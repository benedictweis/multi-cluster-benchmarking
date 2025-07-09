#!/usr/bin/env bash

GREEN="\e[32m"
BLUE="\e[34m"
ENDCOLOR="\e[0m"

function info() {
    echo -e "${BLUE}=> ${1}${ENDCOLOR}"
}

function approachinfo() {
    echo -e "${GREEN}=> ${1}${ENDCOLOR}"
}

if [[ $SET_NETWORK_PREFIX == "auto" ]]; then
    if docker network inspect kind &>/dev/null; then
        NETWORK_PREFIX=$(docker network inspect -f '{{(index .IPAM.Config 0).Gateway}}' kind | cut -d '.' -f 1-3)
        if [ -z "$NETWORK_PREFIX" ]; then
            NETWORK_PREFIX=$(docker network inspect -f '{{(index .IPAM.Config 1).Gateway}}' kind | cut -d '.' -f 1-3)
        fi
        info "Docker network 'kind' exists, using ist network prefix $NETWORK_PREFIX"
    else
        NETWORK_PREFIX="172.17.0"
        info "Docker network 'kind' does not exist, using default network prefix $NETWORK_PREFIX"
    fi
else
    info "Using provided network prefix: $SET_NETWORK_PREFIX"
    NETWORK_PREFIX="$SET_NETWORK_PREFIX"
fi
