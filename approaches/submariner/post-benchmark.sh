#!/usr/bin/env bash

# https://piotrminkowski.com/2021/07/08/kubernetes-multicluster-with-kind-and-submariner/

set -euo pipefail

cd "$(dirname "$0")" || exit 1

source ../../config.cfg
source ../../helper.sh

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

PORT=80
if [[ "${BENCHMARK}" == "iperf" ]]; then
    PORT=5201
fi

approachinfo "Exposing $BENCHMARK-server"
kubectl --context "$CLUSTER_1_CONTEXT" --namespace $BENCHMARK expose deployment/$BENCHMARK-server --port $PORT

approachinfo "Exporting service"
subctl export service --context "$CLUSTER_1_CONTEXT" --namespace $BENCHMARK $BENCHMARK-server

export SERVER_ADDRESS="$BENCHMARK-server.$BENCHMARK.svc.clusterset.local"
