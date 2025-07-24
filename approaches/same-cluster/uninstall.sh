#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")" || exit 1

source ../../config.cfg
source ../../helper.sh

approachinfo "Adjusting context files for clusters"
cat "context-2.txt" >"../../$CONTEXT_2_FILE"
rm context-2.txt
