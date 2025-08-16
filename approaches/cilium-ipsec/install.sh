#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")" || exit 1

source ../../config.cfg
source ../../helper.sh

HELM_REPO_URL="https://helm.cilium.io/"

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

approachinfo "Adding cilium helm repo"
helm repo add cilium "${HELM_REPO_URL}"
helm repo update

approachinfo "Setting up network configuration"
if [[ "${PROVIDER}" == "kind" ]]; then
    export CLUSTER_1_CILIUM_APISERVER_IP="${NETWORK_PREFIX}159"
    export CLUSTER_2_CILIUM_APISERVER_IP="${NETWORK_PREFIX}179"
elif [[ "${PROVIDER}" == "k3s" ]]; then
    export CLUSTER_1_CILIUM_APISERVER_IP=$(kubectl --context "${CLUSTER_1_CONTEXT}" get node -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    export CLUSTER_2_CILIUM_APISERVER_IP=$(kubectl --context "${CLUSTER_2_CONTEXT}" get node -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
fi

approachinfo "Generating IPSec keys"
kubectl delete secret -n kube-system cilium-ipsec-keys --ignore-not-found --context "${CLUSTER_1_CONTEXT}"
kubectl delete secret -n kube-system cilium-ipsec-keys --ignore-not-found --context "${CLUSTER_2_CONTEXT}"
cilium encrypt create-key --auth-algo rfc4106-gcm-aes --context "${CLUSTER_1_CONTEXT}"
cilium encrypt create-key --auth-algo rfc4106-gcm-aes --context "${CLUSTER_2_CONTEXT}"
KEYID=$(kubectl get secret -n kube-system cilium-ipsec-keys --context "${CLUSTER_1_CONTEXT}" -o go-template --template="{{.data.keys}}" | base64 -d | grep -Eo "^[0-9]{1,2}" )
if [[ $KEYID -ge 15 ]]; then KEYID=0; fi
data=$(echo "{\"stringData\":{\"keys\":\"$((($KEYID+1)))+ "rfc4106\(gcm\(aes\)\)" $(dd if=/dev/urandom count=20 bs=1 2> /dev/null | xxd -p -c 64) 128\"}}")
kubectl patch secret -n kube-system cilium-ipsec-keys -p="${data}" -v=1 --context "${CLUSTER_1_CONTEXT}"
kubectl patch secret -n kube-system cilium-ipsec-keys -p="${data}" -v=1 --context "${CLUSTER_2_CONTEXT}"

approachinfo "Installing Cilium on cluster-1"
CILIUM_HELM_VALUES_FILE_1=$(mktemp)
envsubst <"cilium-$CLUSTER_1_NAME.yaml" >"${CILIUM_HELM_VALUES_FILE_1}"
helm upgrade --install --reset-values -n kube-system cilium cilium/cilium -f "${CILIUM_HELM_VALUES_FILE_1}" --kube-context "${CLUSTER_1_CONTEXT}"

approachinfo "Setting up shared CA"
kubectl --context="${CLUSTER_2_CONTEXT}" delete secret -n kube-system cilium-ca --ignore-not-found
kubectl --context="${CLUSTER_1_CONTEXT}" get secret -n kube-system cilium-ca -o yaml |
    kubectl --context "${CLUSTER_2_CONTEXT}" create -f -

approachinfo "Installing Cilium on cluster-2"
CILIUM_HELM_VALUES_FILE_2=$(mktemp)
envsubst <"cilium-$CLUSTER_2_NAME.yaml" >"${CILIUM_HELM_VALUES_FILE_2}"
helm upgrade --install --reset-values -n kube-system cilium cilium/cilium -f "${CILIUM_HELM_VALUES_FILE_2}" --kube-context "${CLUSTER_2_CONTEXT}"

approachinfo "Restarting all Cilium pods"
kubectl --context="${CLUSTER_1_CONTEXT}" -n kube-system delete pod -l app.kubernetes.io/part-of=cilium
kubectl --context="${CLUSTER_2_CONTEXT}" -n kube-system delete pod -l app.kubernetes.io/part-of=cilium

approachinfo "Waiting for cilium to be ready"
cilium status --context "${CLUSTER_1_CONTEXT}" --wait
cilium status --context "${CLUSTER_2_CONTEXT}" --wait

approachinfo "Waiting for clusters to be connected"
cilium clustermesh status --context "${CLUSTER_1_CONTEXT}" --wait
cilium clustermesh status --context "${CLUSTER_2_CONTEXT}" --wait

rm "${CILIUM_HELM_VALUES_FILE_1}" "${CILIUM_HELM_VALUES_FILE_2}"
