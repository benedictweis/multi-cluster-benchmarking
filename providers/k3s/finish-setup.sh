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
    .clusters[] |= 
        if .name == \"default\" then .name = \"$CLUSTER_1_NAME\" | .cluster else . end |
    .contexts[] |= 
        if .name == \"default\" then .name = \"$CLUSTER_1_NAME\" | .context.cluster = \"$CLUSTER_1_NAME\" | .context.user = \"user-1\" else . end |
    .users[] |= 
        if .name == \"default\" then .name = \"user-1\" else . end |
    .current-context = \"$CLUSTER_1_NAME\"
" "$KUBECONFIG_FILE_CLUSTER_1"

yq -i "
    .clusters[] |= 
        if .name == \"default\" then .name = \"$CLUSTER_2_NAME\" | .cluster else . end |
    .contexts[] |= 
        if .name == \"default\" then .name = \"$CLUSTER_2_NAME\" | .context.cluster = \"$CLUSTER_2_NAME\" | .context.user = \"user-2\" else . end |
    .users[] |= 
        if .name == \"default\" then .name = \"user-2\" else . end |
    .current-context = \"$CLUSTER_2_NAME\"
" "$KUBECONFIG_FILE_CLUSTER_2"

yq -i ".clusters[0].name = \"$CLUSTER_1_NAME\"" "$KUBECONFIG_FILE_CLUSTER_1"
yq -i ".clusters[0].name = \"$CLUSTER_2_NAME\"" "$KUBECONFIG_FILE_CLUSTER_2"

export KUBECONFIG="$KUBECONFIG_FILE_CLUSTER_1:$KUBECONFIG_FILE_CLUSTER_2"
kubectl config view --flatten >"../../$KUBECONFIG_FILE"
export KUBECONFIG="../../$KUBECONFIG_FILE"
