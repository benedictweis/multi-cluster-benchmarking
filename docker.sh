#!/usr/bin/env bash

source config.cfg

if [[ $OSTYPE == darwin* ]]; then
    DOCKER_NETWORK="kind"
else
    DOCKER_NETWORK="host"
fi

ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" || "$ARCH" == "aarch64" ]]; then
    CLI_ARCH="arm64"
else
    CLI_ARCH="amd64"
fi

docker build -t mbench . --build-arg CLI_ARCH=$CLI_ARCH
docker run -it \
    -v /var/run/docker.sock:/var/run/docker.sock \
    --network $DOCKER_NETWORK --name mbench mbench "$@"

DATE=$(date +%Y%m%d%H%M%S)
mkdir -p "./$RESULTS_DIR/$DATE"
docker cp "mbench:/multi-cluster-benchmarking/$RESULTS_DIR/." "./$RESULTS_DIR/$DATE"
docker cp "mbench:/multi-cluster-benchmarking/$CONTEXT_1_FILE" "./$CONTEXT_1_FILE"
docker cp "mbench:/multi-cluster-benchmarking/$CONTEXT_2_FILE" "./$CONTEXT_2_FILE"
docker cp "mbench:/multi-cluster-benchmarking/$KUBECONFIG_FILE" "./$KUBECONFIG_FILE"
if [ -z "$(ls -A "./$RESULTS_DIR/$DATE")" ]; then
    rm -rf "./$RESULTS_DIR/$DATE"
fi
docker rm -f mbench
