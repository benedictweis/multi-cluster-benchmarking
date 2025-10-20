#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")" || exit 1

source ../../config.cfg
source ../../helper.sh

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

approachinfo "Uninstalling skupper in both clusters"
kubectl delete -f https://skupper.io/install.yaml --wait --context ${CLUSTER_1_CONTEXT}
kubectl delete -f https://skupper.io/install.yaml --wait --context ${CLUSTER_2_CONTEXT}
