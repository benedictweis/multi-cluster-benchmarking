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
    annotations:
       linkerd.io/inject: enabled
EOF
)

approachinfo "Annotating namespaces for Linkerd Sidecar injection"
kubectl apply --context "$CLUSTER_1_CONTEXT" -f - <<<"$NAMESPACE_MANIFEST"
kubectl apply --context "$CLUSTER_2_CONTEXT" -f - <<<"$NAMESPACE_MANIFEST"

PORT=80
if [[ "${BENCHMARK}" == "iperf" ]]; then
    PORT=5201
fi
SERVICE_MANIFEST=$(
    cat <<EOF
apiVersion: v1
kind: Service
metadata:
    name: $BENCHMARK-server
    namespace: $BENCHMARK
    labels:
        mirror.linkerd.io/exported: "true"
spec:
    selector:
        app: $BENCHMARK-server
    ports:
        - protocol: TCP
          port: $PORT
          targetPort: $PORT
    type: ClusterIP
EOF
)

approachinfo "Applying service manifest"
kubectl --context="$CLUSTER_1_CONTEXT" apply -f - <<<"$SERVICE_MANIFEST"

export SERVER_ADDRESS="$BENCHMARK-server-cluster-1"
