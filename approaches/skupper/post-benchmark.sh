#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")" || exit 1

source ../../config.cfg
source ../../helper.sh

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

approachinfo "Setting namespaces for both clusters"
kubectl config set-context --namespace=${BENCHMARK} ${CLUSTER_1_CONTEXT}
kubectl config set-context --namespace=${BENCHMARK} ${CLUSTER_2_CONTEXT}

approachinfo "Creating skupper sites in both clusters"
skupper site create ${CLUSTER_1_NAME} --enable-link-access --context ${CLUSTER_1_CONTEXT}
skupper site create ${CLUSTER_2_NAME} --context ${CLUSTER_2_CONTEXT}

approachinfo "Linking both clusters"
SKUPPER_TOKEN_FILE="$(mktemp)"
skupper token issue ${SKUPPER_TOKEN_FILE} --context ${CLUSTER_1_CONTEXT}
skupper token redeem ${SKUPPER_TOKEN_FILE} --context ${CLUSTER_2_CONTEXT}
skupper link status --context ${CLUSTER_1_CONTEXT}
skupper link status --context ${CLUSTER_2_CONTEXT}
rm -f ${SKUPPER_TOKEN_FILE}

approachinfo "Exposing benchmark server"
skupper connector create ${BENCHMARK}-server ${PORT} --context ${CLUSTER_1_CONTEXT}
skupper listener create ${BENCHMARK}-server ${PORT} --context ${CLUSTER_2_CONTEXT}

approachinfo "Unsetting namespaces for both clusters"
kubectl config set-context --namespace=default ${CLUSTER_1_CONTEXT}
kubectl config set-context --namespace=default ${CLUSTER_2_CONTEXT}

export SERVER_ADDRESS="$BENCHMARK-server"
