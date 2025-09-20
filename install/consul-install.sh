#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: BrynnJKnight
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://www.consul.io/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  curl \
  wget \
  unzip \
  ca-certificates \
  gnupg
msg_ok "Installed Dependencies"

msg_info "Installing Consul"
CONSUL_VERSION=$(curl -s https://releases.hashicorp.com/consul/ | grep -o 'consul/[0-9]*\.[0-9]*\.[0-9]*' | head -1 | cut -d'/' -f2)
cd /tmp
wget -q https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip
unzip -q consul_${CONSUL_VERSION}_linux_amd64.zip
mv consul /usr/local/bin/
chmod +x /usr/local/bin/consul
rm consul_${CONSUL_VERSION}_linux_amd64.zip
msg_ok "Installed Consul $CONSUL_VERSION"

msg_info "Creating Consul User"
useradd --system --home /etc/consul --shell /bin/false consul
mkdir -p /opt/consul /etc/consul/data
chown -R consul:consul /opt/consul /etc/consul
msg_ok "Created Consul User"

msg_info "Configuring Consul"
HOST_IP=$(hostname -I | awk '{print $1}')
cat <<EOF >/etc/consul/consul.hcl
datacenter = "dc1"
data_dir = "/etc/consul/data"
log_level = "INFO"
node_name = "consul-server"
server = true
bootstrap_expect = 1
bind_addr = "$HOST_IP"
client_addr = "0.0.0.0"
retry_join = ["$HOST_IP"]
ui_config {
  enabled = true
}
connect {
  enabled = true
}
ports {
  grpc = 8502
}
acl = {
  enabled = false
  default_policy = "allow"
  enable_token_persistence = true
}
EOF

chown consul:consul /etc/consul/consul.hcl
msg_ok "Configured Consul"

msg_info "Creating Consul Service"
cat <<EOF >/etc/systemd/system/consul.service
[Unit]
Description=Consul
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul/consul.hcl

[Service]
Type=notify
User=consul
Group=consul
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul/
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl enable -q --now consul
msg_ok "Created Consul Service"

msg_info "Creating Update Script"
cat <<'EOF' >/usr/bin/update
#!/bin/bash
set -euo pipefail

echo "Checking for Consul updates..."
LATEST_VERSION=$(curl -s https://releases.hashicorp.com/consul/ | grep -o 'consul/[0-9]*\.[0-9]*\.[0-9]*' | head -1 | cut -d'/' -f2)
CURRENT_VERSION=$(/usr/local/bin/consul version | head -1 | cut -d'v' -f2)

if [[ "$LATEST_VERSION" != "$CURRENT_VERSION" ]]; then
    echo "Updating from $CURRENT_VERSION to $LATEST_VERSION"
    systemctl stop consul
    cd /tmp
    wget -q https://releases.hashicorp.com/consul/${LATEST_VERSION}/consul_${LATEST_VERSION}_linux_amd64.zip
    unzip -q consul_${LATEST_VERSION}_linux_amd64.zip
    mv consul /usr/local/bin/
    chmod +x /usr/local/bin/consul
    rm consul_${LATEST_VERSION}_linux_amd64.zip
    systemctl start consul
    echo "Consul updated to $LATEST_VERSION"
else
    echo "Already running latest version: $CURRENT_VERSION"
fi
EOF

chmod +x /usr/bin/update
msg_ok "Created Update Script"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"