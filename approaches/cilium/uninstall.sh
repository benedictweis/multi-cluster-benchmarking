#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")" || exit 1

source ../../config.cfg
source ../../helper.sh

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

approachinfo "Uninstalling Cilium"
helm upgrade --install --reset-values --version 1.17.5 -n kube-system cilium cilium/cilium --kube-context "${CLUSTER_1_CONTEXT}"
helm upgrade --install --reset-values --version 1.17.5 -n kube-system cilium cilium/cilium --kube-context "${CLUSTER_2_CONTEXT}"
