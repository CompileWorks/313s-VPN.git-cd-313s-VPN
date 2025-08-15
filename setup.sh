#!/bin/bash

# 313s VPN - Auto WireGuard Setup (Multi-Location)
# Locations: USA, Germany, UK, Russia, China, Australia

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}
   _____ ___ _____    _____ _   _ ____  
  |___  |_ _|  ___|  |___  | | |  _ \ 
     / / | || |_   _____/ /| | | |_) |
    / /  | ||  _| |_____/ / | | |  __/ 
   /_/  |___|_|       /_/  |_| |_|    
${NC}"
echo -e "${YELLOW}313s VPN - Multi-Location WireGuard Setup${NC}"

# Check root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root (use 'sudo ./setup.sh').${NC}"
  exit 1
fi

# Detect OS (Ubuntu/Debian/CentOS)
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
else
  echo -e "${RED}Unsupported OS. Use Ubuntu/Debian/CentOS.${NC}"
  exit 1
fi

# Install WireGuard based on OS
echo -e "${YELLOW}Installing WireGuard...${NC}"
case $OS in
  ubuntu|debian)
    apt update && apt install -y wireguard qrencode iptables ;;
  centos|rhel)
    yum install -y epel-release && yum install -y wireguard-tools qrencode iptables ;;
  *)
    echo -e "${RED}Unsupported OS. Exiting.${NC}"
    exit 1 ;;
esac

# Country Selection
echo -e "${BLUE}Select VPN server location:${NC}"
echo "1) USA"
echo "2) Germany"
echo "3) UK"
echo "4) Russia"
echo "5) China"
echo "6) Australia"
read -p "Enter choice (1-6): " LOCATION

case $LOCATION in
  1) COUNTRY="USA" ;;
  2) COUNTRY="Germany" ;;
  3) COUNTRY="UK" ;;
  4) COUNTRY="Russia" ;;
  5) COUNTRY="China" ;;
  6) COUNTRY="Australia" ;;
  *) echo -e "${RED}Invalid choice. Exiting.${NC}" ; exit 1 ;;
esac

# Generate Keys
echo -e "${YELLOW}Generating keys for $COUNTRY server...${NC}"
PRIVATE_KEY=$(wg genkey)
PUBLIC_KEY=$(echo "$PRIVATE_KEY" | wg pubkey)
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)

# Server Config
echo -e "${YELLOW}Creating WireGuard config...${NC}"
cat > /etc/wireguard/wg0.conf <<EOL
[Interface]
PrivateKey = $PRIVATE_KEY
Address = 10.0.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = 10.0.0.2/32
EOL

# Enable IP Forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p > /dev/null

# Start WireGuard
systemctl enable --now wg-quick@wg0

# Client Config
mkdir -p client-configs
cat > "client-configs/$COUNTRY.conf" <<EOL
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = 10.0.0.2/24
DNS = 8.8.8.8

[Peer]
PublicKey = $PUBLIC_KEY
Endpoint = $(curl -4 ifconfig.co):51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOL

# QR Code
echo -e "${GREEN}✅ $COUNTRY VPN setup complete!${NC}"
echo -e "${BLUE}Scan the QR code below or use client-configs/$COUNTRY.conf${NC}"
qrencode -t ansiutf8 < "client-configs/$COUNTRY.conf"
