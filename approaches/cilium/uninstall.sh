#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")" || exit 1

source ../../config.cfg
source ../../helper.sh

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

approachinfo "Uninstalling Cilium"
helm upgrade --install --reset-values --version 1.17.5 -n kube-system cilium cilium/cilium \
        --set ipam.mode=kubernetes \
        --set operator.replicas=1 \
        --kube-context "${CLUSTER_1_CONTEXT}" 
helm upgrade --install --reset-values --version 1.17.5 -n kube-system cilium cilium/cilium \
        --set ipam.mode=kubernetes \
        --set operator.replicas=1 \
        --kube-context "${CLUSTER_2_CONTEXT}"

approachinfo "Restarting all Cilium pods"
kubectl --context="${CLUSTER_1_CONTEXT}" -n kube-system delete pod -l app.kubernetes.io/part-of=cilium
kubectl --context="${CLUSTER_2_CONTEXT}" -n kube-system delete pod -l app.kubernetes.io/part-of=cilium 

approachinfo "Waiting for cilium to be ready"
cilium status --context "${CLUSTER_1_CONTEXT}" --wait
cilium status --context "${CLUSTER_2_CONTEXT}" --wait
