from abc import ABC, abstractmethod
from dataclasses import dataclass
import sys
import json
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import os
from datetime import datetime
import logging


@dataclass
class Benchmark:
    name: str
    data: list[float]


@dataclass
class BenchmarkRuns:
    plot_name: str
    measurement: str
    unit: str
    better: str
    benchmarks: list[Benchmark]


class BenchmarkDataParser(ABC):
    @abstractmethod
    def parse(self, benchmark_files: str) -> BenchmarkRuns:
        pass


class NginxCurlBenchmarkParser(BenchmarkDataParser):
    def parse(self, benchmark_files) -> BenchmarkRuns:
        benchmarks = []
        for filename in benchmark_files:
            with open(filename, 'r') as f:
                times_ms = []
                for line in f:
                    if "time_total=" in line:
                        try:
                            time_str = line.split("time_total=")[1].split("s")[0]
                            time_ms = float(time_str) * 1000
                            times_ms.append(time_ms)
                        except Exception:
                            logger.error(f"Error parsing time from line: {line} in file: {filename}")
                            continue
                benchmarks.append(Benchmark(name=os.path.basename(filename), data=times_ms))

        return BenchmarkRuns(
            plot_name='Nginx Curl Benchmark',
            measurement='Round Trip Time (RTT)',
            unit='ms',
            better='lower',
            benchmarks=benchmarks
        )


class NginxWrkBenchmarkParser(BenchmarkDataParser):
    def parse(self, benchmark_files) -> BenchmarkRuns:
        benchmarks = []
        for filename in benchmark_files:
            with open(filename, 'r') as f:
                data = []
                for line in f:
                    if "Latency" in line and "Thread Stats" not in line:
                        try:
                            parts = line.split()
                            # Find the value and unit (e.g., 7.39ms)
                            value_str = parts[1]
                            if value_str.endswith("ms"):
                                data.append(float(value_str.replace("ms", "")))
                            elif value_str.endswith("s"):
                                data.append(float(value_str.replace("s", "")) * 1000)
                        except Exception:
                            logger.error(f"Error parsing latency from line: {line} in file: {filename}")
                benchmarks.append(Benchmark(name=os.path.basename(filename), data=data))

        return BenchmarkRuns(
            plot_name='Nginx wrk Benchmark',
            measurement='Latency',
            unit='ms',
            better='lower',
            benchmarks=benchmarks
        )


class IperfBenchmarkParser(BenchmarkDataParser):
    def parse(self, benchmark_files) -> BenchmarkRuns:
        benchmarks = []
        for filename in benchmark_files:
            with open(filename, 'r') as f:
                try:
                    data = json.load(f)
                    bps_list = [interval['sum']['bits_per_second'] / 1e9 for interval in data.get('intervals', [])]
                    benchmarks.append(Benchmark(name=os.path.basename(filename), data=bps_list))
                except Exception as e:
                    logger.error(f"Error parsing iperf file {filename}: {e}")
                    continue

        return BenchmarkRuns(
            plot_name='Iperf Network Throughput',
            measurement='Throughput',
            unit='Gbit/s',
            better='higher',
            benchmarks=benchmarks
        )


class MemoryBenchmarkParser(BenchmarkDataParser):
    def parse(self, benchmark_files) -> BenchmarkRuns:
        benchmarks = []
        for filename in benchmark_files:
            with open(filename, 'r') as f:
                data = []
                aggregated_memory = 0
                for line in f:
                    if line.startswith("NAME") or not line.strip():
                        data.append(aggregated_memory)
                        aggregated_memory = 0
                        continue    
                    parts = line.split()
                    mem_str = parts[3]
                    mem_val = float(mem_str.replace("Mi", ""))
                    aggregated_memory += mem_val
                logger.info(f"Parsed memory data from {filename}: {max(data)}")
                benchmarks.append(Benchmark(name=os.path.basename(filename), data=[max(data)]))

        return BenchmarkRuns(
            plot_name='Peak Memory Usage During Benchmark',
            measurement='Peak Memory',
            unit='Mi',
            better='lower',
            benchmarks=benchmarks
        )


class CPUBenchmarkParser(BenchmarkDataParser):
    def parse(self, benchmark_files) -> BenchmarkRuns:
        benchmarks = []
        for filename in benchmark_files:
            with open(filename, 'r') as f:
                data = []
                aggregated_cpu = 0
                for line in f:
                    if line.startswith("NAME") or not line.strip():
                        data.append(aggregated_cpu)
                        aggregated_cpu = 0
                        continue
                    parts = line.split()
                    cpu_str = parts[1]
                    cpu_val = float(cpu_str.replace("m", ""))
                    aggregated_cpu += cpu_val
                benchmarks.append(Benchmark(name=os.path.basename(filename), data=[max(data)]))

        return BenchmarkRuns(
            plot_name='CPU Seconds Used During Benchmark',
            measurement='CPU Seconds',
            unit='m',
            better='lower',
            benchmarks=benchmarks
        )


class BenchmarkOutputGenerator(ABC):
    @abstractmethod
    def generate_plot(self, benchmark_runs: BenchmarkRuns, output_file: str):
        pass


class BoxPlotGenerator(BenchmarkOutputGenerator):
    def generate_plot(self, benchmark_runs: BenchmarkRuns, output_file: str):
        plot_data = [benchmark.data for benchmark in benchmark_runs.benchmarks]
        labels = [benchmark.name for benchmark in benchmark_runs.benchmarks]

        plt.figure(figsize=(10, 5))
        box = plt.boxplot(plot_data, vert=False, patch_artist=True, widths=0.8, showfliers=False)
        colors = plt.cm.viridis(np.linspace(0, 1, len(plot_data)))
        for patch, color in zip(box['boxes'], colors):
            patch.set_facecolor(color)

        plt.title(benchmark_runs.plot_name, fontsize=10)
        plt.xlabel(f'{benchmark_runs.measurement} [{benchmark_runs.unit}] ({benchmark_runs.better} is better)', fontsize=8)
        plt.yticks(range(1, len(labels) + 1), labels, fontsize=8)

        plt.gca().xaxis.grid(True, which='major', linestyle='-', linewidth=0.7, color='gray', alpha=0.5)
        plt.gca().set_axisbelow(True)

        plt.tight_layout(pad=1.0)
        plt.savefig(output_file, dpi=300)
        plt.close()


class BarChartGenerator(BenchmarkOutputGenerator):
    def generate_plot(self, benchmark_runs: BenchmarkRuns, output_file: str):
        # Gather the data for all benchmarks
        plot_data = [benchmark.data[0] for benchmark in benchmark_runs.benchmarks]
        labels = [benchmark.name for benchmark in benchmark_runs.benchmarks]

        plt.figure(figsize=(10, 5))
        bars = plt.barh(labels, plot_data, color=plt.cm.viridis(np.linspace(0, 1, len(plot_data))), height=0.8)

        plt.title(benchmark_runs.plot_name, fontsize=10)
        plt.xlabel(f'{benchmark_runs.measurement} (in {benchmark_runs.unit}) ({benchmark_runs.better} is better)', fontsize=8)
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


class StatsGenerator(BenchmarkOutputGenerator):
    def generate_plot(self, benchmark_runs: BenchmarkRuns, output_file: str):
        stats = []
        for benchmark_run in benchmark_runs.benchmarks:
            series = pd.Series(benchmark_run.data)
            stat = {
                'name': benchmark_run.name,
                'min': float(series.min()),
                'q1': float(series.quantile(0.25)),
                'median': float(series.median()),
                'q3': float(series.quantile(0.75)),
                'max': float(series.max()),
                'mean': float(series.mean()),
                'std': float(series.std())
            }
            stats.append(stat)

        with open(output_file, 'w') as f:
            json.dump(stats, f, indent=2)
        pass


def get_parser_generator(benchmark_name: str, metrics_to_get: str) -> tuple[BenchmarkDataParser, BenchmarkOutputGenerator]:
    match metrics_to_get:
        case "bench":
            match benchmark_name:
                case "nginx-curl":
                    return NginxCurlBenchmarkParser(), BoxPlotGenerator()
                case "nginx-wrk":
                    return NginxWrkBenchmarkParser(), BoxPlotGenerator()
                case "iperf":
                    return IperfBenchmarkParser(), BoxPlotGenerator()
                case _:
                    print(f"Unknown benchmark_name, metrics_to_get: {benchmark_name}, {metrics_to_get}")
                    sys.exit(1)
        case "memory":
            return MemoryBenchmarkParser(), BarChartGenerator()
        case "cpu":
            return CPUBenchmarkParser(), BarChartGenerator()
        case _:
            print(f"Unknown benchmark_name, metrics_to_get: {benchmark_name}, {metrics_to_get}")
            sys.exit(1)


def main():
    if len(sys.argv) == 5:
        input_folder = sys.argv[1]
        benchmark_name = sys.argv[2]
        metrics_to_get = sys.argv[3]
        output_folder = sys.argv[4]
    else:
        print("Usage: python box.py <input_folder> <benchmark_name> <metrics_to_get> <output_folder>")
        sys.exit(1)

    benchmark_parser, plot_generator = get_parser_generator(benchmark_name, metrics_to_get)
    logging.info(f"Using parser {benchmark_parser.__class__.__name__} and plot generator {plot_generator.__class__.__name__}")
    benchmark_files = []
    for fname in os.listdir(input_folder):
        if metrics_to_get == "bench":
            if f"{benchmark_name}-client" in fname:
                benchmark_files.append(os.path.join(input_folder, fname))
        elif metrics_to_get == "memory" or metrics_to_get == "cpu":
            if f"{benchmark_name}-metrics" in fname:
                benchmark_files.append(os.path.join(input_folder, fname))
    logging.info(f"Found benchmark files: {benchmark_files}")
    logging.info(f"Parsing benchmark files with {benchmark_parser.__class__.__name__}")
    benchmark_runs = benchmark_parser.parse(benchmark_files)
    logging.info(f"Parsed {len(benchmark_runs.benchmarks)} benchmarks for {benchmark_runs.plot_name}")

    if metrics_to_get == "bench":
        for benchmark in benchmark_runs.benchmarks:
            for entry in order:
                if entry in benchmark.name:
                    benchmark.name = entry
                    break

        def sort_key(benchmark):
            for idx, entry in enumerate(order):
                if benchmark.name == entry:
                    return idx
            return len(order)

        benchmark_runs.benchmarks.sort(key=sort_key)
        benchmark_runs.benchmarks.reverse()
    else:
        benchmark_runs.benchmarks.sort(key=lambda x: x.name)

    current_time = datetime.now().strftime("%Y%m%d%H%M%S")

    logging.info(f"Generating plot for {benchmark_runs.plot_name}")
    output_file = os.path.join(output_folder, f'{benchmark_name}-{metrics_to_get}-{current_time}.png')
    plot_generator.generate_plot(benchmark_runs, output_file)
    logging.info(f"Plot saved to {output_file}")

    logging.info(f"Generating stats for {benchmark_runs.plot_name}")
    stats_generator = StatsGenerator()
    stats_output_file = os.path.join(output_folder, f'{benchmark_name}-{metrics_to_get}-{current_time}.json')
    stats_generator.generate_plot(benchmark_runs, stats_output_file)
    logging.info(f"Stats saved to {stats_output_file}")



logger = logging.getLogger(__name__)

order = [
    "same-cluster",
    "load-balancer",
    "cilium",
    "calico",
    "istio",
    "linkerd",
    "nss",
    "kuma",
    "skupper",
    "submariner",
    "liqo",
    "cluster-link",
]

if __name__ == "__main__":
    logging.basicConfig(format="%(asctime)s %(levelname)s %(message)s", level=logging.INFO)
    logger.info("Starting benchmark plotting script")
    main()
