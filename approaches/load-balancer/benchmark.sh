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
spec:
    selector:
        app: $BENCHMARK-server
    ports:
$PORTS
    type: LoadBalancer
EOF
)

approachinfo "Applying service manifest"
kubectl --context="$CLUSTER_1_CONTEXT" apply -f - <<<"$SERVICE_MANIFEST"

approachinfo "Getting server address"
sleep 5
LB_HOSTNAME=$(kubectl get service $BENCHMARK-server -n $BENCHMARK -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' --context "$CLUSTER_1_CONTEXT")
LB_IP=$(kubectl get service $BENCHMARK-server -n $BENCHMARK -o jsonpath='{.status.loadBalancer.ingress[0].ip}' --context "$CLUSTER_1_CONTEXT")
approachinfo "LB Hostname: $LB_HOSTNAME"
approachinfo "LB IP: $LB_IP"

export SERVER_ADDRESS=${LB_HOSTNAME:-$LB_IP}
