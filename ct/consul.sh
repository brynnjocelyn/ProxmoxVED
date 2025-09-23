#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVED/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: BrynnJKnight
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://www.consul.io/

APP="Consul"
var_tags="${var_tags:-service-discovery;service-mesh;key-value}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-1024}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -f /etc/systemd/system/consul.service ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Updating ${APP} LXC"
  CURRENT_VERSION=$(consul version | head -n1 | awk '{print $2}')
  LATEST_VERSION=$(curl -s https://api.github.com/repos/hashicorp/consul/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

  if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
    msg_ok "Consul is already at the latest version ($CURRENT_VERSION)"
  else
    msg_info "Updating Consul from $CURRENT_VERSION to $LATEST_VERSION"
    cd /tmp
    wget -q https://releases.hashicorp.com/consul/${LATEST_VERSION}/consul_${LATEST_VERSION}_linux_amd64.zip
    unzip -q consul_${LATEST_VERSION}_linux_amd64.zip
    systemctl stop consul
    mv consul /usr/bin/consul
    chmod +x /usr/bin/consul
    systemctl start consul
    rm consul_${LATEST_VERSION}_linux_amd64.zip
    msg_ok "Updated Consul to version $LATEST_VERSION"
  fi
  msg_ok "Updated Successfully"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8500${CL}"