#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")" || exit 1

source ../../config.cfg
source ../../helper.sh

for CLUSTER_NAME in "${CLUSTER_1_NAME}" "${CLUSTER_2_NAME}"; do
    info "[$CLUSTER_NAME] Destroying kind cluster"
    kind delete cluster --name "${CLUSTER_NAME}"
done
