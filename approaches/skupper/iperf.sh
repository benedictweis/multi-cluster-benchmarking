#!/usr/bin/env bash

set -euo pipefail

source ../../helper.sh
source ../../config.cfg

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

approachinfo "Preparing skupper installation"
kubectl create namespace iperf --context "$CLUSTER_1_CONTEXT" --dry-run=client -o yaml | kubectl apply --context "$CLUSTER_1_CONTEXT" -f -
kubectl create namespace iperf --context "$CLUSTER_2_CONTEXT" --dry-run=client -o yaml | kubectl apply --context "$CLUSTER_2_CONTEXT" -f -
kubectl config set-context "$CLUSTER_1_CONTEXT" --namespace iperf
kubectl config set-context "$CLUSTER_2_CONTEXT" --namespace iperf

approachinfo "Installing skupper"
skupper init --context "$CLUSTER_1_CONTEXT"
skupper init --context "$CLUSTER_2_CONTEXT"

approachinfo "Generating cluster tokens"
CLUSTER_2_TOKEN_LOCATION=$(mktemp)
skupper token create "$CLUSTER_2_TOKEN_LOCATION" --context "$CLUSTER_2_CONTEXT"

approachinfo "Linking clusters"
skupper link create "$CLUSTER_2_TOKEN_LOCATION" --context "$CLUSTER_1_CONTEXT"

approachinfo "Exposing iperf-server"
skupper expose deployment/iperf-server --port 5201 --context "$CLUSTER_1_CONTEXT"

kubectl config set-context "$CLUSTER_1_CONTEXT" --namespace=default
kubectl config set-context "$CLUSTER_2_CONTEXT" --namespace=default
