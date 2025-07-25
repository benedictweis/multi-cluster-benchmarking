#!/usr/bin/env bash

GREEN="\e[32m"
BLUE="\e[34m"
ENDCOLOR="\e[0m"

function info() {
    echo -e "${BLUE}$(date '+%Y-%m-%d %H:%M:%S') ${1}${ENDCOLOR}"
}

function approachinfo() {
    echo -e "${GREEN}$(date '+%Y-%m-%d %H:%M:%S') ${1}${ENDCOLOR}"
}

wait_for_gateway() {
    local namespace=$1
    local name=$2
    local context=$3
    local timeout=100
    local interval=1
    local elapsed=0

    while true; do
        external_ip=$(kubectl --context="$context" -n "$namespace" get svc "$name" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        hostname=$(kubectl --context="$context" -n "$namespace" get svc "$name" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        if [[ -n "$external_ip" || -n "$hostname" ]]; then
            approachinfo "Gateway in context $context is ready: ${external_ip:-$hostname}"
            break
        fi
        if ((elapsed >= timeout)); then
            echo "Timeout waiting for external IP/hostname for gateway in context $context"
            exit 1
        fi
        sleep "$interval"
        ((elapsed += interval))
    done
}

if [[ $SET_NETWORK_PREFIX == "auto" ]]; then
    if docker network inspect kind &>/dev/null; then
        NETWORK_PREFIX_1=$(docker network inspect -f '{{(index .IPAM.Config 0).Gateway}}' kind)
        NETWORK_PREFIX_2=$(docker network inspect -f '{{(index .IPAM.Config 1).Gateway}}' kind)

        if [[ "$NETWORK_PREFIX_1" == *:* ]]; then
            NETWORK_PREFIX_1="$(echo "$NETWORK_PREFIX_1" | rev | cut -d ':' -f 2- | rev):"
        else
            NETWORK_PREFIX_1="$(echo "$NETWORK_PREFIX_1" | cut -d '.' -f 1-3)."
        fi

        if [[ "$NETWORK_PREFIX_2" == *:* ]]; then
            NETWORK_PREFIX_2="$(echo "$NETWORK_PREFIX_2" | rev | cut -d ':' -f 2- | rev):"
        else
            NETWORK_PREFIX_2="$(echo "$NETWORK_PREFIX_2" | cut -d '.' -f 1-3)."
        fi
        if [[ "$PROVIDER" == *"ipv6"* ]]; then
            if [[ "$NETWORK_PREFIX_1" == *:* ]]; then
                NETWORK_PREFIX="$NETWORK_PREFIX_1"
            else
                NETWORK_PREFIX="$NETWORK_PREFIX_2"
            fi
        else
            if [[ "$NETWORK_PREFIX_1" == *.* ]]; then
                NETWORK_PREFIX="$NETWORK_PREFIX_1"
            else
                NETWORK_PREFIX="$NETWORK_PREFIX_2"
            fi
        fi
        info "Docker network 'kind' exists, using its network prefix $NETWORK_PREFIX"
    else
        NETWORK_PREFIX="172.17.0."
        info "Docker network 'kind' does not exist, using default network prefix $NETWORK_PREFIX"
    fi
else
    info "Using provided network prefix: $SET_NETWORK_PREFIX"
    NETWORK_PREFIX="$SET_NETWORK_PREFIX"
fi
