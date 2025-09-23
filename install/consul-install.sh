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
  gnupg \
  lsb-release \
  ca-certificates \
  unzip \
  jq
msg_ok "Installed Dependencies"

msg_info "Installing Consul"
CONSUL_VERSION=$(curl -s https://api.github.com/repos/hashicorp/consul/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
cd /tmp
wget -q https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip
unzip -q consul_${CONSUL_VERSION}_linux_amd64.zip
mv consul /usr/bin/consul
chmod +x /usr/bin/consul
rm consul_${CONSUL_VERSION}_linux_amd64.zip

# Create consul user and directories
useradd --system --home /opt/consul --shell /bin/false consul
mkdir -p /opt/consul/{data,config}
msg_ok "Installed Consul v${CONSUL_VERSION}"

msg_info "Configuring Consul"
# Get the container's primary IP address
HOST_IP=$(hostname -I | awk '{print $1}')

# Create Consul configuration
cat <<EOF >/opt/consul/config/consul.hcl
datacenter = "dc1"
data_dir = "/opt/consul/data"
log_level = "INFO"
node_name = "consul-server"
server = true
bootstrap_expect = 1
encrypt = ""

# Bind to all interfaces for container environment
bind_addr = "0.0.0.0"
client_addr = "0.0.0.0"

# UI Configuration
ui_config {
  enabled = true
}

# Connect Configuration (Service Mesh)
connect {
  enabled = true
}

# DNS Configuration
ports {
  dns = 8600
  http = 8500
  https = -1
  serf_lan = 8301
  serf_wan = 8302
  server = 8300
  grpc = 8502
  grpc_tls = -1
}

# ACL Configuration (disabled by default for dev use)
acl = {
  enabled = false
  default_policy = "allow"
}

# Performance tuning
performance {
  raft_multiplier = 1
}
EOF

# Set proper ownership
chown -R consul:consul /opt/consul
chmod -R 755 /opt/consul
msg_ok "Configured Consul"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/consul.service
[Unit]
Description=Consul
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/opt/consul/config/consul.hcl

[Service]
Type=notify
User=consul
Group=consul
ExecStart=/usr/bin/consul agent -config-dir=/opt/consul/config/
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
TimeoutStartSec=0
RestartSec=5s
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl enable -q --now consul
sleep 2

# Wait for Consul to be ready
msg_info "Waiting for Consul to start..."
for i in {1..30}; do
  if consul members &>/dev/null; then
    break
  fi
  sleep 1
done
msg_ok "Created Service"

msg_info "Setting up Consul CLI"
# Add consul autocomplete
consul -autocomplete-install 2>/dev/null || true

# Create a helper script for common operations
cat <<'EOF' >/usr/local/bin/consul-helper
#!/bin/bash
case "$1" in
  bootstrap-acl)
    echo "Bootstrapping ACL system..."
    consul acl bootstrap
    echo "Save the SecretID shown above - it's your bootstrap token!"
    ;;
  enable-acl)
    echo "Enabling ACL system (requires restart)..."
    sed -i 's/enabled = false/enabled = true/' /opt/consul/config/consul.hcl
    sed -i 's/default_policy = "allow"/default_policy = "deny"/' /opt/consul/config/consul.hcl
    systemctl restart consul
    echo "ACL system enabled. Run 'consul-helper bootstrap-acl' to create the bootstrap token."
    ;;
  status)
    consul members
    ;;
  ui)
    echo "Consul UI is available at: http://$(hostname -I | awk '{print $1}'):8500"
    ;;
  *)
    echo "Usage: consul-helper {bootstrap-acl|enable-acl|status|ui}"
    exit 1
    ;;
esac
EOF
chmod +x /usr/local/bin/consul-helper
msg_ok "Setup Consul CLI"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"