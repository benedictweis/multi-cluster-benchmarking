#!/usr/bin/env bash

set -euo pipefail

source ../../helper.sh
source ../../config.cfg

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

approachinfo "Labeling namespaces for Istio injection"
kubectl label --context="${CLUSTER_1_CONTEXT}" namespace nginx-wrk \
    istio-injection=enabled
kubectl label --context="${CLUSTER_2_CONTEXT}" namespace nginx-wrk \
    istio-injection=enabled

sleep 10
