#!/usr/bin/env bash

set -euo pipefail

source ../../helper.sh
source ../../config.cfg

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")

approachinfo "Offloading nginx-curl namespace"
liqoctl offload namespace nginx-curl \
    --context "$CLUSTER_1_CONTEXT" \
    --namespace-mapping-strategy EnforceSameName \
    --pod-offloading-strategy Local
