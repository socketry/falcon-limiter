# Falcon Limiter

Advanced concurrency control and resource limiting for Falcon web server, built on top of [async-limiter](https://github.com/socketry/async-limiter).

[![Development Status](https://github.com/socketry/falcon-limiter/workflows/Test/badge.svg)](https://github.com/socketry/falcon-limiter/actions?workflow=Test)

## Features

This gem provides sophisticated concurrency management for Falcon applications by:

  - **Connection Limiting**: Control the number of concurrent connections to prevent server overload.
  - **Long Task Management**: Handle I/O vs CPU bound workloads effectively by releasing resources during long operations.
  - **Priority-based Resource Allocation**: Higher priority tasks get preferential access to limited resources.
  - **Automatic Resource Cleanup**: Ensures proper resource release even when exceptions occur.
  - **Built-in Statistics**: Monitor resource utilization and contention.

## Usage

Please see the [project documentation](https://socketry.github.io/falcon-limiter/) for more details.

  - [Getting Started](https://socketry.github.io/falcon-limiter/guides/getting-started/index) - This guide explains how to get started with `falcon-limiter` for advanced concurrency control and resource limiting in Falcon web applications.

  - [Long Tasks](https://socketry.github.io/falcon-limiter/guides/long-tasks/index) - This guide explains how to use <code class="language-ruby">Falcon::Limiter::LongTask</code> to effectively manage I/O vs CPU bound workloads in your Falcon applications.

## Releases

Please see the [project releases](https://socketry.github.io/falcon-limiter/releases/index) for all releases.

### v0.1.0

  - Initial implementation.

## See Also

  - [falcon](https://github.com/socketry/falcon) - A fast, asynchronous, rack-compatible web server.
  - [async-limiter](https://github.com/socketry/async-limiter) - Execution rate limiting for Async.
  - [async](https://github.com/socketry/async) - A concurrency framework for Ruby.

## Contributing

We welcome contributions to this project.

1.  Fork it.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create new Pull Request.

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.
