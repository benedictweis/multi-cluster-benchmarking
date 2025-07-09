#!/usr/bin/env bash

set -euo pipefail

source ../../config.cfg
source ../../helper.sh

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

approachinfo "Getting server address"
sleep 5
LB_HOSTNAME=$(kubectl get service iperf-server -n iperf -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' --context "$CLUSTER_1_CONTEXT")
LB_IP=$(kubectl get service iperf-server -n iperf -o jsonpath='{.status.loadBalancer.ingress[0].ip}' --context "$CLUSTER_1_CONTEXT")
approachinfo "LB Hostname: $LB_HOSTNAME"
approachinfo "LB IP: $LB_IP"

SERVER_ADDRESS=${LB_HOSTNAME:-$LB_IP}

approachinfo "Creating ConfigMap"
kubectl apply -f - --context "$CLUSTER_2_CONTEXT" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
    name: iperf-config
    namespace: iperf
data:
    SERVER_ADDRESS: "$SERVER_ADDRESS"
    INITIAL_SLEEP: "50"
EOF
