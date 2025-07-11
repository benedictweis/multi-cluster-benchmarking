#!/usr/bin/env bash

cd "$(dirname "$0")" || exit 1

source ../../config.cfg
source ../../helper.sh

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

approachinfo "Deleting linkerd namespace"
kubectl delete namespace linkerd --context "$CLUSTER_1_CONTEXT" --ignore-not-found
kubectl delete namespace linkerd --context "$CLUSTER_2_CONTEXT" --ignore-not-found

approachinfo "Deleting linkerd-multicluster namespace"
kubectl delete namespace linkerd-multicluster --context "$CLUSTER_1_CONTEXT" --ignore-not-found
kubectl delete namespace linkerd-multicluster --context "$CLUSTER_2_CONTEXT" --ignore-not-found

approachinfo "Uninstalling Linkerd"
linkerd uninstall --context "$CLUSTER_1_CONTEXT" | kubectl delete --context "$CLUSTER_1_CONTEXT" -f -
linkerd uninstall --context "$CLUSTER_2_CONTEXT" | kubectl delete --context "$CLUSTER_2_CONTEXT" -f -

approachinfo "Uninstalling Gateway API CRDs"
kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml --context "$CLUSTER_1_CONTEXT"
kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml --context "$CLUSTER_2_CONTEXT"
