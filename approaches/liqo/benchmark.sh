#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")" || exit 1

source ../../config.cfg
source ../../helper.sh

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")

SERVICE_MANIFEST=$(
    cat <<EOF
apiVersion: v1
kind: Service
metadata:
    name: $BENCHMARK-server
    namespace: $BENCHMARK
spec:
    selector:
        app: $BENCHMARK-server
    ports:
$PORTS
    type: ClusterIP
EOF
)

approachinfo "Applying service manifest"
kubectl --context="$CLUSTER_1_CONTEXT" apply -f - <<<"$SERVICE_MANIFEST"

approachinfo "Offloading $BENCHMARK namespace"
liqoctl offload namespace $BENCHMARK \
    --context "$CLUSTER_1_CONTEXT" \
    --namespace-mapping-strategy EnforceSameName \
    --pod-offloading-strategy Local

export SERVER_ADDRESS="$BENCHMARK-server"
