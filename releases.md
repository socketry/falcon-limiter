# Releases

## Unreleased

- Use `Async::Limiter::Token#close` when closing sockets so cached tokens cannot re-acquire after socket close.

## v0.2.0

  - Use `async-limiter` v2.2 utilization metrics for connection and long task limiter telemetry.

## v0.1.0

  - Initial implementation.
