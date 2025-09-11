# Releases

## v0.1.0

Initial release of falcon-limiter gem extracted from Falcon web server.

### Features

- **Priority-aware Semaphores**: Built on async-limiter for sophisticated resource management
- **Long Task Management**: Handle I/O vs CPU bound workloads effectively
- **Connection Limiting**: Control concurrent connections to prevent server overload  
- **HTTP Middleware**: Protocol::HTTP::Middleware integration for Falcon
- **Falcon Environment**: Turn-key setup with `Falcon::Environment::Limiter`
- **Resource Statistics**: Monitor utilization and contention
- **Thread-safe**: Full thread and fiber safety with priority-based fairness

### Dependencies

- `async-limiter >= 1.5` - Core concurrency limiting functionality
- `protocol-http ~> 0.31` - HTTP middleware integration
- `async >= 2.31.0` - Async framework with Deadline support

### Breaking Changes

This is the initial release extracted from Falcon, so there are no breaking changes from a previous version of falcon-limiter. However, if migrating from Falcon's built-in limiter functionality:

- Require `falcon-limiter` gem explicitly
- Use `Falcon::Environment::Limiter` instead of `Falcon::Environment::Server`
- Configuration remains the same via environment variables or programmatic setup

### Architecture

- Built on top of `Async::Limiter::Queued` with `Async::PriorityQueue`
- Uses `Async::Limiter::Token` for resource management
- Integrates with Falcon's HTTP pipeline through Protocol::HTTP::Middleware
- Supports priority-based resource allocation and automatic cleanup
