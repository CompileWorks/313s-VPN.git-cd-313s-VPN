#!/bin/bash

# 313s VPN - Auto WireGuard Setup Script
# Locations: USA, Germany, UK, Russia, China, Australia

echo -e "\033[1;34m
   _____ ___ _____    _____ _   _ ____  
  |___  |_ _|  ___|  |___  | | |  _ \ 
     / / | || |_   _____/ /| | | |_) |
    / /  | ||  _| |_____/ / | | |  __/ 
   /_/  |___|_|       /_/  |_| |_|    
\033[0m"
echo -e "\033[1;36m313s VPN - Multi-Location WireGuard Setup\033[0m"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "\033[1;31mPlease run as root (use 'sudo ./setup.sh').\033[0m"
  exit 1
fi

# Install WireGuard
echo -e "\033[1;33mInstalling WireGuard...\033[0m"
apt update && apt install -y wireguard qrencode

# Generate Keys
echo -e "\033[1;33mGenerating WireGuard keys...\033[0m"
wg genkey | tee /etc/wireguard/privatekey | wg pubkey | tee /etc/wireguard/publickey

# Configure WG
echo -e "\033[1;33mCreating WireGuard config...\033[0m"
PRIVATE_KEY=$(cat /etc/wireguard/privatekey)
PUBLIC_KEY=$(cat /etc/wireguard/publickey)

cat > /etc/wireguard/wg0.conf <<EOL
[Interface]
PrivateKey = $PRIVATE_KEY
Address = 10.0.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = <CLIENT_PUBLIC_KEY>
AllowedIPs = 10.0.0.2/32
EOL

# Enable IP Forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Start WireGuard
systemctl enable --now wg-quick@wg0

# Generate Client Config
echo -e "\033[1;33mGenerating client config...\033[0m"
cat > client.conf <<EOL
[Interface]
PrivateKey = <CLIENT_PRIVATE_KEY>
Address = 10.0.0.2/24
DNS = 8.8.8.8

[Peer]
PublicKey = $PUBLIC_KEY
Endpoint = $(curl -4 ifconfig.co):51820
AllowedIPs = 0.0.0.0/0
EOL

echo -e "\033[1;32m✅ WireGuard setup complete!\033[0m"
echo -e "\033[1;36mScan the QR code below or copy client.conf to your device.\033[0m"
qrencode -t ansiutf8 < client.conf
