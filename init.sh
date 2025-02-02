#!/bin/bash

# Run as root or with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo."
  exit 1
fi

groupadd docker
usermod -aG docker $USER

# ufw allow ssh        # SSH (always important)
# ufw allow 443/tcp    # Nginx (HTTPS for Grafana) - Or 80/tcp if using HTTP
ufw allow 8545/tcp   # Reth RPC
ufw allow 8546/tcp   # Reth WSS
ufw allow 8551/tcp   # Reth Engine API

# Outbound rules (essential with default deny outgoing)
ufw allow out 30303/tcp  # Reth p2p
ufw allow out 9000/tcp  # Lighthouse p2p
ufw allow out 9000/udp  # Lighthouse p2p
ufw allow out 53/tcp     # DNS
ufw allow out 53/udp     # DNS

# If you need to access Grafana, Prometheus, or the Metrics Exporter directly:
# sudo ufw allow 3000/tcp   # Grafana
# sudo ufw allow 9090/tcp   # Prometheus
# sudo ufw allow 9091/tcp   # Metrics exporter

for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove -y $pkg; done

apt update -y
apt install ca-certificates curl -y
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-compose -y

ufw allow 80/tcp
ufw allow 443/tcp

mkdir -p /home/node/reth-node/certs
mkdir -p /home/node/reth-node/reth_data
mkdir -p /home/node/reth-node/web
apt install certbot -y
certbot certonly --standalone -d alphabit.app -d grafana.alphabit.app -d prometheus.alphabit.app -d api.alphabit.app -d app.alphabit.app -d play.alphabit.app -d auth.alphabit.app --email admin@alphabit.app --agree-tos -v
cp /etc/letsencrypt/live/alphabit.app/fullchain.pem /home/node/reth-node/certs/fullchain.pem
cp /etc/letsencrypt/live/alphabit.app/privkey.pem /home/node/reth-node/certs/privkey.pem

openssl rand -hex 32 | tr -d "\n" | tee > /home/node/reth-node/jwt.hex

ufw deny 80/tcp
