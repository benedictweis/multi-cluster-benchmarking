#!/usr/bin/env bash

set -euo pipefail

source ../../helper.sh
source ../../config.cfg

cat "context-2.txt" >"../../$CONTEXT_2_FILE"
rm context-2.txt
