#!/usr/bin/env bash

set -euo pipefail

source ../../config.cfg
source ../../helper.sh

cat "context-2.txt" >"../../$CONTEXT_2_FILE"
rm context-2.txt
