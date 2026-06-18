# Releases

## v0.5.0

  - Add optional `Falcon::Limiter::LongTask#start(tags:)` metadata for instrumentation.

## v0.4.0

  - Add `Falcon::Limiter::LongTask#pending?` for detecting delayed long tasks which have not acquired yet.

## v0.3.0

  - Use `Async::Limiter::Token#close` when closing sockets so cached tokens cannot re-acquire after socket close.

## v0.2.0

  - Use `async-limiter` v2.2 utilization metrics for connection and long task limiter telemetry.

## v0.1.0

  - Initial implementation.
