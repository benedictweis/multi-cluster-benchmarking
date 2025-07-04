#!/usr/bin/env bash

set -euo pipefail

source ../../helper.sh
source ../../config.cfg

for CLUSTER_NAME in "${CLUSTER_1_NAME}" "${CLUSTER_2_NAME}"; do
    info "[$CLUSTER_NAME] Destroying kind cluster"
    kind delete cluster --name "${CLUSTER_NAME}"
done
