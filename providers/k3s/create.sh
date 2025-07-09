#!/usr/bin/env bash

set -euo pipefail

source ../../config.cfg
source ../../helper.sh

INVENTORY_FILE="../../infra/aws-dual-ec2/hosts.ini"
INSTANCE_VARS_FILE="../../infra/aws-dual-ec2/vars.yaml"
USERNAME="admin"

info "[$PROVIDER] Creating clusters with Ansible"
ansible-playbook -i "$INVENTORY_FILE" ./clusters.yaml -e @"$INSTANCE_VARS_FILE" -u "$USERNAME"
