#!/usr/bin/env bash

set -euo pipefail

source ../../config.cfg
source ../../helper.sh

bash ../../install-docker.sh

KUBECONFIG_FILE_CLUSTER_1="../../kubeconfig_instance_1.yaml"
KUBECONFIG_FILE_CLUSTER_2="../../kubeconfig_instance_2.yaml"

echo $CLUSTER_1_NAME >"../../$CONTEXT_1_FILE"
echo $CLUSTER_2_NAME >"../../$CONTEXT_2_FILE"

#kubectl --kubeconfig="$KUBECONFIG_FILE_CLUSTER_1" config rename-context "$(kubectl --kubeconfig="$KUBECONFIG_FILE_CLUSTER_1" config current-context)" "$CLUSTER_1_NAME"
#kubectl --kubeconfig="$KUBECONFIG_FILE_CLUSTER_2" config rename-context "$(kubectl --kubeconfig="$KUBECONFIG_FILE_CLUSTER_2" config current-context)" "$CLUSTER_2_NAME"

export KUBECONFIG="$KUBECONFIG_FILE_CLUSTER_1:$KUBECONFIG_FILE_CLUSTER_2"
kubectl config view --flatten >"../../$KUBECONFIG_FILE"
export KUBECONFIG="../../$KUBECONFIG_FILE"
