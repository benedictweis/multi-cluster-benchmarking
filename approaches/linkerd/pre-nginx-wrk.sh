#!/usr/bin/env bash

set -euo pipefail

source ../../helper.sh
source ../../config.cfg

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

approachinfo "Annotating namespaces for Linkerd Sidecar injection"
kubectl apply --context "$CLUSTER_1_CONTEXT" -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
    name: nginx-wrk
    annotations:
        linkerd.io/inject: enabled
EOF

kubectl apply --context "$CLUSTER_2_CONTEXT" -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
    name: nginx-wrk
    annotations:
        linkerd.io/inject: enabled
EOF
