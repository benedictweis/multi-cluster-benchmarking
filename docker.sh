#!/usr/bin/env bash

source config.cfg

docker build -t mbench .
docker run -it \
    -v /var/run/docker.sock:/var/run/docker.sock \
    --network kind --name mbench mbench "$@"
DATE=$(date +%Y%m%d%H%M%S)
mkdir -p "./$RESULTS_DIR/$DATE"
docker cp "mbench:/multi-cluster-benchmarking/$RESULTS_DIR/." "./$RESULTS_DIR/$DATE"
docker cp "mbench:/multi-cluster-benchmarking/$KUBECONFIG_FILE" "./$KUBECONFIG_FILE"
if [ -z "$(ls -A "./$RESULTS_DIR/$DATE")" ]; then
    rm -rf "./$RESULTS_DIR/$DATE"
fi
docker rm -f mbench
