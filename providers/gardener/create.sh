#!/usr/bin/env bash

set -euo pipefail

source ../../helper.sh
source ../../config.cfg
source .env

KUBECONFIG_FILE_1=$(mktemp)
KUBECONFIG_FILE_2=$(mktemp)
gardenctl kubeconfig --flatten --garden "$GARDENER_LANDSCAPE" --project "$GARDENER_PROJECT" --shoot "$GARDENER_SHOOT_1" >"$KUBECONFIG_FILE_1"
gardenctl kubeconfig --flatten --garden "$GARDENER_LANDSCAPE" --project "$GARDENER_PROJECT" --shoot "$GARDENER_SHOOT_2" >"$KUBECONFIG_FILE_2"

export KUBECONFIG="$KUBECONFIG_FILE_1:$KUBECONFIG_FILE_2"
kubectl config view --flatten >"../../$KUBECONFIG_FILE"

echo "garden-$GARDENER_PROJECT--$GARDENER_SHOOT_1-external" >"../../$CONTEXT_1_FILE"
echo "garden-$GARDENER_PROJECT--$GARDENER_SHOOT_2-external" >"../../$CONTEXT_2_FILE"
