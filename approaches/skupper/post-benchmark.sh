#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")" || exit 1

source ../../config.cfg
source ../../helper.sh

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

approachinfo "Preparing skupper installation"
kubectl create namespace $BENCHMARK --context "$CLUSTER_1_CONTEXT" --dry-run=client -o yaml | kubectl apply --context "$CLUSTER_1_CONTEXT" -f -
kubectl create namespace $BENCHMARK --context "$CLUSTER_2_CONTEXT" --dry-run=client -o yaml | kubectl apply --context "$CLUSTER_2_CONTEXT" -f -
kubectl config set-context "$CLUSTER_1_CONTEXT" --namespace $BENCHMARK
kubectl config set-context "$CLUSTER_2_CONTEXT" --namespace $BENCHMARK

approachinfo "Installing skupper"
skupper init --context "$CLUSTER_1_CONTEXT"
skupper init --context "$CLUSTER_2_CONTEXT"

approachinfo "Generating cluster tokens"
CLUSTER_2_TOKEN_LOCATION=$(mktemp)
skupper token create "$CLUSTER_2_TOKEN_LOCATION" --context "$CLUSTER_2_CONTEXT"

approachinfo "Linking clusters"
skupper link create "$CLUSTER_2_TOKEN_LOCATION" --context "$CLUSTER_1_CONTEXT"

PORT=80
if [[ "${BENCHMARK}" == "iperf" ]]; then
    PORT=5201
fi

approachinfo "Exposing $BENCHMARK-server"
skupper expose deployment/$BENCHMARK-server --port $PORT --context "$CLUSTER_1_CONTEXT"

kubectl config set-context "$CLUSTER_1_CONTEXT" --namespace=default
kubectl config set-context "$CLUSTER_2_CONTEXT" --namespace=default

rm "$CLUSTER_2_TOKEN_LOCATION"

export SERVER_ADDRESS="$BENCHMARK-server"
