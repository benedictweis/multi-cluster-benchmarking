#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")" || exit 1

source ../../config.cfg
source ../../helper.sh

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

approachinfo "Unpeering clusters"
liqoctl unpeer --context="$CLUSTER_2_CONTEXT" --remote-context="$CLUSTER_1_CONTEXT"
sleep 1

approachinfo "Uninstalling liqo"
liqoctl uninstall --purge --skip-confirm --context "$CLUSTER_1_CONTEXT"
liqoctl uninstall --purge --skip-confirm --context "$CLUSTER_2_CONTEXT"
