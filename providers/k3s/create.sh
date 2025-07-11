#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")" || exit 1

source ../../config.cfg
source ../../helper.sh

TERRAFORM_DIR="../../infra/aws-dual-ec2"
INVENTORY_FILE="$TERRAFORM_DIR/hosts.ini"
INSTANCE_VARS_FILE="$TERRAFORM_DIR/vars.yaml"
USERNAME="admin"

info "[$PROVIDER] Creating clusters with Ansible"
ansible-playbook -i "$INVENTORY_FILE" ./clusters.yaml -e @"$INSTANCE_VARS_FILE" -u "$USERNAME"
