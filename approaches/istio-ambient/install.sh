#!/usr/bin/env bash
#https://istio.io/latest/docs/setup/install/multicluster/multi-primary_multi-network/

set -euo pipefail

cd "$(dirname "$0")" || exit 1

source ../../config.cfg
source ../../helper.sh

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

approachinfo "Installing Gateway API"
kubectl get crd gateways.gateway.networking.k8s.io --context "$CLUSTER_1_CONTEXT" &> /dev/null || \
  kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml --context "$CLUSTER_1_CONTEXT"
kubectl get crd gateways.gateway.networking.k8s.io --context "$CLUSTER_2_CONTEXT" &> /dev/null || \
  kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml --context "$CLUSTER_2_CONTEXT"

approachinfo "Labeling namespace in cluster-1"
kubectl --context="$CLUSTER_1_CONTEXT" create namespace istio-system
kubectl --context="$CLUSTER_1_CONTEXT" label namespace istio-system topology.istio.io/network=network1

approachinfo "Adding Istio Helm repository"
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

approachinfo "Installing Istio in cluster-1"
helm install istio-base istio/base -n istio-system --kube-context "$CLUSTER_1_CONTEXT" --wait
helm install istiod istio/istiod -n istio-system --kube-context "$CLUSTER_1_CONTEXT" --wait \
    --set global.meshID=mesh1 \
    --set global.multiCluster.clusterName="$CLUSTER_1_NAME" \
    --set global.network=network1 \
    --set profile=ambient \
    --set env.AMBIENT_ENABLE_MULTI_NETWORK="true"
helm install istio-cni istio/cni -n istio-system --kube-context "$CLUSTER_1_CONTEXT" --wait \
    --set profile=ambient
helm install ztunnel istio/ztunnel -n istio-system --kube-context "$CLUSTER_1_CONTEXT" --wait \
    --set multiCluster.clusterName="$CLUSTER_1_NAME" \
    --set global.network=network1

approachinfo "Installing Istio east-west gateway in cluster-1"
kubectl apply --context="$CLUSTER_1_CONTEXT" -f cluster1-ewgateway.yaml

approachinfo "Labeling namespace in cluster-2"
kubectl --context="$CLUSTER_2_CONTEXT" create namespace istio-system
kubectl --context="$CLUSTER_2_CONTEXT" label namespace istio-system topology.istio.io/network=network2

approachinfo "Setting up shared CA"
kubectl --context="${CLUSTER_2_CONTEXT}" delete secret -n istio-system istio-ca-secret --ignore-not-found
kubectl --context="${CLUSTER_1_CONTEXT}" get secret -n istio-system istio-ca-secret -o yaml |
    kubectl --context "${CLUSTER_2_CONTEXT}" create -f -

approachinfo "Installing Istio in cluster-2"
helm install istio-base istio/base -n istio-system --kube-context "$CLUSTER_2_CONTEXT" --wait
helm install istiod istio/istiod -n istio-system --kube-context "$CLUSTER_2_CONTEXT" --wait \
    --set global.meshID=mesh1 \
    --set global.multiCluster.clusterName="$CLUSTER_2_NAME" \
    --set global.network=network2 \
    --set profile=ambient \
    --set env.AMBIENT_ENABLE_MULTI_NETWORK="true"
helm install istio-cni istio/cni -n istio-system --kube-context "$CLUSTER_2_CONTEXT" --wait \
    --set profile=ambient
helm install ztunnel istio/ztunnel -n istio-system --kube-context "$CLUSTER_2_CONTEXT" --wait \
    --set multiCluster.clusterName="$CLUSTER_2_NAME" \
    --set global.network=network2

approachinfo "Installing Istio east-west gateway in cluster-2"
kubectl apply --context="$CLUSTER_2_CONTEXT" -f cluster2-ewgateway.yaml
sleep 5

approachinfo "Installing remote secrets"
istioctl create-remote-secret \
  --context="${CLUSTER_1_CONTEXT}" \
  --name=cluster1 | \
  kubectl apply -f - --context="${CLUSTER_2_CONTEXT}"
istioctl create-remote-secret \
  --context="${CLUSTER_2_CONTEXT}" \
  --name=cluster2 | \
  kubectl apply -f - --context="${CLUSTER_1_CONTEXT}"
sleep 5

approachinfo "Verifying Istio Multi-Cluster Installation"
istioctl remote-clusters --context="${CLUSTER_1_CONTEXT}"
istioctl remote-clusters --context="${CLUSTER_2_CONTEXT}"
