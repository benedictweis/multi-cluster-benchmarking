from abc import ABC, abstractmethod


class Approach(ABC):
    @abstractmethod
    def install(self):
        pass

    @abstractmethod
    def uninstall(self):
        pass

    def pre_benchmark(self):
        pass

    def post_benchmark(self):
        pass


class CiliumNoneApproach(Approach):
    def install(self):
        pass

    def uninstall(self):
        pass


APPROACHES_MAP = {
    "cilium_none": CiliumNoneApproach
}
