# Kubernetes Multi Cluster Benchmarking Setup

## Try it out

This requires docker to be installed on your system!

1. Edit `config.cfg` file to your liking
2. Enter `./benchmarks.sh help` to get an overview of commands available
3. Enter `./benchmarks.sh clusters-create` to create two k8s clusters with the configured provider
4. Enter `./docker.sh bash benchmarks.sh benchmarks` to run the benchmarks using a dedicated docker container, this creates a new directory in the `results` folder
5. Enter `./benchmarks.sh plot <newly created folder>` to generate plots into `plotting/results`

## Results

![Comparison of TCP Throughput](./plots/iperf-tcp-benchmark.svg)
![Comparison of TCP Throughput with different amount of parallel streams](./plots/iperf-tcp-par-comparison.svg)
![Comparison of TCP Throughput with different payload sizes](./plots/iperf-tcp-pld-comparison.svg)

![Comparison of UDP Throughput](./plots/iperf-udp-benchmark.svg)

![Comparison of HTTP Latency for single requests](./plots/nginx-curl-benchmark.svg)
![Comparison of HTTP Latency for single requests with different payload sizes](./plots/nginx-curl-pld-comparison.svg)

![Comparison of HTTP Latency for many requests](./plots/nginx-wrk-benchmark.svg)
![Comparison of HTTP Latency for many requests with different payload sizes](./plots/nginx-wrk-pld-comparison.svg)
