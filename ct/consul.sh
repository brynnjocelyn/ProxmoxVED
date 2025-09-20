#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/brynnjocelyn/ProxmoxVED/add-consul/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: BrynnJKnight
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://www.consul.io/

APP="Consul"
var_tags="${var_tags:-service-discovery;hashicorp;distributed-systems}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
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
  LATEST_VERSION=$(curl -s https://releases.hashicorp.com/consul/ | grep -o 'consul/[0-9]*\.[0-9]*\.[0-9]*' | head -1 | cut -d'/' -f2)
  CURRENT_VERSION=$(/usr/local/bin/consul version | head -1 | cut -d'v' -f2)
  
  if [[ "$LATEST_VERSION" != "$CURRENT_VERSION" ]]; then
    msg_info "Updating from $CURRENT_VERSION to $LATEST_VERSION"
    systemctl stop consul
    cd /tmp
    wget -q https://releases.hashicorp.com/consul/${LATEST_VERSION}/consul_${LATEST_VERSION}_linux_amd64.zip
    unzip -q consul_${LATEST_VERSION}_linux_amd64.zip
    mv consul /usr/local/bin/
    chmod +x /usr/local/bin/consul
    rm consul_${LATEST_VERSION}_linux_amd64.zip
    systemctl start consul
    msg_ok "Updated to Consul $LATEST_VERSION"
  else
    msg_ok "Already running latest version: $CURRENT_VERSION"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URLs:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8500${CL} (Web UI)"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8600${CL} (DNS)"