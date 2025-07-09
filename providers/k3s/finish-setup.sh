#!/usr/bin/env bash

set -euo pipefail

source ../../config.cfg
source ../../helper.sh

bash ../../install-docker.sh

KUBECONFIG_FILE_CLUSTER_1="../../kubeconfig_instance_1.yaml"
KUBECONFIG_FILE_CLUSTER_2="../../kubeconfig_instance_2.yaml"

echo $CLUSTER_1_NAME >"../../$CONTEXT_1_FILE"
echo $CLUSTER_2_NAME >"../../$CONTEXT_2_FILE"

yq -i "
  (.clusters[] | select(.name == \"default\")).name = env.CLUSTER_1_NAME |
  (.contexts[] | select(.name == \"default\")).name = env.CLUSTER_1_NAME |
  (.contexts[] | select(.name == env.CLUSTER_1_NAME)).context.cluster = env.CLUSTER_1_NAME |
  (.contexts[] | select(.name == env.CLUSTER_1_NAME)).context.user = \"user-1\" |
  (.users[] | select(.name == \"default\")).name = \"user-1\" |
  .[\"current-context\"] = env.CLUSTER_1_NAME
" "$KUBECONFIG_FILE_CLUSTER_1"

yq -i "
  (.clusters[] | select(.name == \"default\")).name = env.CLUSTER_2_NAME |
  (.contexts[] | select(.name == \"default\")).name = env.CLUSTER_2_NAME |
  (.contexts[] | select(.name == env.CLUSTER_2_NAME)).context.cluster = env.CLUSTER_2_NAME |
  (.contexts[] | select(.name == env.CLUSTER_2_NAME)).context.user = \"user-2\" |
  (.users[] | select(.name == \"default\")).name = \"user-2\" |
  .[\"current-context\"] = env.CLUSTER_2_NAME
" "$KUBECONFIG_FILE_CLUSTER_2"

yq -i ".clusters[0].name = \"$CLUSTER_1_NAME\"" "$KUBECONFIG_FILE_CLUSTER_1"
yq -i ".clusters[0].name = \"$CLUSTER_2_NAME\"" "$KUBECONFIG_FILE_CLUSTER_2"

export KUBECONFIG="$KUBECONFIG_FILE_CLUSTER_1:$KUBECONFIG_FILE_CLUSTER_2"
kubectl config view --flatten >"../../$KUBECONFIG_FILE"
export KUBECONFIG="../../$KUBECONFIG_FILE"
