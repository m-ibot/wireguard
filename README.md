# WireGuard Home Server Setup Guide

This guide describes how to set up a WireGuard server on Fedora 44 (Raspberry Pi 4) using \`wg-easy\` and Podman.

## Current Setup Status
- **OS:** Fedora 44 Server (aarch64)
- **Container Engine:** Podman
- **VPN Software:** wg-easy (WireGuard)
- **DynDNS:** Fritz!Box + Strato

## Installation Steps
> **Note:** All scripts should be run with `sudo` or as a user with root privileges. Fedora Server has `firewalld` enabled by default; ensure it is active before proceeding.

1. Run `sudo scripts/01-prepare-host.sh` to install dependencies and configure the firewall.
2. Run `sudo scripts/02-setup-storage.sh` to prepare persistent storage.
3. Run `sudo scripts/03-deploy-wg-easy.sh` to deploy the WireGuard container.
   * **Note on DNS:** During deployment, you will be prompted for a DNS IP address. If you are running a local Pihole on the host, enter your host's local network IP address (e.g., `192.168.178.20`). Otherwise, press Enter to default to `1.1.1.1`.

## Post-Installation
1. Configure Fritz!Box:
   - Port forward **UDP 51820** to the Raspberry Pi.
   - (Optional) Port forward **TCP 51821** only if you want remote WebUI access (NOT recommended for security; use local access or VPN into it first).
2. Access the WebUI at `http://<pi-ip>:51821`.
3. Add a client, download the config/QR code, and test the connection.

## Maintenance
- **Manual Update:** Run `sudo podman auto-update`.
- **Automatic Updates:** Enable the daily background update timer:
  ```bash
  sudo systemctl enable --now podman-auto-update.timer
  ```

## AI Agents usage
[Google Gemini](https://gemini.google.com/) was used to discuss and solve problems during the setup of wg-easy. Furthermore [GeminiCLI](https://geminicli.com/) was used to update and structure the documentation and generate the scripts.