#!/usr/bin/env bash

# Dependency specification

set -o errexit
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

source helper.sh
source config.cfg

function show_help() {
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  clean-results               clean benchmark results, only affects benchmark .log files"
    echo "  clusters-create             create clusters using configured provider"
    echo "  clusters-destroy            destroy clusters using configured provider"
    echo "  benchmarks                  run configured benchmarks with configure approaches on configured provider"
    echo "  plot <benchmark> <dir>      generate plots from benchmark results"
}

### COMMAND FUNCTIONS ###

function clean_results() {
    info "[$BENCHMARKS] Cleaning results"
    rm -rf "$RESULTS_DIR"
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

function benchmark_approach() {
    local approach=$1
    local benchmark=$2

    if [[ "${DRY_RUN-0}" != "1" ]]; then
        CLUSTER_1_CONTEXT=$(cat "$CONTEXT_1_FILE")
        CLUSTER_2_CONTEXT=$(cat "$CONTEXT_2_FILE")
    else
        CLUSTER_1_CONTEXT="context-1"
        CLUSTER_2_CONTEXT="context-2"
    fi

    if [[ -f ./"$APPROACHES_DIR"/"$approach"/"pre-$benchmark".sh ]]; then
        info "[$PROVIDER $approach $benchmark] Executing custom pre script"
        run_if_exists ./"$APPROACHES_DIR"/"$approach"/"pre-$benchmark".sh
    else
        info "[$PROVIDER $approach $benchmark] Creating namespace '$benchmark' in both clusters"
        kubectl create namespace "$benchmark" --context "$CLUSTER_1_CONTEXT" --dry-run=client -o yaml | kubectl apply -f - --context "$CLUSTER_1_CONTEXT"
        kubectl create namespace "$benchmark" --context "$CLUSTER_2_CONTEXT" --dry-run=client -o yaml | kubectl apply -f - --context "$CLUSTER_2_CONTEXT"
    fi

    info "[$PROVIDER $approach $benchmark] Deploying benchmark"
    apply_if_exists "$BENCHMARKS_DIR/$benchmark/server.yaml" "$CLUSTER_1_CONTEXT" strict
    apply_if_exists "$BENCHMARKS_DIR/$benchmark/client.yaml" "$CLUSTER_2_CONTEXT" strict

    info "[$PROVIDER $approach $benchmark] Customizing benchmark"
    apply_if_exists "$APPROACHES_DIR/$approach/$CLUSTER_1_NAME/$benchmark.yaml" "$CLUSTER_1_CONTEXT"
    apply_if_exists "$APPROACHES_DIR/$approach/$CLUSTER_2_NAME/$benchmark.yaml" "$CLUSTER_2_CONTEXT"

    info "[$PROVIDER $approach $benchmark] Executing custom script"
    run_if_exists ./"$APPROACHES_DIR"/"$approach"/"$benchmark".sh

    info "[$PROVIDER $approach $benchmark] Running benchmark"
    LABEL="app=${benchmark}-client"
    DATE=$(date +%Y%m%d%H%M%S)
    mkdir -p ./"$RESULTS_DIR"
    if [[ "${DRY_RUN-0}" != "1" ]]; then
        if [[ "$benchmark" == "none" ]]; then
            info "[$PROVIDER $approach $benchmark] Skipping benchmark execution as 'none' is selected"
            read -p "Press key to continue.. " -n1 -s
            echo
        else
            while true; do
                sleep 1
                kubectl top nodes --context $CLUSTER_1_CONTEXT >>"./$RESULTS_DIR/$PROVIDER-$approach-$benchmark-metrics-$CLUSTER_1_NAME-$DATE".log
                kubectl top nodes --context $CLUSTER_2_CONTEXT >>"./$RESULTS_DIR/$PROVIDER-$approach-$benchmark-metrics-$CLUSTER_2_NAME-$DATE".log
                STATUS=$(kubectl get pod -n $benchmark -l $LABEL --context $CLUSTER_2_CONTEXT -o json | jq -r ".items[0].status.containerStatuses[] | select(.name==\"${benchmark}-client\") | .state.terminated")
                if [[ "$STATUS" != "null" ]]; then
                    echo "$LABEL container has terminated."
                    break
                fi
            done
            for job in $(kubectl get jobs -n $benchmark -l $LABEL -o jsonpath='{.items[*].metadata.name}' --context="$CLUSTER_2_CONTEXT"); do
                kubectl logs job/"$job" -n $benchmark -c "${benchmark}-client" --context="$CLUSTER_2_CONTEXT" >"./$RESULTS_DIR/$PROVIDER-$approach-$job-$DATE".log
            done
        fi
    else
        info "DRY RUN: Would execute benchmark for $benchmark with $approach"
    fi

    if [[ "${WAIT_BEFORE_CLEANUP-0}" == "1" ]]; then
        info "[$PROVIDER $approach $benchmark] Waiting for user input before cleanup"
        read -p "Press key to continue.. " -n1 -s
        echo
    fi

    info "[$PROVIDER $approach $benchmark] Uncustomizing benchmark"
    apply_if_exists "$APPROACHES_DIR/$approach/$CLUSTER_1_NAME/$benchmark.yaml" "$CLUSTER_1_CONTEXT"
    apply_if_exists "$APPROACHES_DIR/$approach/$CLUSTER_2_NAME/$benchmark.yaml" "$CLUSTER_2_CONTEXT"

    info "[$PROVIDER $approach $benchmark] Undeploying benchmark"
    delete_if_exists "$BENCHMARKS_DIR/$benchmark/server.yaml" "$CLUSTER_1_CONTEXT" strict
    delete_if_exists "$BENCHMARKS_DIR/$benchmark/client.yaml" "$CLUSTER_2_CONTEXT" strict

    if [[ -f ./"$APPROACHES_DIR"/"$approach"/"post-$benchmark".sh ]]; then
        info "[$PROVIDER $approach $benchmark] Executing custom post script"
        run_if_exists ./"$APPROACHES_DIR"/"$approach"/"post-$benchmark".sh
    else
        info "[$PROVIDER $approach $benchmark] Deleting namespace '$benchmark' in both clusters"
        kubectl delete namespace "$benchmark" --context "$CLUSTER_1_CONTEXT"
        kubectl delete namespace "$benchmark" --context "$CLUSTER_2_CONTEXT"
    fi
}

function benchmarks() {
    info "[$PROVIDER; $APPROACHES; $BENCHMARKS] Running benchmarks"
    for approach in $APPROACHES; do
        info "[$PROVIDER $approach] Installing approach"
        run_if_exists "./$APPROACHES_DIR/$approach/install.sh"

        for benchmark in $BENCHMARKS; do
            benchmark_approach "$approach" "$benchmark"
        done

        info "[$PROVIDER $approach] Uninstalling approach"
        run_if_exists "./$APPROACHES_DIR/$approach/uninstall.sh"
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
        if [[ "${DRY_RUN-0}" != "1" ]]; then
            (cd "$(dirname "$script_path")" && ./"$(basename $script_path)")
        else
            info "DRY RUN: Would execute '$script_path'"
        fi
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
        if [[ "${DRY_RUN-0}" != "1" ]]; then
            kubectl apply -f "$file_name" --context "$context"
        else
            info "DRY RUN: Would apply file '$file_name' with context '$context'"
        fi
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
        if [[ "${DRY_RUN-0}" != "1" ]]; then
            kubectl delete -f "$file_name" --context "$context" --ignore-not-found
        else
            info "DRY RUN: Would delete file '$file_name' with context '$context'"
        fi
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
