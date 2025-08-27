#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")" || exit 1

source ../../config.cfg
source ../../helper.sh

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

NAMESPACE_MANIFEST=$(
    cat <<EOF
apiVersion: v1
kind: Namespace
metadata:
    name: $BENCHMARK
    labels:
       istio.io/dataplane-mode: ambient
EOF
)

approachinfo "Annotating namespaces for Istio Sidecar injection"
kubectl apply --context "$CLUSTER_1_CONTEXT" -f - <<<"$NAMESPACE_MANIFEST"
kubectl apply --context "$CLUSTER_2_CONTEXT" -f - <<<"$NAMESPACE_MANIFEST"

SERVICE_MANIFEST=$(
    cat <<EOF
apiVersion: v1
kind: Service
metadata:
    name: $BENCHMARK-server
    namespace: $BENCHMARK
    labels:
        istio.io/global: "true"
spec:
    selector:
        app: $BENCHMARK-server
    ports:
$PORTS
    type: ClusterIP
EOF
)

approachinfo "Applying service manifest"
kubectl apply --context "$CLUSTER_1_CONTEXT" -f - <<<"$SERVICE_MANIFEST"
kubectl apply --context "$CLUSTER_2_CONTEXT" -f - <<<"$SERVICE_MANIFEST"

export SERVER_ADDRESS="$BENCHMARK-server"
