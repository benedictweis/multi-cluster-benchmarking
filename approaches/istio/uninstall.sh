#!/usr/bin/env bash
#https://istio.io/latest/docs/setup/install/multicluster/multi-primary_multi-network/

set -euo pipefail

source ../../config.cfg
source ../../helper.sh

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

approachinfo "Uninstalling Istio in cluster-1"
helm delete istiod -n istio-system --kube-context "$CLUSTER_1_CONTEXT"
helm delete istio-eastwestgateway -n istio-system --kube-context "$CLUSTER_1_CONTEXT"
helm delete istio-base -n istio-system --kube-context "$CLUSTER_1_CONTEXT"

kubectl delete ns istio-system --context="$CLUSTER_1_CONTEXT"

approachinfo "Uninstalling Istio in cluster-2"
helm delete istiod -n istio-system --kube-context "$CLUSTER_2_CONTEXT"
helm delete istio-eastwestgateway -n istio-system --kube-context "$CLUSTER_2_CONTEXT"
helm delete istio-base -n istio-system --kube-context "$CLUSTER_2_CONTEXT"

kubectl delete ns istio-system --context="$CLUSTER_2_CONTEXT"

approachinfo "Uninstalling Istio crds"
kubectl get crd -oname --context "$CLUSTER_1_CONTEXT" | grep --color=never 'istio.io' | xargs kubectl delete --context "$CLUSTER_1_CONTEXT"
kubectl get crd -oname --context "$CLUSTER_2_CONTEXT" | grep --color=never 'istio.io' | xargs kubectl delete --context "$CLUSTER_2_CONTEXT"
