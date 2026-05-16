#!/bin/bash
set -e

# Configuration
STORAGE_DIR="/opt/wg-easy"
QUADLET_PATH="/etc/containers/systemd/wg-easy.container"

echo "Checking for Podman secrets..."

# Handle WG_HOST secret
if ! sudo podman secret exists wg_host; then
    echo "Secret 'wg_host' (your domain/DynDNS) not found."
    read -p "Enter your public domain name (e.g., dummy.mydomain.de): " WG_HOST_VAL
    printf "%s" "$WG_HOST_VAL" | sudo podman secret create wg_host -
    echo "Secret 'wg_host' created."
fi

# Handle wg_password_hash secret
if ! sudo podman secret exists wg_password_hash; then
    echo "Secret 'wg_password_hash' not found."
    read -s -p "Enter the password for the WireGuard Web UI: " UI_PASS
    echo
    echo "Generating bcrypt hash (this might take a moment to pull the image if not present)..."
    RAW_OUTPUT=$(sudo podman run --rm ghcr.io/wg-easy/wg-easy wgpw "$UI_PASS")
    # The output is in the format: PASSWORD_HASH='$2y$10$...'
    # We need to extract just the hash between the single quotes
    HASH=$(echo "$RAW_OUTPUT" | sed -n "s/^PASSWORD_HASH='\(.*\)'$/\1/p")
    
    if [ -z "$HASH" ]; then
        echo "Failed to extract hash. Raw output was: $RAW_OUTPUT"
        # Fallback if the format was somehow different
        HASH="$RAW_OUTPUT"
    fi

    printf "%s" "$HASH" | sudo podman secret create wg_password_hash -
    echo "Secret 'wg_password_hash' created."
    # Clear the variable just to be safe
    UI_PASS=""
fi

# Handle wg_dns secret
if ! sudo podman secret exists wg_dns; then
    echo "Secret 'wg_dns' not found. You need to enter the DNS server's IP address."
    echo "If the DNS server also  runs on podman on the same serverm you might need to configure the IP of podmans"
    echo " internal networkinterface. The default on fedora would be 10.88.0.1. Run `ip address` for details."
    read -p "Enter the DNS server IP for VPN clients (Press Enter to default to 1.1.1.1): " DNS_VAL
    if [ -z "$DNS_VAL" ]; then
        DNS_VAL="1.1.1.1"
    fi
    printf "%s" "$DNS_VAL" | sudo podman secret create wg_dns -
    echo "Secret 'wg_dns' created with value $DNS_VAL."
fi

echo "Creating Quadlet file at $QUADLET_PATH..."
sudo tee "$QUADLET_PATH" > /dev/null <<EOF
[Unit]
Description=wg-easy container

[Container]
AutoUpdate=registry
Image=ghcr.io/wg-easy/wg-easy
ContainerName=wg-easy
Environment=WG_ALLOWED_IPS=0.0.0.0/0, ::/0
Environment=WG_MTU=1280
Environment=WG_PERSISTENT_KEEPALIVE=25

# Use double %% for systemd and quotes for the full string
Environment="WG_POST_UP=iptables -A FORWARD -i %%i -j ACCEPT; iptables -A FORWARD -o %%i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE"
Environment="WG_POST_DOWN=iptables -D FORWARD -i %%i -j ACCEPT; iptables -D FORWARD -o %%i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE"

# Enable IP Forwarding inside the container
Sysctl=net.ipv4.ip_forward=1
Sysctl=net.ipv4.conf.all.src_valid_mark=1

# Inject secrets as environment variables
Secret=wg_host,type=env,target=WG_HOST
Secret=wg_password_hash,type=env,target=PASSWORD_HASH
Secret=wg_dns,type=env,target=WG_DEFAULT_DNS
Volume=$STORAGE_DIR:/etc/wireguard:Z
PublishPort=51820:51820/udp
PublishPort=51821:51821/tcp
AddCapability=CAP_NET_ADMIN CAP_SYS_MODULE CAP_NET_RAW

[Service]
Restart=always

[Install]
WantedBy=multi-user.target default.target
EOF

echo "Cleaning up legacy plain-text password secret if it exists..."
if sudo podman secret exists wg_password; then
    sudo podman secret rm wg_password || true
    echo "Removed legacy 'wg_password' secret."
fi

echo "Reloading systemd and restarting wg-easy service..."
sudo systemctl daemon-reload
sudo systemctl restart wg-easy

echo "Deployment complete. Access the Web UI at http://<your-pi-ip>:51821"
