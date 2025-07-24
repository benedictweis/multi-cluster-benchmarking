#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")" || exit 1

source ../../config.cfg
source ../../helper.sh

approachinfo "Adjusting context files for clusters"
cat "../../$CONTEXT_2_FILE" >"context-2.txt"
cat "../../$CONTEXT_1_FILE" >"../../$CONTEXT_2_FILE"
