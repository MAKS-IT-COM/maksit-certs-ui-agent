#!/bin/bash

# Variables
SERVICE_NAME="maksit-certs-ui-agent"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
INSTALL_DIR="/opt/$SERVICE_NAME"
SERVICE_PORT="5000"
FIREWALL_XML="/etc/firewalld/services/maks-it-agent.xml"

echo "Uninstalling $SERVICE_NAME ..."

# Stop and disable the service if it exists
if systemctl list-unit-files | grep -q "$SERVICE_NAME.service"; then
  echo "Stopping service..."
  sudo systemctl stop "$SERVICE_NAME.service" || true
  sudo systemctl disable "$SERVICE_NAME.service" || true
fi

# Remove the systemd service file
if [ -f "$SERVICE_FILE" ]; then
  echo "Removing systemd service file..."
  sudo rm -f "$SERVICE_FILE"
fi

# Reload systemd
echo "Reloading systemd..."
sudo systemctl daemon-reload

# Remove installation directory
if [ -d "$INSTALL_DIR" ]; then
  echo "Removing installation directory $INSTALL_DIR ..."
  sudo rm -rf "$INSTALL_DIR"
fi

# Remove firewalld rule and XML
if command -v firewall-cmd > /dev/null 2>&1; then
  echo "Removing firewalld service rule..."
  sudo firewall-cmd --permanent --remove-service=$SERVICE_NAME || true

  if [ -f "$FIREWALL_XML" ]; then
    echo "Removing firewalld XML file..."
    sudo rm -f "$FIREWALL_XML"
  fi

  sudo firewall-cmd --reload || true
fi

# Remove UFW rule if available
if command -v ufw > /dev/null 2>&1; then
  echo "Removing UFW rule..."
  sudo ufw delete allow "$SERVICE_PORT"/tcp || true
fi

echo "Uninstall complete."
