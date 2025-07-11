#!/usr/bin/env bash

set -euo pipefail

source ../../config.cfg
source ../../helper.sh

KUBECONFIG_FILE_CLUSTER_1="../../kubeconfig_instance_1.yaml"
KUBECONFIG_FILE_CLUSTER_2="../../kubeconfig_instance_2.yaml"

echo $CLUSTER_1_NAME >"../../$CONTEXT_1_FILE"
echo $CLUSTER_2_NAME >"../../$CONTEXT_2_FILE"

info "[$PROVIDER $CLUSTER_1_NAME] Adjusting kubeconfig file for cluster 1"
yq -i '.clusters[0].name = "cluster-1"' "$KUBECONFIG_FILE_CLUSTER_1"
yq -i '.contexts[0].name = "cluster-1"' "$KUBECONFIG_FILE_CLUSTER_1"
yq -i '.contexts[0].context.cluster = "cluster-1"' "$KUBECONFIG_FILE_CLUSTER_1"
yq -i '.contexts[0].context.user = "user-1"' "$KUBECONFIG_FILE_CLUSTER_1"
yq -i '.current-context = "cluster-1"' "$KUBECONFIG_FILE_CLUSTER_1"
yq -i '.users[0].name = "user-1"' "$KUBECONFIG_FILE_CLUSTER_1"

info "[$PROVIDER $CLUSTER_2_NAME] Adjusting kubeconfig file for cluster 2"
yq -i '.clusters[0].name = "cluster-2"' "$KUBECONFIG_FILE_CLUSTER_2"
yq -i '.contexts[0].name = "cluster-2"' "$KUBECONFIG_FILE_CLUSTER_2"
yq -i '.contexts[0].context.cluster = "cluster-2"' "$KUBECONFIG_FILE_CLUSTER_2"
yq -i '.contexts[0].context.user = "user-2"' "$KUBECONFIG_FILE_CLUSTER_2"
yq -i '.current-context = "cluster-2"' "$KUBECONFIG_FILE_CLUSTER_2"
yq -i '.users[0].name = "user-2"' "$KUBECONFIG_FILE_CLUSTER_2"

info "[$PROVIDER] Merging kubeconfig files"
export KUBECONFIG="$KUBECONFIG_FILE_CLUSTER_1:$KUBECONFIG_FILE_CLUSTER_2"
kubectl config view --flatten >"../../$KUBECONFIG_FILE"
export KUBECONFIG="../../$KUBECONFIG_FILE"

for CLUSTER_NAME in "${CLUSTER_1_NAME}" "${CLUSTER_2_NAME}"; do
    kubectl config use "${CLUSTER_NAME}"

    info "[$PROVIDER $CLUSTER_NAME] Deploying metallb"
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml
    info "[$PROVIDER $CLUSTER_NAME] Waiting for metallb to be ready"
    kubectl wait --namespace metallb-system \
        --for=condition=ready pod \
        --selector=component=controller \
        --timeout=90s
    sleep 5

    info "[$PROVIDER $CLUSTER_NAME] Configuring l2 advertisement."
    export NODE_IP_ADDR=$(kubectl get node -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    envsubst <metallb-l2-advertisement.template.yaml | kubectl apply -f -

    info "[$PROVIDER $CLUSTER_NAME] Deploying metrics server"
    kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml --ignore-not-found
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    kubectl patch deployment metrics-server -n kube-system --type='json' --patch-file=./metrics-server-patch.json
    info "[$PROVIDER $CLUSTER_NAME] Waiting for metrics server deployment to be ready"
    kubectl -n kube-system wait --for=condition=available --timeout=90s deployment/metrics-server
done
