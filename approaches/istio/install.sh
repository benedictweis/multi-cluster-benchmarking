#!/usr/bin/env bash
#https://istio.io/latest/docs/setup/install/multicluster/multi-primary_multi-network/

set -euo pipefail

source ../../helper.sh
source ../../config.cfg

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

approachinfo "Labeling namespace in cluster-1"
kubectl --context="$CLUSTER_1_CONTEXT" create namespace istio-system
kubectl --context="$CLUSTER_1_CONTEXT" label namespace istio-system topology.istio.io/network=network1

approachinfo "Adding Istio Helm repository"
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

approachinfo "Installing Istio in cluster-1"
helm install istio-base istio/base -n istio-system --kube-context "$CLUSTER_1_CONTEXT"
helm install istiod istio/istiod -n istio-system --kube-context "$CLUSTER_1_CONTEXT" \
    --set global.meshID=mesh1 \
    --set global.externalIstiod=true \
    --set global.multiCluster.clusterName="$CLUSTER_1_NAME" \
    --set global.network=network1
helm install istio-eastwestgateway istio/gateway -n istio-system --kube-context "$CLUSTER_1_CONTEXT" \
    --set name=istio-eastwestgateway \
    --set networkGateway=network1

approachinfo "Exposing Istio gateway"
kubectl apply --context="$CLUSTER_1_CONTEXT" -n istio-system -f expose-istiod.yaml

approachinfo "Labeling namespace in cluster-2"
kubectl --context="$CLUSTER_2_CONTEXT" create namespace istio-system
kubectl --context="$CLUSTER_2_CONTEXT" annotate namespace istio-system topology.istio.io/controlPlaneClusters="$CLUSTER_1_NAME"
kubectl --context="$CLUSTER_2_CONTEXT" label namespace istio-system topology.istio.io/network=network2

approachinfo "Installing Istio in cluster-2"
DISCOVERY_ADDRESS=$(kubectl \
    --context="$CLUSTER_1_CONTEXT" \
    -n istio-system get svc istio-eastwestgateway \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
helm install istio-base istio/base -n istio-system --set profile=remote --kube-context "$CLUSTER_2_CONTEXT"
helm install istiod istio/istiod -n istio-system \
    --set profile=remote \
    --set global.multiCluster.clusterName="$CLUSTER_2_NAME" \
    --set global.network=network2 \
    --set istiodRemote.injectionPath=/inject/cluster/"$CLUSTER_2_NAME"/net/network2 \
    --set global.configCluster=true \
    --set global.remotePilotAddress="${DISCOVERY_ADDRESS}" \
    --kube-context "$CLUSTER_2_CONTEXT"

approachinfo "Attaching cluster-2 as remote cluster of cluster-1"
istioctl create-remote-secret \
    --context="$CLUSTER_2_CONTEXT" \
    --name="$CLUSTER_2_NAME" |
    kubectl apply -f - --context="$CLUSTER_1_CONTEXT"

approachinfo "Installing gateway in cluster-2"
helm install istio-eastwestgateway istio/gateway -n istio-system --kube-context "$CLUSTER_2_CONTEXT" \
    --set name=istio-eastwestgateway \
    --set networkGateway=network2

approachinfo "Exposing services in cluster-1 and cluster-2"
kubectl --context="$CLUSTER_1_CONTEXT" apply -n istio-system -f ./expose-services.yaml
sleep 1

approachinfo "Verifying Istio Multi-Cluster Installation"
istioctl remote-clusters --context="${CLUSTER_1_CONTEXT}"
