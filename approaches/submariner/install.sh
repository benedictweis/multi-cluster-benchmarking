#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")" || exit 1

source ../../config.cfg
source ../../helper.sh

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

BROKER_FILE="broker-info.subm"

approachinfo "Deploying Broker to cluster-1"
subctl deploy-broker --context "$CLUSTER_1_CONTEXT"

approachinfo "Joining clusters to broker"
subctl join --context "$CLUSTER_1_CONTEXT" --clusterid "$CLUSTER_1_NAME" "$BROKER_FILE" --natt=false
subctl join --context "$CLUSTER_2_CONTEXT" --clusterid "$CLUSTER_2_NAME" "$BROKER_FILE" --natt=false
sleep 5

rm "$BROKER_FILE"
