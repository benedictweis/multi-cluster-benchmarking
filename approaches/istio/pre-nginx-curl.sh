#!/usr/bin/env bash

set -euo pipefail

source ../../config.cfg
source ../../helper.sh

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

approachinfo "Annotating namespaces for Istio Sidecar injection"
kubectl apply --context "$CLUSTER_1_CONTEXT" -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
    name: nginx-curl
    labels:
       istio-injection: enabled
EOF

kubectl apply --context "$CLUSTER_2_CONTEXT" -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
    name: nginx-curl
    labels:
       istio-injection: enabled
EOF
