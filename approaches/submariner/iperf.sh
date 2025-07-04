#!/usr/bin/env bash

# https://piotrminkowski.com/2021/07/08/kubernetes-multicluster-with-kind-and-submariner/

set -euo pipefail

source ../../helper.sh
source ../../config.cfg

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

approachinfo "Exposing iperf-server"
kubectl --context "$CLUSTER_1_CONTEXT" --namespace iperf expose deployment/iperf-server --port 5201

approachinfo "Exporting service"
subctl export service --context "$CLUSTER_1_CONTEXT" --namespace iperf iperf-server
