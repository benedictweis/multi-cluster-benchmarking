#!/usr/bin/env bash

set -euo pipefail

source ../../helper.sh
source ../../config.cfg

cat "../../$CONTEXT_2_FILE" >"context-2.txt"
cat "../../$CONTEXT_1_FILE" >"../../$CONTEXT_2_FILE"
