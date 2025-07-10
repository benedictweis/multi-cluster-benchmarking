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

for CLUSTER_NAME in "${CLUSTER_1_NAME}" "${CLUSTER_2_NAME}"; do
    info "[$PROVIDER $CLUSTER_NAME] Deploying metallb"
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml
    info "[$PROVIDER $CLUSTER_NAME] Waiting for metallb to be ready"
    kubectl wait --namespace metallb-system \
        --for=condition=ready pod \
        --selector=component=controller \
        --timeout=90s
    sleep 5

    info "[$PROVIDER $CLUSTER_NAME] Configuring l2 advertisement."
    source ../../helper.sh # Recalculate NETWORK_PREFIX
    if [[ "$CLUSTER_NAME" == "$CLUSTER_1_NAME" ]]; then
        export START_GROUP=150
        export END_GROUP=175
    else
        export START_GROUP=176
        export END_GROUP=200
    fi
    envsubst <metallb-l2-advertisement.template.yaml | kubectl apply -f -
done
