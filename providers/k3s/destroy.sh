#!/usr/bin/env bash

set -euo pipefail

source ../../config.cfg
source ../../helper.sh

TERRAFORM_DIR="../../infra/aws-dual-ec2"

info "[$PROVIDER] Running 'tofu destroy' in $TERRAFORM_DIR"
pushd "$TERRAFORM_DIR" >/dev/null
tofu destroy -auto-approve
popd >/dev/null
