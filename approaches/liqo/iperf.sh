#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")" || exit 1

source ../../config.cfg
source ../../helper.sh

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")

approachinfo "Offloading iperf namespace"
liqoctl offload namespace iperf \
    --context "$CLUSTER_1_CONTEXT" \
    --namespace-mapping-strategy EnforceSameName \
    --pod-offloading-strategy Local
