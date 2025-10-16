FROM debian:latest

RUN apt-get update
RUN apt-get install -y \
    curl \
    apt-transport-https \
    ca-certificates \
    gnupg

ARG CLI_ARCH
ENV CLI_ARCH=${CLI_ARCH}
RUN echo "CLI_ARCH is set to: ${CLI_ARCH}"

ENV K8S_PKG_VERSION=v1.33
ENV KIND_VERSION=v0.30.0
ENV LIQO_CTL_VERSION=v1.0.1
ENV SKUPPER_CLI_VERSION=2.1.2
ENV K9S_VERSION=v0.50.15
ENV ISTIO_VERSION=1.26.2

RUN curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_PKG_VERSION}/deb/Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_PKG_VERSION}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list && \
    chmod 644 /etc/apt/sources.list.d/kubernetes.list

RUN curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor -o /usr/share/keyrings/helm.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | tee /etc/apt/sources.list.d/helm-stable-debian.list

RUN curl -fsSL https://packages.smallstep.com/keys/apt/repo-signing-key.gpg -o /etc/apt/trusted.gpg.d/smallstep.asc && \
    echo 'deb [signed-by=/etc/apt/trusted.gpg.d/smallstep.asc] https://packages.smallstep.com/stable/debian debs main' | tee /etc/apt/sources.list.d/smallstep.list

RUN curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

RUN CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt) && \
    curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum} && \
    sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum && \
    tar xzvf cilium-linux-${CLI_ARCH}.tar.gz -C /usr/local/bin && \
    rm cilium-linux-${CLI_ARCH}.tar.gz cilium-linux-${CLI_ARCH}.tar.gz.sha256sum

RUN curl -Lo ./kind https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${CLI_ARCH} && \
    chmod +x ./kind && \
    mv ./kind /usr/local/bin/kind

RUN curl -Lo /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${CLI_ARCH} && \
    chmod +x /usr/local/bin/yq

RUN curl --fail -LS "https://github.com/liqotech/liqo/releases/download/${LIQO_CTL_VERSION}/liqoctl-linux-${CLI_ARCH}.tar.gz" | tar -xz &&\ 
    install -o root -g root -m 0755 liqoctl /usr/local/bin/liqoctl

RUN curl --fail -LS "https://github.com/skupperproject/skupper/releases/download/${SKUPPER_CLI_VERSION}/skupper-cli-${SKUPPER_CLI_VERSION}-linux-${CLI_ARCH}.tgz" | tar -xz &&\ 
    install -o root -g root -m 0755 skupper /usr/local/bin/skupper

RUN curl --fail -LS "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_${CLI_ARCH}.tar.gz" | tar -xz &&\ 
    install -o root -g root -m 0755 k9s /usr/local/bin/k9s

RUN curl -Ls https://get.submariner.io | bash
ENV PATH="$PATH:~/.local/bin"

RUN curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install-edge | sh
ENV PATH="/root/.linkerd2/bin:${PATH}"

RUN curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${ISTIO_VERSION} sh -
ENV PATH="$PATH:/istio-${ISTIO_VERSION}/bin"

RUN apt-get update
RUN apt-get install -y \
    iputils-ping \
    kubectl \ 
    helm \
    step-cli \
    jq \
    gettext \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin \
    xxd

RUN echo 'alias k=kubectl' >> /root/.bashrc && \
    echo 'alias ks="kubectl -n kube-system"' >> /root/.bashrc

WORKDIR /multi-cluster-benchmarking

ENV KUBECONFIG=/multi-cluster-benchmarking/kubeconfig.yaml

COPY . .
