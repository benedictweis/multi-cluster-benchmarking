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
