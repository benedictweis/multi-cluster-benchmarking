from dataclasses import dataclass
import logging
import typer
import os
import cattrs

from providers.provider import Provider, PROVIDERS_MAP
from approaches.approach import Approach, APPROACHES_MAP
from benchmarks.benchmark import Benchmark, BENCHMARKS_MAP

app = typer.Typer()

logger = logging.getLogger(__name__)


@dataclass
class Config:
    providers_dir: str
    approaches_dir: str
    benchmarks_dir: str
    results_dir: str
    kubeconfig_file: str
    context_1_file: str
    context_2_file: str
    benchmark_custom_file: str
    cluster_1_name: str
    cluster_2_name: str
    resource_create_timeout: str
    set_network_prefix: str
    provider: Provider
    approaches: list[Approach]
    benchmarks: list[Benchmark]
    payload_sizes: list[str]
    iperf_parallel_streams: list[str]
    benchmarks_n: str
    wait_before_cleanup: bool


converter = cattrs.Converter()
converter.register_structure_hook(Provider, lambda v, _: PROVIDERS_MAP[v]())
converter.register_structure_hook(Approach, lambda v, _: APPROACHES_MAP[v]())
converter.register_structure_hook(Benchmark, lambda v, _: BENCHMARKS_MAP[v]())

config: Config = None


@app.callback()
def config_callback(config_file: str = "config.yaml"):
    import yaml
    if not os.path.exists(config_file):
        logger.error(f"Config file '{config_file}' does not exist")
        raise typer.Exit(1)
    logger.debug(f"Loading config from {config_file}")
    global config
    config = converter.structure(yaml.safe_load(open(config_file)), Config)
    logger.debug(f"Loaded config: {config}")


@app.command(help="Create clusters for configured provider")
def clusters_create():
    provider = config.provider
    logger.info(f"Creating clusters for provider '{provider}'")


@app.command(help="Destroy clusters for configured provider")
def clusters_destroy():
    provider = config.provider
    logger.info(f"Destroying clusters for provider '{provider}'")


@app.command(help="Run benchmarks")
def run_benchmarks():
    logger.info("Running benchmarks")
    for approach in config.approaches:
        logger.info(f"Installing approach '{approach}'")

        if not config.benchmarks:
            logger.info("No benchmarks selected, only setting up the approach")
            print("Press any key to uninstall approach")
            input()
        else:
            for benchmark in config.benchmarks:
                variable_sizes = config.payload_sizes
                for variable_size in variable_sizes:
                    logger.info(f"Running benchmark '{benchmark}' with variable size {variable_size}")

        logger.info(f"Uninstalling approach '{approach}'")


if __name__ == "__main__":
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
    )
    app()
