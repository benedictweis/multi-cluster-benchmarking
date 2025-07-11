#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")" || exit 1

source ../../config.cfg
source ../../helper.sh

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

approachinfo "Getting server address"
sleep 5
LB_HOSTNAME=$(kubectl get service nginx-server -n nginx-wrk -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' --context "$CLUSTER_1_CONTEXT")
LB_IP=$(kubectl get service nginx-server -n nginx-wrk -o jsonpath='{.status.loadBalancer.ingress[0].ip}' --context "$CLUSTER_1_CONTEXT")
approachinfo "LB Hostname: $LB_HOSTNAME"
approachinfo "LB IP: $LB_IP"

SERVER_ADDRESS=${LB_HOSTNAME:-$LB_IP}

approachinfo "Creating ConfigMap"
kubectl apply -f - --context "$CLUSTER_2_CONTEXT" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
    name: nginx-config
    namespace: nginx-wrk
data:
    SERVER_ADDRESS: "$SERVER_ADDRESS"  
    INITIAL_SLEEP: "50"
EOF
