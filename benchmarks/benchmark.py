from abc import ABC, abstractmethod


class Benchmark(ABC):
    @abstractmethod
    def deploy_client(self):
        pass

    @abstractmethod
    def deploy_server(self):
        pass

    @abstractmethod
    def cleanup_client(self):
        pass

    @abstractmethod
    def cleanup_server(self):
        pass


class NginxCurlBenchmark(Benchmark):
    def deploy_client(self):
        pass

    def deploy_server(self):
        pass

    def cleanup_client(self):
        pass

    def cleanup_server(self):
        pass


BENCHMARKS_MAP = {
    "nginx_curl": NginxCurlBenchmark
}
