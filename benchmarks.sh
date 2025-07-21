#!/usr/bin/env bash

# Dependency specification

set -o errexit
set -o nounset
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

source config.cfg
source helper.sh

set -o pipefail

export BENCHMARKS_N
export BENCHMARKS_N_DIV_10=$((BENCHMARKS_N / 10))
# This is for envsubst to substitute dollars to $
export DOLLAR='$'

function show_help() {
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  clean-results        clean benchmark results, only affects benchmark .log files"
    echo "  clusters-create      create clusters using configured provider"
    echo "  clusters-destroy     destroy clusters using configured provider"
    echo "  benchmarks           run configured benchmarks with configure approaches on configured provider"
    echo "  plot <dir>           generate plots from benchmark results"
}

### COMMAND FUNCTIONS ###

function clean_results() {
    info "[$BENCHMARKS] Cleaning results"
    rm -rf "$RESULTS_DIR"
    rm -rf plotting/"$RESULTS_DIR"
}

function clusters_create() {
    info "[$PROVIDER] Creating clusters"
    run_if_exists "./$PROVIDERS_DIR/$PROVIDER/create.sh" strict
}

function clusters_destroy() {
    info "[$PROVIDER] Destroying clusters"
    run_if_exists "./$PROVIDERS_DIR/$PROVIDER/destroy.sh" strict
    rm -rf "$CONTEXT_1_FILE" "$CONTEXT_2_FILE" "$KUBECONFIG_FILE"
}

function calculate_ports() {
    export PORT=80
    if [[ "$1" == iperf* ]]; then
        export PORT=5201
    elif [[ "$1" == *grpc* ]]; then
        export PORT=9000
    fi
    export PORTS=$(
        cat <<EOF
      - protocol: TCP
        port: $PORT
        targetPort: $PORT
EOF
    )
    if [[ "$1" == iperf-udp ]]; then
        export PORTS=$(
            cat <<EOF
      - name: iperf-tcp
        protocol: TCP
        port: $PORT
        targetPort: $PORT
      - name: iperf-udp
        protocol: UDP
        port: $PORT
        targetPort: $PORT
EOF
        )
    fi
}

function benchmark_approach() {
    local approach=$1
    local benchmark=$2

    CLUSTER_1_CONTEXT=$(cat $CONTEXT_1_FILE)
    CLUSTER_2_CONTEXT=$(cat $CONTEXT_2_FILE)

    calculate_ports $benchmark

    info "[$PROVIDER $approach $benchmark] Creating namespace '$benchmark' in both clusters"
    kubectl create namespace "$benchmark" --context "$CLUSTER_1_CONTEXT" --dry-run=client -o yaml | kubectl apply -f - --context "$CLUSTER_1_CONTEXT"
    kubectl create namespace "$benchmark" --context "$CLUSTER_2_CONTEXT" --dry-run=client -o yaml | kubectl apply -f - --context "$CLUSTER_2_CONTEXT"

    info "[$PROVIDER $approach $benchmark] Executing benchmark script"
    export BENCHMARK="$benchmark"
    run_if_exists "$APPROACHES_DIR"/"$approach"/"$BENCHMARK_CUSTOM_FILE"

    info "[$PROVIDER $approach $benchmark] Deploying benchmark server"
    apply_if_exists "$BENCHMARKS_DIR/$benchmark/server.yaml" "$CLUSTER_1_CONTEXT" strict

    CLIENT_LABEL="app=${benchmark}-client"
    SERVER_LABEL="app=${benchmark}-server"

    CLUSTER_1_CONTROL_PLANE_NAME=$(kubectl get nodes --context "$CLUSTER_1_CONTEXT" --selector='node-role.kubernetes.io/control-plane' --no-headers -o custom-columns=NAME:.metadata.name)
    CLUSTER_2_CONTROL_PLANE_NAME=$(kubectl get nodes --context "$CLUSTER_2_CONTEXT" --selector='node-role.kubernetes.io/control-plane' --no-headers -o custom-columns=NAME:.metadata.name)

    DATE=$(date +%Y%m%d%H%M%S)
    mkdir -p ./"$RESULTS_DIR"

    info "[$PROVIDER $approach $benchmark] Waiting for server pod to be scheduled in cluster 1"
    until kubectl get pod -n "$benchmark" -l "$SERVER_LABEL" --context "$CLUSTER_1_CONTEXT" | grep "${benchmark}-server" >/dev/null 2>&1; do
        sleep 1
    done
    info "[$PROVIDER $approach $benchmark] Waiting for server pod to be ready in cluster 1"
    kubectl wait --for=condition=Ready pod -n "$benchmark" -l "$SERVER_LABEL" --context "$CLUSTER_1_CONTEXT" --timeout=30s
    info "[$PROVIDER $approach $benchmark] Executing benchmark post script"
    export BENCHMARK="$benchmark"
    run_if_exists "$APPROACHES_DIR"/"$approach"/"post-$BENCHMARK_CUSTOM_FILE"
    info "[$PROVIDER $approach $benchmark] Deploying benchmark client"
    apply_if_exists "$BENCHMARKS_DIR/$benchmark/client.yaml" "$CLUSTER_2_CONTEXT" strict BENCHMARKS_N="$BENCHMARKS_N" BENCHMARKS_N_DIV_10="$BENCHMARKS_N_DIV_10"
    info "[$PROVIDER $approach $benchmark] Waiting for client pod to be scheduled in cluster 2"
    until kubectl get pod -n "$benchmark" -l "$CLIENT_LABEL" --context "$CLUSTER_2_CONTEXT" | grep "${benchmark}-client" >/dev/null 2>&1; do
        sleep 1
    done
    info "[$PROVIDER $approach $benchmark] Waiting for client pod to be ready in cluster 2"
    kubectl wait --for=condition=Ready pod -n "$benchmark" -l "$CLIENT_LABEL" --context "$CLUSTER_2_CONTEXT" --timeout=30s
    info "[$PROVIDER $approach $benchmark] Running benchmark"
    kubectl get --context "$CLUSTER_1_CONTEXT" --raw "/api/v1/nodes/$CLUSTER_1_CONTROL_PLANE_NAME/proxy/metrics/cadvisor" | grep '^container_cpu_usage_seconds_total{container="",cpu="total",id="/"' >>"./$RESULTS_DIR/$PROVIDER-$approach-$benchmark-metrics-cpu-$CLUSTER_1_NAME-$DATE".log
    kubectl get --context "$CLUSTER_2_CONTEXT" --raw "/api/v1/nodes/$CLUSTER_2_CONTROL_PLANE_NAME/proxy/metrics/cadvisor" | grep '^container_cpu_usage_seconds_total{container="",cpu="total",id="/"' >>"./$RESULTS_DIR/$PROVIDER-$approach-$benchmark-metrics-cpu-$CLUSTER_2_NAME-$DATE".log
    while true; do
        sleep 1
        kubectl get --context "$CLUSTER_1_CONTEXT" --raw "/api/v1/nodes/$CLUSTER_1_CONTROL_PLANE_NAME/proxy/metrics/cadvisor" | grep '^container_memory_working_set_bytes{container="",id="/"' >> "./$RESULTS_DIR/$PROVIDER-$approach-$benchmark-metrics-memory-$CLUSTER_1_NAME-$DATE".log
        kubectl get --context "$CLUSTER_2_CONTEXT" --raw "/api/v1/nodes/$CLUSTER_2_CONTROL_PLANE_NAME/proxy/metrics/cadvisor" | grep '^container_memory_working_set_bytes{container="",id="/"' >> "./$RESULTS_DIR/$PROVIDER-$approach-$benchmark-metrics-memory-$CLUSTER_2_NAME-$DATE".log
        STATUS=$(kubectl get pod -n $benchmark -l $CLIENT_LABEL --context $CLUSTER_2_CONTEXT -o json | jq -r ".items[0].status.containerStatuses[] | select(.name==\"${benchmark}-client\") | .state.terminated")
        if [[ "$STATUS" != "null" ]]; then
            echo "$CLIENT_LABEL container has terminated."
            break
        fi
    done
    for job in $(kubectl get jobs -n $benchmark -l $CLIENT_LABEL -o jsonpath='{.items[*].metadata.name}' --context="$CLUSTER_2_CONTEXT"); do
        kubectl logs job/"$job" -n $benchmark -c "${benchmark}-client" --context="$CLUSTER_2_CONTEXT" >"./$RESULTS_DIR/$PROVIDER-$approach-$job-$DATE".log
    done
    kubectl get --context "$CLUSTER_1_CONTEXT" --raw "/api/v1/nodes/$CLUSTER_1_CONTROL_PLANE_NAME/proxy/metrics/cadvisor" | grep '^container_cpu_usage_seconds_total{container="",cpu="total",id="/"' >>"./$RESULTS_DIR/$PROVIDER-$approach-$benchmark-metrics-cpu-$CLUSTER_1_NAME-$DATE".log
    kubectl get --context "$CLUSTER_2_CONTEXT" --raw "/api/v1/nodes/$CLUSTER_2_CONTROL_PLANE_NAME/proxy/metrics/cadvisor" | grep '^container_cpu_usage_seconds_total{container="",cpu="total",id="/"' >>"./$RESULTS_DIR/$PROVIDER-$approach-$benchmark-metrics-cpu-$CLUSTER_2_NAME-$DATE".log

    if [[ "${WAIT_BEFORE_CLEANUP-0}" == "1" ]]; then
        info "[$PROVIDER $approach $benchmark] Waiting for user input before cleanup"
        read -p "Press key to continue.. " -n1 -s
        echo
    fi

    info "[$PROVIDER $approach $benchmark] Deleting namespace '$benchmark' in both clusters"
    kubectl delete namespace "$benchmark" --context "$CLUSTER_1_CONTEXT" --ignore-not-found --wait
    kubectl delete namespace "$benchmark" --context "$CLUSTER_2_CONTEXT" --ignore-not-found --wait
}

function benchmarks() {
    info "[$PROVIDER; $APPROACHES; $BENCHMARKS] Running benchmarks"
    for approach in $APPROACHES; do
        info "[$PROVIDER $approach] Installing approach"
        run_if_exists "$APPROACHES_DIR/$approach/install.sh"

        if [[ "$BENCHMARKS" == "none" ]]; then
            info "[$PROVIDER $approach $BENCHMARKS] Skipping benchmark execution as 'none' is selected"
            read -p "Press key to continue.. " -n1 -s
            echo
        else
            for benchmark in $BENCHMARKS; do
                benchmark_approach "$approach" "$benchmark"
            done
        fi

        info "[$PROVIDER $approach] Uninstalling approach"
        run_if_exists "$APPROACHES_DIR/$approach/uninstall.sh"
    done
}

function plot() {
    local input_folder="$1"
    info "[$BENCHMARKS] Preparing plot"
    source ./plotting/.venv/bin/activate
    for benchmark in $BENCHMARKS; do
        for metric in "bench" "memory" "cpu"; do
            info "[$benchmark $metric] Plotting results"
            mkdir -p plotting/results
            (cd ./plotting && python3 plots.py "../$input_folder" "$benchmark" "$metric" "$RESULTS_DIR")
        done
    done
}

### UTILITY FUNCTIONS ###

function run_if_exists() {
    local script_path="$1"
    local mode="${2-}"
    if [[ -f "$script_path" ]]; then
        pushd "$(dirname "$script_path")" >/dev/null
        source "$(basename "$script_path")"
        popd >/dev/null
    else
        if [[ "$mode" == "strict" ]]; then
            info "Warning: File '$script_path' does not exist"
        fi
    fi
}

function apply_if_exists() {
    local file_name="$1"
    local context="${2}"
    local mode="${3-}"
    if [[ -f "$file_name" ]]; then
        envsubst <"$file_name" | kubectl apply -f - --context "$context"
    else
        if [[ "$mode" == "strict" ]]; then
            info "Warning: File '$file_name' does not exist"
        fi
    fi
}

function delete_if_exists() {
    local file_name="$1"
    local context="${2}"
    local mode="${3-}"
    if [[ -f "$file_name" ]]; then
        envsubst <"$file_name" | kubectl delete -f - --context "$context" --ignore-not-found
    else
        if [[ "$mode" == "strict" ]]; then
            info "Warning: File '$file_name' does not exist"
        fi
    fi
}

### MAIN FUNCTION ###

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi
    case "$1" in
    clean-results)
        shift
        clean_results
        ;;
    clusters-create)
        shift
        clusters_create
        ;;
    clusters-destroy)
        shift
        clusters_destroy
        ;;
    benchmarks)
        shift
        benchmarks
        ;;
    plot)
        shift
        plot "$@"
        ;;
    help | "")
        show_help
        ;;
    *)
        echo "Error: Unknown command '$1'"
        show_help
        exit 1
        ;;
    esac
fi
