#!/usr/bin/env bash

set -euo pipefail

source ../../helper.sh
source ../../config.cfg

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

approachinfo "Uninstalling Cilium"
helm upgrade --install --reset-values --version 1.17.5 -n kube-system cilium cilium/cilium --set ipam.mode=kubernetes --kube-context "${CLUSTER_1_CONTEXT}"
helm upgrade --install --reset-values --version 1.17.5 -n kube-system cilium cilium/cilium --set ipam.mode=kubernetes --kube-context "${CLUSTER_2_CONTEXT}"
