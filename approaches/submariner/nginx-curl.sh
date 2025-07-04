#!/usr/bin/env bash

set -euo pipefail

source ../../helper.sh
source ../../config.cfg

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

approachinfo "Exposing nginx-curl"
kubectl --context "$CLUSTER_1_CONTEXT" --namespace nginx-curl expose deployment/nginx-server --port 80

approachinfo "Exporting service"
subctl export service --context "$CLUSTER_1_CONTEXT" --namespace nginx-curl nginx-server
