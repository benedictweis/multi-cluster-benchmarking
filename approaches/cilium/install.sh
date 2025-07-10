#!/usr/bin/env bash

set -euo pipefail

source ../../config.cfg
source ../../helper.sh

HELM_REPO_URL="https://helm.cilium.io/"
CILIUM_HELM_VALUES_FILE="cilium.yaml"

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

approachinfo "Adding cilium helm repo"
helm repo add cilium "${HELM_REPO_URL}"
helm repo update

approachinfo "Setting up network configuration"
if [[ "${PROVIDER}" == "kind" ]]; then
    export CLUSTER_1_CILIUM_APISERVER_IP="$NETWORK_PREFIX.159"
    export CLUSTER_2_CILIUM_APISERVER_IP="$NETWORK_PREFIX.160"
elif [[ "${PROVIDER}" == "k3s" ]]; then
    export CLUSTER_1_CILIUM_APISERVER_IP=$(kubectl --context "${CLUSTER_1_CONTEXT}" get node -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    export CLUSTER_2_CILIUM_APISERVER_IP=$(kubectl --context "${CLUSTER_2_CONTEXT}" get node -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
fi

approachinfo "Installing Cilium on cluster-1"
CILIUM_HELM_VALUES_FILE_1=$(mktemp)
envsubst <"${CLUSTER_1_NAME}/${CILIUM_HELM_VALUES_FILE}" >"${CILIUM_HELM_VALUES_FILE_1}"
helm upgrade --install --reset-values -n kube-system cilium cilium/cilium -f "${CILIUM_HELM_VALUES_FILE_1}" --kube-context "${CLUSTER_1_CONTEXT}"

approachinfo "Setting up shared CA"
kubectl --context="${CLUSTER_2_CONTEXT}" delete secret -n kube-system cilium-ca --ignore-not-found
kubectl --context="${CLUSTER_1_CONTEXT}" get secret -n kube-system cilium-ca -o yaml |
    kubectl --context "${CLUSTER_2_CONTEXT}" create -f -

approachinfo "Installing Cilium on cluster-2"
CILIUM_HELM_VALUES_FILE_2=$(mktemp)
envsubst <"${CLUSTER_2_NAME}/${CILIUM_HELM_VALUES_FILE}" >"${CILIUM_HELM_VALUES_FILE_2}"
helm upgrade --install --reset-values -n kube-system cilium cilium/cilium -f "${CILIUM_HELM_VALUES_FILE_2}" --kube-context "${CLUSTER_2_CONTEXT}"

approachinfo "Restarting all Cilium pods in cluster-2"
kubectl --context="${CLUSTER_2_CONTEXT}" -n kube-system delete pod -l k8s-app=cilium

approachinfo "Scaling deployments"
kubectl -n kube-system scale deployment cilium-operator --replicas=1 --context "${CLUSTER_1_CONTEXT}"
kubectl -n kube-system scale deployment cilium-operator --replicas=1 --context "${CLUSTER_2_CONTEXT}"

approachinfo "Waiting for cluster to be ready"
cilium status --context "${CLUSTER_1_CONTEXT}" --wait
cilium status --context "${CLUSTER_2_CONTEXT}" --wait

approachinfo "Waiting for clusters to be connected"
cilium clustermesh status --context "${CLUSTER_1_CONTEXT}" --wait
cilium clustermesh status --context "${CLUSTER_2_CONTEXT}" --wait
