#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")" || exit 1

source ../../config.cfg
source ../../helper.sh

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

approachinfo "Uninstalling submariner"
subctl uninstall --yes --context "$CLUSTER_1_CONTEXT"
subctl uninstall --yes --context "$CLUSTER_2_CONTEXT"
