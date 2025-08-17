from dataclasses import dataclass
import sys
import json
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from datetime import datetime
import logging
from statsmodels.formula.api import ols

from extract_data import BenchmarkDataPoint, benchmarks, approaches, clusters
import re
import os

PLOT_FONTSIZE = 12

@dataclass
class BenchmarkLineInfo:
    x: list[str]
    y: list[float]
    label: str


markers = {
    "same-cluster": "o",
    "load-balancer": "s",
    "cilium-none": "D",
    "cilium-ipsec": "d",
    "cilium-wireguard": "+",
    "calico": "^",
    "istio": "v",
    "linkerd": "<",
    "nss": "P",
    "kuma": "X",
    "skupper": "H",
    "submariner": "8",
    "liqo": "9",
    "cluster-link": "0",
}

colors = {
    "same-cluster": "#332288",
    "load-balancer": "#117733",
    "cilium-none": "#44AA99",
    "cilium-ipsec": "#88CCEE",
    "cilium-wireguard": "#DDCC77",
    "calico": "#000000",
    "istio": "#CC6677",
    "linkerd": "#AA4499",
    "nss": "#000000",
    "kuma": "#000000",
    "skupper": "#882255",
    "submariner": "#000000",
    "liqo": "#000000",
    "cluster-link": "#000000",
}


def generate_box_plot(plot_info: any, plot_data: list, labels: list, output_file: str):
    plot_data = plot_data[::-1]
    labels = labels[::-1]
    plt.figure(figsize=(10, 5))
    box = plt.boxplot(plot_data, vert=False, patch_artist=True, widths=0.8, showfliers=False)
    for i, label in enumerate(labels):
        color = next((color_val for key, color_val in colors.items() if key in label), '#000000')
        box['boxes'][i].set_facecolor(color)

    if hasattr(plot_info, 'lower_bound') and plot_info['lower_bound'] is not None:
        plt.xlim(left=plot_info['lower_bound'])
    if hasattr(plot_info, 'upper_bound') and plot_info['upper_bound'] is not None:
        plt.xlim(right=plot_info['upper_bound'])

    #plt.title(plot_info['plot_name'], fontsize=10)
    plt.xlabel(f'{plot_info['measurement']} [{plot_info['unit']}] ({plot_info['better']} is better)', fontsize=PLOT_FONTSIZE)
    plt.yticks(range(1, len(labels) + 1), labels, fontsize=PLOT_FONTSIZE)

    plt.gca().xaxis.grid(True, which='major', linestyle='-', linewidth=0.7, color='gray', alpha=0.5)
    plt.gca().set_axisbelow(True)

    if plot_info['lower_bound'] is not None:
        plt.xlim(plot_info['lower_bound'], plot_info['upper_bound'])

    plt.tight_layout(pad=1.0)
    plt.savefig(output_file, dpi=300)
    plt.close()


def generate_bar_chart(plot_info: any, plot_data: list, labels: list, output_file: str):
    plot_data = plot_data[::-1]
    labels = labels[::-1]
    plt.figure(figsize=(10, 5))
    bars = plt.barh(labels, plot_data, height=0.8)
    for i, label in enumerate(labels):
        color = next((color_val for key, color_val in colors.items() if key in label), '#000000')
        bars[i].set_facecolor(color)

    #plt.title(plot_info['plot_name'], fontsize=10)
    plt.xlabel(f'{plot_info['measurement']} [{plot_info['unit']}] ({plot_info['better']} is better)', fontsize=PLOT_FONTSIZE)
    plt.yticks(fontsize=PLOT_FONTSIZE)

    plt.gca().xaxis.grid(True, which='major', linestyle='-', linewidth=0.7, color='gray', alpha=0.5)
    plt.gca().set_axisbelow(True)

    min_val = min(plot_data)
    max_val = max(plot_data)
    if min_val != max_val:
        margin = (max_val - min_val) * 0.1  # 10% margin
        plt.xlim(min_val - margin, max_val + margin)
    else:
        plt.xlim(min_val - 1, max_val + 1)

    plt.tight_layout(pad=1.0)
    plt.savefig(output_file, dpi=300)
    plt.close()


def generate_line_plot(plot_info: any, plot_data: list[BenchmarkLineInfo], output_file: str):
    plt.figure(figsize=(10, 5))
    for line_info in plot_data:
        plt.plot(line_info.x, line_info.y, marker=markers[line_info.label], color=colors[line_info.label], label=line_info.label)

    #plt.title(plot_info['plot_name'], fontsize=10)
    if "payload" in plot_info['plot_name'].lower():
        xlabel = "Payload Size"
    elif "parallel" in plot_info['plot_name'].lower():
        xlabel = "Amount of Parallel Streams"
    plt.xlabel(xlabel, fontsize=PLOT_FONTSIZE)
    plt.ylabel(f'{plot_info['measurement']} [{plot_info['unit']}] ({plot_info['better']} is better)', fontsize=PLOT_FONTSIZE)
    plt.legend(fontsize=PLOT_FONTSIZE, loc='upper left')

    plt.gca().xaxis.grid(True, which='major', linestyle='-', linewidth=0.7, color='gray', alpha=0.5)
    plt.gca().yaxis.grid(True, which='major', linestyle='-', linewidth=0.7, color='gray', alpha=0.5)
    plt.gca().set_axisbelow(True)

    max_y = max(max(line.y) for line in plot_data)
    if plot_info['lower_bound'] is not None and max_y < plot_info['upper_bound']:
        plt.ylim(plot_info['lower_bound'], plot_info['upper_bound'])
    #else:
    #    plt.yscale('log')

    plt.tight_layout(pad=1.0)
    plt.savefig(output_file, dpi=300)
    plt.close()


def generate_statistics(plot_data: list, labels: list, output_file: str):
    stats = []
    for index, data in enumerate(plot_data):
        series = pd.Series(data)
        x = np.arange(len(series))
        y = series.values
        df = pd.DataFrame({'x': x, 'y': y})
        try:
            model = ols('y ~ x', data=df).fit()
            coef = float(model.params['x'])
            std_err = float(model.bse['x'])
            t_value = float(model.tvalues['x'])
            p_value = float(model.pvalues['x'])
            r_squared = float(model.rsquared)
        except Exception:
            coef = std_err = t_value = p_value = r_squared = None
        stat = {
            'name': labels[index],
            'min': float(series.min()),
            'q1': float(series.quantile(0.25)),
            'median': float(series.median()),
            'q3': float(series.quantile(0.75)),
            'max': float(series.max()),
            'mean': float(series.mean()),
            'std': float(series.std()),
            'coef': coef,
            'std_err': std_err,
            't_value': t_value,
            'p_value': p_value,
            'r_squared': r_squared
        }
        stats.append(stat)

    with open(output_file, 'w') as f:
        json.dump(stats, f, indent=2)
    pass

plots = [
    ["benchmark", generate_box_plot],
    ["metrics-cpu", generate_bar_chart],
    ["metrics-memory", generate_bar_chart],
    ["efficiency-cpu", generate_bar_chart],
    ["efficiency-memory", generate_bar_chart],
]

info = {
    "nginx-curl": {
        "plot_name": "Nginx Curl Benchmark",
        "measurement": "Round Trip Time (RTT)",
        "unit": "ms",
        "better": "lower",
        "lower_bound": 0,
        "upper_bound": 3,
    },
    "nginx-wrk": {
        "plot_name": "Nginx Wrk Benchmark",
        "measurement": "Latency",
        "unit": "ms",
        "better": "lower",
        "lower_bound": 0,
        "upper_bound": 50,
    },
    "iperf-tcp": {
        "plot_name": "Iperf TCP Network Throughput Benchmark",
        "measurement": "TCP Throughput",
        "unit": "Gbit/s",
        "better": "higher",
        "lower_bound": 0,
        "upper_bound": 60,
    },
    "iperf-udp": {
        "plot_name": "Iperf UDP Network Throughput Benchmark",
        "measurement": "UDP Throughput",
        "unit": "Gbit/s",
        "better": "higher",
        "lower_bound": 0,
        "upper_bound": 60,
    },
    "metrics-cpu": {
        "plot_name": "CPU Seconds used",
        "measurement": "CPU Seconds",
        "unit": "s",
        "better": "lower",
    },
    "metrics-memory": {
        "plot_name": "Peak Memory used",
        "measurement": "Peak Memory",
        "unit": "MiB",
        "better": "lower",
    },
    "efficiency-cpu": {
        "plot_name": "CPU Efficiency",
        "measurement": "CPU Second",
        "unit": "s",
    },
    "efficiency-memory": {
        "plot_name": "Memory Efficiency",
        "measurement": "MiB of Peak Memory",
        "unit": "MiB",
    },
}


def get_plot_info(benchmark: str, plot_type: str, ) -> any:
    benchmark_info = info[benchmark.removesuffix("-pld").removesuffix("-par")]
    plot_type_info = info.get(plot_type, {})

    if plot_type == "benchmark":
        return benchmark_info
    elif "metrics" in plot_type:
        plot_type_info['plot_name'] = f"{benchmark_info['plot_name']} ({plot_type_info['plot_name']})"
        return plot_type_info
    elif "efficiency" in plot_type:
        return {
            "plot_name": f"{plot_type_info['plot_name']} for {benchmark_info['plot_name']}",
            "measurement": f"{benchmark_info['measurement']} per {plot_type_info['measurement']}",
            "unit": f"{benchmark_info['unit']} / {plot_type_info['unit']}",
            "better": "higher"
        }
    elif plot_type == "comparison":
        if benchmark.endswith("-pld"):
            plot_name = f"Comparison of {benchmark_info['plot_name']} across payload sizes"
        elif benchmark.endswith("-par"):
            plot_name = f"Comparison of {benchmark_info['plot_name']} across amount of parallel streams"
        benchmark_info['plot_name'] = plot_name
        return benchmark_info
    else:
        logger.error(f"Unknown plot type: {plot_type} for benchmark: {benchmark}")
        return {}


def render_plots_without_payload_size(benchmark: str, data_points: list[BenchmarkDataPoint], current_time: str):
    for [plot, function] in plots:
        data_points_for_plot = []
        labels = []
        for approach in approaches:
            if plot == "metrics-cpu":
                for cluster in clusters:
                    possible_data_points = [dp.value for dp in data_points if dp.benchmark_type == benchmark and dp.approach == approach and dp.cluster == cluster and dp.data_type == plot]
                    if possible_data_points is None or len(possible_data_points) < 1:
                        continue
                    labels.append(f"{approach} ({cluster})")
                    data_points_for_plot.append(possible_data_points[1]-possible_data_points[0])
            elif plot == "metrics-memory":
                for cluster in clusters:
                    possible_data_points = [dp.value for dp in data_points if dp.benchmark_type == benchmark and dp.approach == approach and dp.cluster == cluster and dp.data_type == plot]
                    if possible_data_points is None or len(possible_data_points) < 1:
                        continue
                    labels.append(f"{approach} ({cluster})")
                    data_points_for_plot.append(max(possible_data_points))
            elif plot == "efficiency-cpu":
                cpu_metrics = []
                for cluster in clusters:
                    possible_data_points = [dp.value for dp in data_points if dp.benchmark_type == benchmark and dp.approach == approach and dp.cluster == cluster and dp.data_type == "metrics-cpu"]
                    if possible_data_points is None or len(possible_data_points) < 1:
                        continue
                    cpu_metrics.append(possible_data_points[1]-possible_data_points[0])
                possible_data_points = [dp.value for dp in data_points if dp.benchmark_type == benchmark and dp.approach == approach and dp.data_type == "benchmark"]
                if possible_data_points is None or len(possible_data_points) < 1:
                    continue
                cpu_metric = max(cpu_metrics)
                benchmark_metric = np.mean(possible_data_points)
                efficiency = benchmark_metric / cpu_metric if cpu_metric > 0 else 0
                labels.append(f"{approach}")
                data_points_for_plot.append(efficiency)
            elif plot == "efficiency-memory":
                memory_metric = 0
                for cluster in clusters:
                    possible_data_points = [dp.value for dp in data_points if dp.benchmark_type == benchmark and dp.approach == approach and dp.cluster == cluster and dp.data_type == "metrics-memory"]
                    if possible_data_points is None or len(possible_data_points) < 1:
                        continue
                possible_data_points = [dp.value for dp in data_points if dp.benchmark_type == benchmark and dp.approach == approach and dp.data_type == "benchmark"]
                if possible_data_points is None or len(possible_data_points) < 1:
                    continue
                memory_metric = max(possible_data_points)
                benchmark_metric = np.mean(possible_data_points)
                efficiency = benchmark_metric / memory_metric if memory_metric > 0 else 0
                labels.append(f"{approach}")
                data_points_for_plot.append(efficiency)
            else:
                possible_data_points = [dp.value for dp in data_points if dp.benchmark_type == benchmark and dp.approach == approach and dp.data_type == plot]
                if possible_data_points is None or len(possible_data_points) < 1:
                    continue
                labels.append(approach)
                data_points_for_plot.append(possible_data_points)

        if not data_points_for_plot:
            continue

        plot_info = get_plot_info(benchmark, plot)
        logger.info(f"Plotting {benchmark} with {plot} approaches: {labels}")
        function(plot_info, data_points_for_plot, labels, f"results/{current_time}/{benchmark}-{plot}.svg")
        generate_statistics(data_points_for_plot, labels, f"results/{current_time}/{benchmark}-{plot}-stats.json")


def render_plots_with_payload_size(benchmark: str, data_points: list[BenchmarkDataPoint], current_time: str):
    plot_data = []

    def parse_size(size):
        if size is None:
            return -1
        size_str = str(size).strip().upper()
        match = re.match(r"(\d+(?:\.\d+)?)([A-Z]+)?", size_str)
        if not match:
            return -1
        num, unit = match.groups()
        num = float(num)
        unit_multipliers = {
            None: 1,
            "B": 1,
            "KB": 1024,
            "MB": 1024**2,
            "GB": 1024**3,
            "TB": 1024**4,
        }
        multiplier = unit_multipliers.get(unit, 1)
        return num * multiplier

    payload_sizes = sorted(
        set(dp.payload_size for dp in data_points if dp.payload_size if dp.benchmark_type == benchmark  is not None),
        key=parse_size
    )
    payload_sizes = [ps for ps in payload_sizes if str(ps).lower() != "none"]
    for approach in approaches:
        x = []
        y = []
        for payload_size in payload_sizes:
            values = [
                dp.value
                for dp in data_points
                if dp.benchmark_type == benchmark
                and dp.approach == approach
                and dp.data_type == "benchmark"
                and dp.payload_size == payload_size
            ]
            x.append(payload_size)
            y.append(np.mean(values) if values else 0)
        if x and y and any(y):
            plot_data.append(BenchmarkLineInfo(x=x, y=y, label=approach))

    if not plot_data:
        return

    logger.info(f"Plotting {benchmark} with approaches: {[line.label for line in plot_data]} and payload sizes: {payload_sizes}")
    plot_info = get_plot_info(benchmark, "comparison")
    generate_line_plot(plot_info, plot_data, f"results/{current_time}/{benchmark}-comparison.svg")


def get_data_points(input: str) -> list[BenchmarkDataPoint]:
    data_points = []
    for line in input.strip().splitlines():
        if line.strip():
            obj = json.loads(line)
            data_points.append(BenchmarkDataPoint(**obj))
    return data_points


def get_input_data() -> str:
    if len(sys.argv) > 1:
        input_file = sys.argv[1]
        with open(input_file, 'r') as f:
            return f.read()
    elif not sys.stdin.isatty():
        return sys.stdin.read()
    else:
        logger.error("No input file provided and no data in stdin.")
        sys.exit(1)


def main():
    input_data = get_input_data()
    data_points = get_data_points(input_data)
    logger.info(f"Extracted {len(data_points)} data points from input")

    current_time = datetime.now().strftime('%Y%m%d-%H%M%S')
    os.makedirs(f"results/{current_time}", exist_ok=True)

    for benchmark in benchmarks:
        if benchmark.endswith("-pld") or benchmark.endswith("-par"):
            render_plots_with_payload_size(benchmark, data_points, current_time)
        else:
            render_plots_without_payload_size(benchmark, data_points, current_time)


logger = logging.getLogger(__name__)

if __name__ == "__main__":
    logging.basicConfig(format="%(asctime)s %(levelname)s %(message)s", level=logging.INFO)
    main()
