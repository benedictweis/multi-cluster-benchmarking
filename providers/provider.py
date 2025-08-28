from abc import ABC, abstractmethod


class Provider(ABC):
    @abstractmethod
    def create(self):
        pass

    @abstractmethod
    def destroy(self):
        pass

    def __str__(self) -> str:
        return self.__class__.__name__


class K3sProvider(Provider):
    def create(self):
        pass

    def destroy(self):
        pass


class KindProvider(Provider):
    def create(self):
        pass

    def destroy(self):
        pass


class KindIPv6Provider(Provider):
    def create(self):
        pass

    def destroy(self):
        pass


PROVIDERS_MAP = {
    "k3s": K3sProvider,
    "kind": KindProvider,
    "kind-ipv6": KindIPv6Provider
}
