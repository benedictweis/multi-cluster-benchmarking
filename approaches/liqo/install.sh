#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")" || exit 1

source ../../config.cfg
source ../../helper.sh

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

approachinfo "Installing liqo"
liqoctl install --cluster-id $CLUSTER_1_NAME --pod-cidr="10.1.0.0/16" --service-cidr="10.10.0.0/16" --context "$CLUSTER_1_CONTEXT"
liqoctl install --cluster-id $CLUSTER_2_NAME --pod-cidr="10.2.0.0/16" --service-cidr="10.20.0.0/16" --context "$CLUSTER_2_CONTEXT"

approachinfo "Checking liqo installation"
liqoctl info --context "$CLUSTER_1_CONTEXT"
liqoctl info --context "$CLUSTER_2_CONTEXT"

approachinfo "Peering clusters"
liqoctl peer --context="$CLUSTER_2_CONTEXT" --remote-context="$CLUSTER_1_CONTEXT"
sleep 5

approachinfo "Checking peering status"
liqoctl info peer --context "$CLUSTER_1_CONTEXT"
liqoctl info peer --context "$CLUSTER_2_CONTEXT"
