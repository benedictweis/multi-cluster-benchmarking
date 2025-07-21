import sys
import json
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from datetime import datetime
import logging
from statsmodels.formula.api import ols

from extract_data import BenchmarkDataPoint, benchmarks, approaches, clusters


def generate_box_plot(plot_name: str, measurement: str, unit: str, better: str, plot_data: list, labels: list, output_file: str):
    plot_data = plot_data[::-1]
    labels = labels[::-1]
    plt.figure(figsize=(10, 5))
    box = plt.boxplot(plot_data, vert=False, patch_artist=True, widths=0.8, showfliers=False)
    colors = plt.cm.viridis(np.linspace(0, 1, len(plot_data)))
    for patch, color in zip(box['boxes'], colors):
        patch.set_facecolor(color)

    plt.title(plot_name, fontsize=10)
    plt.xlabel(f'{measurement} [{unit}] ({better} is better)', fontsize=8)
    plt.yticks(range(1, len(labels) + 1), labels, fontsize=8)

    plt.gca().xaxis.grid(True, which='major', linestyle='-', linewidth=0.7, color='gray', alpha=0.5)
    plt.gca().set_axisbelow(True)

    plt.tight_layout(pad=1.0)
    plt.savefig(output_file, dpi=300)
    plt.close()


def generate_bar_chart(plot_name: str, measurement: str, unit: str, better: str, plot_data: list, labels: list, output_file: str):
    plot_data = plot_data[::-1]
    labels = labels[::-1]
    plt.figure(figsize=(10, 5))
    bars = plt.barh(labels, plot_data, color=plt.cm.viridis(np.linspace(0, 1, len(plot_data))), height=0.8)

    plt.title(plot_name, fontsize=10)
    plt.xlabel(f'{measurement} [{unit}] ({better} is better)', fontsize=8)
    plt.yticks(fontsize=8)

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
    },
    "nginx-wrk": {
        "plot_name": "Nginx Wrk Benchmark",
        "measurement": "Latency",
        "unit": "ms",
        "better": "lower",
    },
    "iperf-tcp": {
        "plot_name": "Iperf TCP Network Throughput Benchmark",
        "measurement": "TCP Throughput",
        "unit": "Gbit/s",
        "better": "higher",
    },
    "iperf-udp": {
        "plot_name": "Iperf UDP Network Throughput Benchmark",
        "measurement": "UDP Throughput",
        "unit": "Gbit/s",
        "better": "higher",
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


def get_plot_info(benchmark: str, plot_type: str, ) -> tuple[str, str, str, str]:
    benchmark_info = info[benchmark]
    plot_type_info = info.get(plot_type, {})

    plot_name, measurement, unit, better = "", "", "", ""

    if plot_type == "benchmark":
        plot_name = benchmark_info["plot_name"]
        measurement = benchmark_info["measurement"]
        unit = benchmark_info["unit"]
        better = benchmark_info["better"]
    elif "metrics" in plot_type:
        plot_name = f"{plot_type_info["plot_name"]} for {benchmark_info["plot_name"]}"
        measurement = plot_type_info["measurement"]
        unit = plot_type_info["unit"]
        better = plot_type_info["better"]
    elif "efficiency" in plot_type:
        plot_name = f"{plot_type_info["plot_name"]} for {benchmark_info["plot_name"]}"
        measurement = f"{benchmark_info["measurement"]} per {plot_type_info["measurement"]}"
        unit = f"{benchmark_info["unit"]} / {plot_type_info["unit"]}"
        better = "higher"

    return plot_name, measurement, unit, better


def main():
    if len(sys.argv) > 1:
        input_file = sys.argv[1]
        with open(input_file, 'r') as f:
            input_data = f.read()
    else:
        if not sys.stdin.isatty():
            input_data = sys.stdin.read()
        else:
            logger.error("No input file provided and no data in stdin.")
            sys.exit(1)

    data_points = []
    for line in input_data.strip().splitlines():
        if line.strip():
            obj = json.loads(line)
            data_points.append(BenchmarkDataPoint(**obj))

    logger.info(f"Extracted {len(data_points)} data points from input")

    current_time = datetime.now().strftime('%Y%m%d-%H%M%S')

    for benchmark in benchmarks:
        for [plot, function] in plots:
            data_points_for_plot = []
            labels = []
            for approach in approaches:
                if plot == "metrics-cpu":
                    for cluster in clusters:
                        possible_data_points = [dp.value for dp in data_points if dp.benchmark_type == benchmark and dp.approach == approach and dp.cluster == cluster and dp.data_type == plot]
                        if possible_data_points is None or len(possible_data_points) < 1:
                            logger.info(f"No data points found for benchmark {benchmark}, plot type {plot}, approach {approach}, cluster {cluster}")
                            continue
                        labels.append(f"{approach} ({cluster})")
                        data_points_for_plot.append(possible_data_points[1]-possible_data_points[0])
                elif plot == "metrics-memory":
                    for cluster in clusters:
                        possible_data_points = [dp.value for dp in data_points if dp.benchmark_type == benchmark and dp.approach == approach and dp.cluster == cluster and dp.data_type == plot]
                        if possible_data_points is None or len(possible_data_points) < 1:
                            logger.info(f"No data points found for benchmark {benchmark}, plot type {plot}, approach {approach}, cluster {cluster}")
                            continue
                        labels.append(f"{approach} ({cluster})")
                        data_points_for_plot.append(max(possible_data_points))
                elif plot == "efficiency-cpu":
                    cpu_metrics = []
                    for cluster in clusters:
                        possible_data_points = [dp.value for dp in data_points if dp.benchmark_type == benchmark and dp.approach == approach and dp.cluster == cluster and dp.data_type == "metrics-cpu"]
                        if possible_data_points is None or len(possible_data_points) < 1:
                            logger.info(f"No data points found for benchmark {benchmark}, plot type {plot}, approach {approach}, cluster {cluster}")
                            continue
                        cpu_metrics.append(possible_data_points[1]-possible_data_points[0])
                    possible_data_points = [dp.value for dp in data_points if dp.benchmark_type == benchmark and dp.approach == approach and dp.data_type == "benchmark"]
                    if possible_data_points is None or len(possible_data_points) < 1:
                        logger.info(f"No data points found for benchmark {benchmark}, plot type {plot}, approach {approach}")
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
                            logger.info(f"No data points found for benchmark {benchmark}, plot type {plot}, approach {approach}, cluster {cluster}")
                            continue
                    possible_data_points = [dp.value for dp in data_points if dp.benchmark_type == benchmark and dp.approach == approach and dp.data_type == "benchmark"]
                    if possible_data_points is None or len(possible_data_points) < 1:
                        logger.info(f"No data points found for benchmark {benchmark}, plot type {plot}, approach {approach}")
                        continue
                    memory_metric = max(possible_data_points)
                    benchmark_metric = np.mean(possible_data_points)
                    efficiency = benchmark_metric / memory_metric if memory_metric > 0 else 0
                    labels.append(f"{approach}")
                    data_points_for_plot.append(efficiency)
                else:
                    possible_data_points = [dp.value for dp in data_points if dp.benchmark_type == benchmark and dp.approach == approach and dp.data_type == plot]
                    if possible_data_points is None or len(possible_data_points) < 1:
                        logger.info(f"No data points found for benchmark {benchmark}, plot type {plot}, approach {approach}")
                        continue
                    labels.append(approach)
                    data_points_for_plot.append(possible_data_points)

            plot_name, measurement, unit, better = get_plot_info(benchmark, plot)

            function(plot_name, measurement, unit, better, data_points_for_plot, labels, f"results/{benchmark}-{plot}-{current_time}.png")
            generate_statistics(data_points_for_plot, labels, f"results/{benchmark}-{plot}-{current_time}-stats.json")

logger = logging.getLogger(__name__)

if __name__ == "__main__":
    logging.basicConfig(format="%(asctime)s %(levelname)s %(message)s", level=logging.INFO)
    main()
