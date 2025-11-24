# MaksIT.CertsUI – HAProxy and Agent Configuration

This guide explains how to configure HAProxy, Nginx, and install the MaksIT.CertsUI Agent for automated, secure certificate management.

---


If you find this project useful, please consider supporting its development:

[<img src="https://cdn.buymeacoffee.com/buttons/v2/default-blue.png" alt="Buy Me A Coffee" style="height: 60px; width: 217px;">](https://www.buymeacoffee.com/maksitcom)


---

## Overview

The **MaksIT.CertsUI Agent** is a lightweight, cross-platform service designed to:
- **Receive cached certificates** from the MaksIT.CertsUI server via secure HTTP APIs.
- **Deploy certificates** to your reverse proxy’s local file system (e.g., HAProxy, Nginx).
- **Reload or restart** the proxy service to activate new certificates automatically.

### Key Features
- **Language Agnostic:**  
  The agent communicates using standard HTTP APIs. While a C# WebAPI implementation is provided, you can build your own agent in any language or framework (C#, Go, Python, Rust, Node.js, etc.) as long as it can:
  - Receive certificate files via HTTP
  - Write files to the proxy’s certificate directory
  - Reload or restart the proxy process

- **Security:**  
  All communication between the agent and the MaksIT.CertsUI server is protected by a shared API key. Only authorized agents can deploy certificates and trigger proxy reloads, safeguarding your infrastructure.

  > **Warning:** Never commit secrets or API keys to version control. Always use strong, unique secrets and passwords.

- **Flexible Integration:**  
  The agent is fully independent from the MaksIT.CertsUI server, allowing you to integrate it into any environment or technology stack that supports HTTP endpoints.

---

## Table of Contents
- [HAProxy configuration](#haproxy-configuration)
  - [Explanation](#explanation)
- [Nginx configuration](#nginx-configuration)
  - [Nginx Explanation](#nginx-explanation)
- [MaksIT.CertsUI Agent installation](#maksitcertsui-agent-installation)
- [Contact](#contact)

---

## HAProxy configuration

Create the certificates directory:

```bash
sudo mkdir /etc/haproxy/certs
```

Edit your HAProxy configuration:

```bash
sudo nano /etc/haproxy/haproxy.cfg
```

Example configuration:

```cfg
# Global settings
#---------------------------------------------------------------------
global
    log         127.0.0.1 local2
    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4000
    user        haproxy
    group       haproxy
    daemon
    stats socket /var/lib/haproxy/stats
    ssl-default-bind-ciphers PROFILE=SYSTEM
    ssl-default-server-ciphers PROFILE=SYSTEM

#---------------------------------------------------------------------
# common defaults that all the 'listen' and 'backend' sections will
# use if not designated in their block
#---------------------------------------------------------------------
defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          1m
    timeout server          1m
    timeout http-keep-alive 10s
    timeout check           10s
    maxconn                 3000

#---------------------------------------------------------------------
# Frontend for HTTP traffic on port 80
#---------------------------------------------------------------------
frontend http_frontend
    bind *:80
    acl acme_path path_beg /.well-known/acme-challenge/

    # Redirect all HTTP traffic to HTTPS except ACME challenge requests
    redirect scheme https if !acme_path

    # Use the appropriate backend based on hostname if it's an ACME challenge request
    use_backend acme_backend if acme_path

#---------------------------------------------------------------------
# Backend to handle ACME challenge requests
#---------------------------------------------------------------------
backend acme_backend
    #server local_acme 172.16.0.5:8080

#---------------------------------------------------------------------
# Frontend for HTTPS traffic (port 443) with SNI and strict-sni
#---------------------------------------------------------------------
frontend https_frontend
    bind *:443 ssl crt /etc/haproxy/certs strict-sni

    http-request capture req.hdr(host) len 64

    # Define ACLs for routing based on hostname
    acl host_homepage hdr(host) -i maks-it.com

    # Use appropriate backend based on SNI hostname
    use_backend homepage_backend if host_homepage

    default_backend homepage_backend

#---------------------------------------------------------------------
# Backend for maks-it.com
#---------------------------------------------------------------------
backend homepage_backend
    http-request set-header X-Forwarded-Proto https
    http-request set-header X-Forwarded-Host %[hdr(host)]
    server homepage_server 172.16.0.10:8080
```

### Explanation
- **ACME Challenge Handling:**
 - The `http_frontend` listens on port80 and checks if the request path starts with `/.well-known/acme-challenge/`. These requests are required by Let's Encrypt for domain validation and are forwarded to the `acme_backend`. All other HTTP requests are redirected to HTTPS.
- **HTTPS Frontend:**
 - The `https_frontend` listens on port443, uses SNI (Server Name Indication) to serve the correct certificate, and routes requests to the appropriate backend based on the hostname.
- **Backends:**
 - `acme_backend` should point to your ACME challenge responder (such as your LetsEncrypt client).
 - `homepage_backend` is an example backend for your main site, forwarding requests to your application server.
- **Certificate Storage:**
 - SSL certificates will be placed by agent in `/etc/haproxy/certs`. Each certificate file will contain the full certificate chain and private key.

---

## Nginx configuration

Create the certificates directory:

```bash
sudo mkdir -p /etc/nginx/certs
```

Edit your Nginx configuration:

```bash
sudo nano /etc/nginx/nginx.conf
```

Example configuration:

```nginx
server {
    listen       80;
    server_name  maks-it.com;

    location /.well-known/acme-challenge/ {
        proxy_pass http://127.0.0.1:5000; # Point to your ACME challenge responder (agent)
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name maks-it.com;

    ssl_certificate /etc/nginx/certs/maks-it.com;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://127.0.0.1:8080; # Your backend application
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Nginx Explanation
- **ACME Challenge Handling:**
 - The first server block listens on port80 and forwards requests to `/.well-known/acme-challenge/` to the agent (or ACME challenge responder). All other HTTP requests are redirected to HTTPS.
- **HTTPS Frontend:**
 - The second server block listens on port443, uses the certificate and key files placed by the agent in `/etc/nginx/certs`, and proxies requests to your backend application.
- **Certificate Storage:**
 - SSL certificates and keys should be placed by the agent in `/etc/nginx/certs`. Each domain should have its own `.crt` and `.key` files.

---

## MaksIT.CertsUI Agent installation

The Agent should be installed on the same machine as your reverse proxy.

Clone the repository in your home dir and navigate to the Agent directory (git should be installed):

```bash
cd ~

git clone https://github.com/MAKS-IT-COM/maksit-certs-ui-agent.git
cd maksit-certs-ui-agent/src/MaksIT.CertsUI.Agent
```

Edit `appsettings.json` configuration:

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*",

  "Configuration": {
    "ApiKey": "<your-agent-key>",
    "CertsPath": "<your-certs-dir-path>"
  }
}
```

**Note:**
- Replace `<your-agent-key>` with your shared API key.
- Replace `<your-certs-dir-path>` with the path to your certificates directory (e.g., `/etc/haproxy/certs` or `/etc/nginx/certs`).

```bash
cd ../Installers
```

To deploy the agent via script:

```bash
sudo sh ./install.sh
```

This script will create the `maksit-certs-ui-agent` service and open port `5000` for communication.

## MaksIT.CertsUI Agent uninstallation

To uninstall the agent, run the following command:

```bash
sudo sh ./uninstall.sh
```

---

## Contact

For any inquiries or contributions, feel free to reach out:

- **Email**: maksym.sadovnychyy@gmail.com
- **Author**: Maksym Sadovnychyy (MAKS-IT)
