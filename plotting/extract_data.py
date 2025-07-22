from dataclasses import dataclass
import sys
import os
import logging
from typing import Callable
import json
import re


logger = logging.getLogger(__name__)


@dataclass
class BenchmarkDataPoint:
    provider: str
    approach: str
    cluster: str
    benchmark_type: str
    data_type: str
    payload_size: str
    number: int
    value: float


def parse_nginx_curl_benchmark(input: str) -> list[float]:
    values = []
    for line in input.splitlines():
        if "time_total=" in line:
            time_str = line.split("time_total=")[1].split("s")[0]
            values.append(float(time_str) * 1000)
    return values


def parse_nginx_wrk_benchmark(input: str) -> list[float]:
    values = []
    for line in input.splitlines():
        if "Latency" in line and "Thread Stats" not in line:
            parts = line.split()
            # Find the value and unit (e.g., 7.39ms)
            value_str = parts[1]
            if value_str.endswith("ms"):
                values.append(float(value_str.replace("ms", "")))
            elif value_str.endswith("s"):
                values.append(float(value_str.replace("s", "")) * 1000)
    return values


def parse_iperf_benchmark(input: str) -> list[float]:
    data = json.loads(input)
    values = [interval['sum']['bits_per_second'] / 1e9 for interval in data.get('intervals', [])]
    return values


def parse_cpu_benchmark(input: str) -> list[float]:
    values = []
    for line in input.splitlines():
        line = line.strip()
        if not line or line.startswith("container_cpu_usage_seconds_total"):
            parts = line.split()
            if len(parts) >= 2:
                values.append(float(parts[-2]))
    return values


def parse_memory_benchmark(input: str) -> list[float]:
    values = []
    for line in input.splitlines():
        line = line.strip()
        if not line or line.startswith("container_memory_working_set_bytes"):
            parts = line.split()
            if len(parts) >= 2:
                mem_bytes = float(parts[-2])
                mem_mib = mem_bytes / (1024 * 1024)
                values.append(mem_mib)
    return values


providers = ["kind", "k3s"]

approaches = [
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

clusters = ["cluster-1", "cluster-2", "client"]

benchmarks = [
    "nginx-curl-pld",
    "nginx-curl",
    "nginx-wrk-pld",
    "nginx-wrk",
    "iperf-tcp-pld",
    "iperf-tcp",
    "iperf-udp",
]

data_types = [
    "client",
    "metrics-cpu",
    "metrics-memory",
]

benchmark_type_parser_map: dict[str, Callable[[str], list[float]]] = {
    "nginx-curl-pld": parse_nginx_curl_benchmark,
    "nginx-curl": parse_nginx_curl_benchmark,
    "nginx-wrk-pld": parse_nginx_wrk_benchmark,
    "nginx-wrk": parse_nginx_wrk_benchmark,
    "iperf-tcp-pld": parse_iperf_benchmark,
    "iperf-tcp": parse_iperf_benchmark,
    "iperf-udp": parse_iperf_benchmark,
    "metrics-cpu": parse_cpu_benchmark,
    "metrics-memory": parse_memory_benchmark,
}


def match_value(possible_values: list[str], value_to_match: str) -> str:
    for value in possible_values:
        if value in value_to_match:
            return value
    logger.error(f"value {value_to_match} does not match any known values in {possible_values}")
    sys.exit(1)


def get_payload_size(file: str) -> str:
    match = re.search(r'-P([^-]+)', file)
    if match:
        return match.group(1)
    logger.error(f"No payload size found in file name {file}")
    sys.exit(1)


def extract_data_from_file(file: str) -> list[BenchmarkDataPoint]:
    provider = match_value(providers, file)
    approach = match_value(approaches, file)
    cluster = match_value(clusters, file)
    benchmark_type = match_value(benchmarks, file)
    data_type = match_value(data_types, file)
    payload_size = get_payload_size(file)
    if data_type == "client":
        data_type = "benchmark"
        parser = benchmark_type_parser_map[benchmark_type]
    else:
        parser = benchmark_type_parser_map[data_type]
    benchmark_data_points = []
    number = 0
    with open(file, 'r') as f:
        values = parser(f.read())
        for number, value in enumerate(values):
            benchmark_data_points.append(
                BenchmarkDataPoint(
                    provider=provider,
                    approach=approach,
                    cluster=cluster,
                    benchmark_type=benchmark_type,
                    data_type=data_type,
                    payload_size=payload_size,
                    number=number,
                    value=value
                )
            )
    return benchmark_data_points


def main():
    if len(sys.argv) < 2:
        logger.error("Usage: python extract_data.py <file>")
        sys.exit(1)

    file_name = sys.argv[1]
    if not os.path.isfile(file_name):
        logger.error(f"File {file_name} does not exist.")
        sys.exit(1)

    data_points = extract_data_from_file(file_name)

    for dp in data_points:
        print(json.dumps(dp.__dict__))


if __name__ == "__main__":
    logging.basicConfig(format="%(asctime)s %(levelname)s %(message)s", level=logging.INFO)
    main()
