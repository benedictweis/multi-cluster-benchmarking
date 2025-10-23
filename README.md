# Kubernetes Multi Cluster Benchmarking Setup

## Try it out

This requires docker to be installed on your system!

1. Edit `config.cfg` file to your liking
2. Enter `./benchmarks.sh help` to get an overview of commands available
3. Enter `./benchmarks.sh clusters-create` to create two k8s clusters with the configured provider
4. Enter `./docker.sh bash benchmarks.sh benchmarks` to run the benchmarks using a dedicated docker container, this creates a new directory in the `results` folder
5. Enter `./benchmarks.sh plot <newly created folder>` to generate plots into `plotting/results`

## Results

![Benchmarks done](./assets/benchmarks.svg)

The benchmark results are presented in the order of the table.

![Comparison of TCP Throughput](./assets/iperf-tcp-benchmark.svg)
![Comparison of TCP Throughput with different amount of parallel streams](./assets/iperf-tcp-par-comparison.svg)
![Comparison of TCP Throughput with different payload sizes](./assets/iperf-tcp-pld-comparison.svg)

![Comparison of UDP Throughput](./assets/iperf-udp-benchmark.svg)

![Comparison of HTTP Latency for single requests](./assets/nginx-curl-benchmark.svg)
![Comparison of HTTP Latency for single requests with different payload sizes](./assets/nginx-curl-pld-comparison.svg)

![Comparison of HTTP Latency for many requests](./assets/nginx-wrk-benchmark.svg)
![Comparison of HTTP Latency for many requests with different payload sizes](./assets/nginx-wrk-pld-comparison.svg)

![Instance settings](./assets/settings.svg)

Instance-1 and Instance-2 are two ec2 instances running in the same placement group, subnet, VPC and region on AWS.
