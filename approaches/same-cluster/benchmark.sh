#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")" || exit 1

source ../../config.cfg
source ../../helper.sh

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

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

export SERVER_ADDRESS="$BENCHMARK-server"
