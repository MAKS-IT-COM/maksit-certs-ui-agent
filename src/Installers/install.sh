#!/bin/bash

# Variables
REQUIRED_DOTNET_SDK="10.0"

SERVICE_NAME="maksit-certs-ui-agent"
SERVICE_PORT="5000"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
INSTALL_DIR="/opt/$SERVICE_NAME"
DOTNET_EXEC="/usr/bin/dotnet"
EXEC_CMD="$DOTNET_EXEC $INSTALL_DIR/MaksIT.CertsUI.Agent.dll --urls \"http://*:$SERVICE_PORT\""
APPSETTINGS_FILE="appsettings.json"
NO_NEW_KEY_FLAG="--no-new-key"
TMP_JSON_FILE="/tmp/tmp.$$.json"

# Detect distro and version
if [ -f /etc/os-release ]; then
  . /etc/os-release
  DISTRO=$ID
  VERSION_ID=$VERSION_ID
else
  echo "Cannot detect Linux distribution."
  exit 1
fi

# Helper: Check available SDKs and install
check_and_install_dotnet_sdk() {
  local sdk_pkg

  case "$DISTRO" in
    ubuntu|debian)
      if ! dpkg -l | grep -q packages-microsoft-prod; then
        wget -q https://packages.microsoft.com/config/$DISTRO/$VERSION_ID/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
        sudo dpkg -i packages-microsoft-prod.deb
        sudo apt-get update
      fi

      sdk_pkg="dotnet-sdk-$REQUIRED_DOTNET_SDK"

      if ! dpkg -l | grep -q "$sdk_pkg"; then
        if ! apt-cache show "$sdk_pkg" > /dev/null 2>&1; then
          echo "Required .NET SDK not available."
          exit 1
        fi
        sudo apt-get install -y "$sdk_pkg"
      fi
      ;;

    centos|rhel|fedora|almalinux|alma|rocky)
      if [[ "$DISTRO" == "almalinux" ]]; then
        MS_DISTRO="alma"
      elif [[ "$DISTRO" == "rocky" ]]; then
        MS_DISTRO="rocky"
      else
        MS_DISTRO="$DISTRO"
      fi

      LOCAL_MAJOR="${VERSION_ID%%.*}"
      REPO_INDEX_URL="https://packages.microsoft.com/config/$MS_DISTRO/"

      AVAILABLE_VERSIONS=$(curl -s "$REPO_INDEX_URL" | grep -oP '(?<=href=")[0-9][^/]*(?=/")' | sort -V)
      if [ -z "$AVAILABLE_VERSIONS" ]; then
        echo "ERROR: Cannot fetch repo index."
        exit 1
      fi

      SELECTED_VERSION=""
      for v in $AVAILABLE_VERSIONS; do
        if [[ "$v" == "$LOCAL_MAJOR" ]]; then
          SELECTED_VERSION="$v"
          break
        fi
        if [[ "$v" -lt "$LOCAL_MAJOR" ]]; then
          SELECTED_VERSION="$v"
        fi
      done

      if [ -z "$SELECTED_VERSION" ]; then
        echo "No matching repo version found"
        exit 1
      fi

      REPO_RPM_URL="$REPO_INDEX_URL$SELECTED_VERSION/packages-microsoft-prod.rpm"

      # Idempotent repo install
      if ! rpm -q packages-microsoft-prod > /dev/null 2>&1; then
        sudo rpm -Uvh --quiet "$REPO_RPM_URL" || {
          echo "ERROR: Failed installing Microsoft repo"
          exit 1
        }
      else
        echo "Microsoft repo already installed, skipping"
      fi

      sudo dnf makecache

      sdk_pkg="dotnet-sdk-$REQUIRED_DOTNET_SDK"

      # Idempotent SDK install
      if ! rpm -q "$sdk_pkg" > /dev/null 2>&1; then
        if dnf list available "$sdk_pkg" > /dev/null 2>&1; then
          sudo dnf install -y "$sdk_pkg"
        else
          echo "ERROR: .NET SDK $sdk_pkg not found and not installed"
          exit 1
        fi
      else
        echo ".NET SDK already installed."
      fi
      ;;

    *)
      echo "Unsupported distro: $DISTRO"
      exit 1
      ;;
  esac
}

check_and_install_dotnet_sdk

# Stop service if exists (idempotent)
if systemctl list-unit-files | grep -q "$SERVICE_NAME.service"; then
  sudo systemctl stop "$SERVICE_NAME.service" || true
  sudo systemctl disable "$SERVICE_NAME.service" || true
fi

# Remove old systemd file (idempotent)
sudo rm -f "$SERVICE_FILE"

# Recreate install dir
sudo rm -rf "$INSTALL_DIR"
sudo mkdir -p "$INSTALL_DIR"

# Update API key
if [[ "$1" != "$NO_NEW_KEY_FLAG" ]]; then
  if [ -f "$APPSETTINGS_FILE" ]; then
    NEW_API_KEY=$(openssl rand -base64 32)
    jq --arg newApiKey "$NEW_API_KEY" '.Configuration.ApiKey = $newApiKey' "$APPSETTINGS_FILE" > "$TMP_JSON_FILE" && mv "$TMP_JSON_FILE" "$APPSETTINGS_FILE"
  fi
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR/.." || exit 1

if [ ! -f "MaksIT.CertsUI.Agent/MaksIT.CertsUI.Agent.csproj" ]; then
  echo "Project missing"
  exit 1
fi

sudo dotnet build MaksIT.CertsUI.Agent/MaksIT.CertsUI.Agent.csproj --configuration Release
sudo dotnet publish MaksIT.CertsUI.Agent/MaksIT.CertsUI.Agent.csproj -c Release -o "$INSTALL_DIR"

# Systemd unit (idempotent)
sudo bash -c "cat > $SERVICE_FILE <<EOL
[Unit]
  Description=Maks-IT Agent
  After=network.target

[Service]
  WorkingDirectory=$INSTALL_DIR
  ExecStart=$EXEC_CMD
  Restart=always
  RestartSec=10
  KillSignal=SIGINT
  SyslogIdentifier=dotnet-servicereloader
  User=root
  Environment=ASPNETCORE_ENVIRONMENT=Production

[Install]
  WantedBy=multi-user.target
EOL"

sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME.service"
sudo systemctl restart "$SERVICE_NAME.service"

# Firewall (idempotent)
if command -v firewall-cmd > /dev/null 2>&1; then
  FIREWALL_SERVICE_XML="/etc/firewalld/services/$SERVICE_NAME.xml"

  if [ ! -f "$FIREWALL_SERVICE_XML" ]; then
    echo '<?xml version="1.0"?>
<service>
  <short>MaksIT.CertsUI Agent</short>
  <port protocol="tcp" port="5000"/>
</service>' | sudo tee "$FIREWALL_SERVICE_XML"
  fi

  sleep 10

  sudo firewall-cmd --permanent --add-service=$SERVICE_NAME || true
  sudo firewall-cmd --reload

elif command -v ufw > /dev/null 2>&1; then
  sudo ufw allow "$SERVICE_PORT"/tcp || true
fi
