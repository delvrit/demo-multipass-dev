#!/usr/bin/env bash
# -*- mode: sh -*-
# vi: set ft=sh ff=unix fenc=utf-8
# shellcheck shell=bash

#
#  Copyright 2020 the original author or authors.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

set -o errexit -o nounset -o pipefail -o errtrace
IFS=$'\n\t'

# set xtrace v1.0
if [[ ${DEBUG-} =~ ^true$ ]]; then
  set -o xtrace
fi

# log minimal v1.3
function log() {
  echo -n "# [$1] "
  shift 1
  echo "$@"
  command -v logger >/dev/null 2>&1 && {
    logger -i -t "${0##*/}" "$@"
  }
}

# source .env v1.1
if [[ -f .env ]]; then
  # shellcheck source=/dev/null
  source .env
fi

VM_NAME=${VM_NAME:-'dev'}
VM_IMAGE=${VM_IMAGE:-'20.04'}
VM_MEM=${VM_MEM:-'6G'}
VM_DISK=${VM_DISK:-'6G'}
#CLOUD_INIT_FILE=${CLOUD_INIT_FILE:-"${VM_NAME}.yaml"}
SSH_ID_FILE=${SSH_ID_FILE:-~/.ssh/id_rsa.pub}

log 'info' "${VM_NAME} on multipass demo"

# remove id in case vm is newly created
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$VM_NAME.multipass" >/dev/null 2>&1

# TODO: externalise
multipass launch --name "${VM_NAME}" --mem "${VM_MEM}" --disk "${VM_DISK}" "${VM_IMAGE}" --cloud-init - 2>/dev/null <<'EOF' && {
#cloud-config
users:
- name: ubuntu
  #sudo: ALL=(ALL) NOPASSWD:ALL
  ssh_authorized_keys:
  - $(cat "${SSH_ID_FILE}")
#manage_resolv_conf: true
resolv_conf:
  nameservers: ['127.0.0.1', '127.0.0.53']
  searchdomains:
    - multipass
    - local
package_update: true
package_upgrade: true
packages:
  - unattended-upgrades
  - aptitude
  - avahi-daemon
  - python3
  - python3-pip
  - python3-powerline
  - python3-powerline-gitstatus
  - python3-powerline-taskwarrior
  - powerline
  - fonts-powerline
  - zsh
  - zsh-autosuggestions
  - zsh-syntax-highlighting
  - zsh-theme-powerlevel9k
  - zip
  - unzip
runcmd:
  - apt-get -y clean
  - apt-get -y autoremove --purge
  - snap refresh
  - snap install canonical-livepatch
  #- snap install multipass --edge --classic
  - snap install docker
  - snap install lxd
bootcmd:
  - echo '127.0.0.53 dns' | tee -a /etc/host
EOF

  multipass exec "${VM_NAME}" -- sh -c 'DEBIAN_FRONTEND=noninteractive sudo dpkg --configure -a'
  multipass exec "${VM_NAME}" -- sudo iptables -P FORWARD ACCEPT

}
# TODO: netplan, lan capacities limited

mkdir -p "${HOME}"/{bin,.config,Repositories,.vscode-server/extensions}

multipass unmount "${VM_NAME}" || true

multipass mount -u "$(id -u)":1001 -g "$(id -g)":1001 "${HOME}/bin" "${VM_NAME}":/home/ubuntu/bin || true
multipass mount -u "$(id -u)":1001 -g "$(id -g)":1001 "${HOME}/.config" "${VM_NAME}":/home/ubuntu/.config || true
multipass mount -u "$(id -u)":1001 -g "$(id -g)":1001 "${HOME}/Repositories" "${VM_NAME}":/home/ubuntu/Repositories || true
multipass mount -u "$(id -u)":1001 -g "$(id -g)":1001 "${HOME}/.vscode" "${VM_NAME}":/home/ubuntu/.vscode || true
multipass mount -u "$(id -u)":1001 -g "$(id -g)":1001 "${HOME}/.vscode-server/extensions" "${VM_NAME}":/home/ubuntu/.vscode-server/extensions || true
# TODO: mount multipass cloud image folder

#multipass mount -u "$(id -u)":1001 -g "$(id -g)":1001 "${HOME}" "${VM_NAME}:/home/$(basename "$HOME")" || true

# setup dotfiles
# TODO: less specific
#multipass exec "${VM_NAME}" -- bash -c 'if [[ -f ~/bin/setup-dirs-config.sh ]]; then ~/bin/setup-dirs-config.sh; fi'

# multipass ssh key in
# /var/snap/multipass/common/data/multipassd/ssh-keys or
# /var/root/Library/Application Support/multipassd/ssh-keys

echo "# $(multipass list | head -n 1)"
echo "# $(multipass list | grep "${VM_NAME}")"
echo "# multipass delete grep ${VM_NAME} --purge"
echo "# ssh ubuntu@$(multipass list | grep "${VM_NAME}" | awk '{ print $3 }')"
echo "# multipass shell ${VM_NAME}"

#multipass exec "${VM_NAME}" -- sudo reboot

# https://github.com/canonical/multipass/issues/118
