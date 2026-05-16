#!/bin/bash
set -e

echo "Updating system..."
sudo dnf update -y

echo "Installing dependencies..."
sudo dnf install -y podman policycoreutils-python-utils

# IMPORTANT: Firewalld needs to reload to see the 'podman' zone 
# provided by the podman package.
echo "Refreshing firewalld configuration..."
sudo systemctl restart firewalld

echo "Configuring firewalld..."

# Loop through both zones to guarantee the rules apply no matter which 
# zone Fedora assigns to your ethernet interface.
ZONES=("FedoraServer" "public")

for ZONE in "${ZONES[@]}"; do
    echo "Applying rules to zone: $ZONE..."
    sudo firewall-cmd --permanent --zone="$ZONE" --add-port=51820/udp || true
    sudo firewall-cmd --permanent --zone="$ZONE" --add-port=51821/tcp || true
    sudo firewall-cmd --permanent --zone="$ZONE" --add-masquerade || true
    sudo firewall-cmd --permanent --zone="$ZONE" --add-service=dns || true
done

echo "WARNING: Port 51821/tcp (Web UI) is being opened permanently."
echo "Ensure this port is NOT forwarded on your router unless you require remote management (not recommended)."

# Ensure 'podman' zone exists before using it in a policy
if ! sudo firewall-cmd --get-zones | grep -q "podman"; then
    echo "Zone 'podman' not found. Creating it manually..."
    sudo firewall-cmd --permanent --new-zone=podman
    sudo firewall-cmd --reload
fi

# Explicitly allow DNS traffic inside the container network zone
sudo firewall-cmd --permanent --zone=podman --add-service=dns

# Fedora-specific: Create policy to allow Podman traffic to exit to the WAN
echo "Creating/updating firewalld policy for Podman-to-WAN routing..."
if ! sudo firewall-cmd --permanent --get-policies | grep -q "podmanToAny"; then
    sudo firewall-cmd --permanent --new-policy podmanToAny
fi

sudo firewall-cmd --permanent --policy podmanToAny --add-ingress-zone podman
sudo firewall-cmd --permanent --policy podmanToAny --add-egress-zone ANY
sudo firewall-cmd --permanent --policy podmanToAny --set-target ACCEPT

sudo firewall-cmd --reload

echo "Configuring kernel modules for WireGuard/iptables/filtering..."
echo -e "iptable_nat\nip_tables\nbr_netfilter" | sudo tee /etc/modules-load.d/wireguard.conf > /dev/null
sudo modprobe iptable_nat || true
sudo modprobe ip_tables || true
sudo modprobe br_netfilter || true

echo "Configuring IP Forwarding..."
echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-wireguard-forwarding.conf > /dev/null
sudo sysctl --system

echo "Host preparation complete."
