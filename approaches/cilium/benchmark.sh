#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")" || exit 1

source ../../config.cfg
source ../../helper.sh

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

SERVICE_MANIFEST=$(
    cat <<EOF
apiVersion: v1
kind: Service
metadata:
    name: $BENCHMARK-server
    namespace: $BENCHMARK
    annotations:
        service.cilium.io/global: "true"
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
kubectl --context="$CLUSTER_2_CONTEXT" apply -f - <<<"$SERVICE_MANIFEST"

export SERVER_ADDRESS="$BENCHMARK-server"
