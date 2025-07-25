#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")" || exit 1

source ../../config.cfg
source ../../helper.sh

HELM_REPO_URL="https://helm.cilium.io/"

for CLUSTER_NAME in "${CLUSTER_1_NAME}" "${CLUSTER_2_NAME}"; do
    info "[$PROVIDER $CLUSTER_NAME] Creating kind cluster"
    kind create cluster --config "kind-${CLUSTER_NAME}.yaml"
    kubectl config use "kind-${CLUSTER_NAME}"

    if [[ "$CLUSTER_NAME" == "$CLUSTER_1_NAME" ]]; then
        export IPAM_CIDR="fd00:10:1::/112"
    else
        export IPAM_CIDR="fd00:10:2::/112"
    fi

    info "[$PROVIDER $CLUSTER_NAME] Installing Cilium"
    helm repo add cilium "${HELM_REPO_URL}"
    helm repo update
    helm upgrade --install --reset-values --version 1.17.5 -n kube-system cilium cilium/cilium \
        --set operator.replicas=1 \
        --set ipv4.enabled=false \
        --set ipv6.enabled=true \
        --set ipam.operator.clusterPoolIPv6PodCIDRList="{$IPAM_CIDR}" \
        --set routingMode=native \
        --set ipv6NativeRoutingCIDR="$IPAM_CIDR" \
        --set enableIPv6Masquerade=false

    info "[$PROVIDER $CLUSTER_NAME] Waiting for Cilium to be ready"
    cilium status --wait

    info "[$PROVIDER $CLUSTER_NAME] Deploying metallb"
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml
    info "[$PROVIDER $CLUSTER_NAME] Waiting for metallb to be ready"
    kubectl wait --namespace metallb-system \
        --for=condition=ready pod \
        --selector=component=controller \
        --timeout=90s
    sleep 5

    info "[$PROVIDER $CLUSTER_NAME] Configuring l2 advertisement."
    source ../../helper.sh # Reload NETWORK_PREFIX
    export NETWORK_PREFIX
    if [[ "$CLUSTER_NAME" == "$CLUSTER_1_NAME" ]]; then
        export START_GROUP=150
        export END_GROUP=175
    else
        export START_GROUP=176
        export END_GROUP=200
    fi
    envsubst <metallb-l2-advertisement.template.yaml | kubectl apply -f -
done

info "[$PROVIDER] Writing cluster contexts to files"
echo "kind-${CLUSTER_1_NAME}" >"../../$CONTEXT_1_FILE"
echo "kind-${CLUSTER_2_NAME}" >"../../$CONTEXT_2_FILE"

info "[$PROVIDER] Writing kubeconfig to file"
CLUSTER_1_TMP_KUBECONFIG_FILE=$(mktemp)
CLUSTER_2_TMP_KUBECONFIG_FILE=$(mktemp)
kind get kubeconfig --name="${CLUSTER_1_NAME}" >"$CLUSTER_1_TMP_KUBECONFIG_FILE"
kind get kubeconfig --name="${CLUSTER_2_NAME}" >"$CLUSTER_2_TMP_KUBECONFIG_FILE"
export KUBECONFIG="$CLUSTER_1_TMP_KUBECONFIG_FILE:$CLUSTER_2_TMP_KUBECONFIG_FILE"
kubectl config view --flatten >"../../$KUBECONFIG_FILE"

info "[$PROVIDER] Adjusting kubeconfig API server addresses"
CLUSTER_1_APISERVER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CLUSTER_1_NAME-control-plane")
CLUSTER_2_APISERVER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CLUSTER_2_NAME-control-plane")
# Detect OS and set proper sed command
if [[ $OSTYPE == darwin* ]]; then
    sed -i '' "s|127.0.0.1:6441|${CLUSTER_1_APISERVER_IP}:6443|g" "../../$KUBECONFIG_FILE"
    sed -i '' "s|127.0.0.1:6442|${CLUSTER_2_APISERVER_IP}:6443|g" "../../$KUBECONFIG_FILE"
else
    sed -i "s|127.0.0.1:6441|${CLUSTER_1_APISERVER_IP}:6443|g" "../../$KUBECONFIG_FILE"
    sed -i "s|127.0.0.1:6442|${CLUSTER_2_APISERVER_IP}:6443|g" "../../$KUBECONFIG_FILE"
fi

rm "$CLUSTER_1_TMP_KUBECONFIG_FILE" "$CLUSTER_2_TMP_KUBECONFIG_FILE"
