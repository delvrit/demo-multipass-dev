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

# see https://askubuntu.com/questions/1032450/how-to-add-dnsmasq-and-keep-systemd-resolved-18-04

# log minimal v1.0
function log() {
  echo -n "[$1] "
  shift 1
  echo "$@"
}

# add value if not present v0.1
function add_value_if_not_present() {
  local file key value
  if [ $# -lt 3 ]; then
    return
  fi
  file="$1"
  key="$2"
  value="$3"
  touch "${file}"
  # shellcheck disable=SC2015
  grep -q "^$key" "${file}" &&
    sed -i "s#^$key=.*#$key=$value#" "${file}" ||
    echo "$key=$value" | tee -a "${file}" >/dev/null
  unset file key value
}

# sudo warn v1.0
if [[ $UID != 0 ]]; then
  log 'warn' "please run this script with sudo:"
  echo "sudo $0 $*"
  exit 1
fi

log 'info' 'setup dnsmasq'

# so far works only on linux :-(
# add multipass dnsmasq (mpqemubr0) if multipass is found
command -v multipass >/dev/null && {
  MULTIPASS_QUEMU_BRIDGE_IP="$(ip route | grep mpqemubr0 | awk '{ print $9 }')"
  echo "$MULTIPASS_QUEMU_BRIDGE_IP"
  add_value_if_not_present /etc/dnsmasq.d/multipass.conf 'server' "/multipass/$MULTIPASS_QUEMU_BRIDGE_IP"
}

sudo systemctl enable dnsmasq
sudo systemctl restart dnsmasq
