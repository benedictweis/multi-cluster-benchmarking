#!/usr/bin/env bash

set -euo pipefail

source ../../config.cfg
source ../../helper.sh

CLUSTER_1_CONTEXT=$(cat "../../$CONTEXT_1_FILE")
CLUSTER_2_CONTEXT=$(cat "../../$CONTEXT_2_FILE")

approachinfo "Checking Linkerd conditions"
linkerd check --pre --context "$CLUSTER_1_CONTEXT"
linkerd check --pre --context "$CLUSTER_2_CONTEXT"

ROOT_CERT_FILE=$(mktemp)
ROOT_KEY_FILE=$(mktemp)
ISSUER_CERT_FILE=$(mktemp)
ISSUER_KEY_FILE=$(mktemp)

approachinfo "Generating trust anchor"
step certificate create root.linkerd.cluster.local "$ROOT_CERT_FILE" "$ROOT_KEY_FILE" --force --profile root-ca --no-password --insecure
step certificate create identity.linkerd.cluster.local "$ISSUER_CERT_FILE" "$ISSUER_KEY_FILE" --force \
    --profile intermediate-ca --not-after 8760h --no-password --insecure \
    --ca "$ROOT_CERT_FILE" --ca-key "$ROOT_KEY_FILE"

approachinfo "Installing Gateway API CRDs"
kubectl apply --context "$CLUSTER_1_CONTEXT" -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
kubectl apply --context "$CLUSTER_2_CONTEXT" -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml

approachinfo "Installing Linkerd crds"
linkerd install --crds | kubectl apply --context "$CLUSTER_1_CONTEXT" -f -
linkerd install --crds | kubectl apply --context "$CLUSTER_2_CONTEXT" -f -

approachinfo "Installing Linkerd in cluster-2"
# Install in second cluster first because it is configured with the other
linkerd install \
    --identity-trust-anchors-file "$ROOT_CERT_FILE" \
    --identity-issuer-certificate-file "$ISSUER_CERT_FILE" \
    --identity-issuer-key-file "$ISSUER_KEY_FILE" |
    kubectl apply --context "$CLUSTER_2_CONTEXT" -f -
approachinfo "Installing Linkerd in cluster-1"
sleep 5
linkerd upgrade \
    --identity-trust-anchors-file "$ROOT_CERT_FILE" \
    --identity-issuer-certificate-file "$ISSUER_CERT_FILE" \
    --identity-issuer-key-file "$ISSUER_KEY_FILE" |
    kubectl apply --context "$CLUSTER_1_CONTEXT" -f -

approachinfo "Checking Linkerd installation"
linkerd check --context "$CLUSTER_1_CONTEXT"
linkerd check --context "$CLUSTER_2_CONTEXT"

approachinfo "Installing Linkerd multicluster"
linkerd multicluster install -f "$CLUSTER_1_NAME/linkerd.yaml" | kubectl apply --context "$CLUSTER_1_CONTEXT" -f -
linkerd multicluster install -f "$CLUSTER_2_NAME/linkerd.yaml" | kubectl apply --context "$CLUSTER_2_CONTEXT" -f -

kubectl label svc -n linkerd-multicluster linkerd-gateway mirror.linkerd.io/exported=true --context "$CLUSTER_1_CONTEXT" --overwrite
kubectl label svc -n linkerd-multicluster linkerd-gateway mirror.linkerd.io/exported=true --context "$CLUSTER_2_CONTEXT" --overwrite

approachinfo "Checking Linkerd multicluster installation"
linkerd multicluster check --context "$CLUSTER_1_CONTEXT"
linkerd multicluster check --context "$CLUSTER_2_CONTEXT"

approachinfo "Checking clusters"
linkerd --context="$CLUSTER_2_CONTEXT" multicluster check

approachinfo "Linking clusters"
linkerd --context="$CLUSTER_2_CONTEXT" multicluster link-gen --cluster-name cluster-2 |
    kubectl --context="$CLUSTER_1_CONTEXT" apply -f -
linkerd --context="$CLUSTER_1_CONTEXT" multicluster link-gen --cluster-name cluster-1 |
    kubectl --context="$CLUSTER_2_CONTEXT" apply -f -

approachinfo "Waiting for Linkerd gateways to have an external IP or hostname"

wait_for_gateway() {
    local context=$1
    local namespace="linkerd-multicluster"
    local name="linkerd-gateway"
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

wait_for_gateway "$CLUSTER_1_CONTEXT"
wait_for_gateway "$CLUSTER_2_CONTEXT"

sleep 10

approachinfo "Checking multicluster link"
linkerd --context="$CLUSTER_1_CONTEXT" multicluster check
linkerd --context="$CLUSTER_1_CONTEXT" multicluster gateways
linkerd --context="$CLUSTER_2_CONTEXT" multicluster check
linkerd --context="$CLUSTER_2_CONTEXT" multicluster gateways
