# Falcon Limiter Examples

This directory contains examples demonstrating the Falcon::Limiter functionality for managing concurrent workloads.

## Overview

The Falcon::Limiter system helps distinguish between I/O bound and CPU bound workloads:

- **I/O bound work**: Long tasks that benefit from releasing connection tokens to improve concurrency
- **CPU bound work**: Tasks that should keep connection tokens to prevent GVL contention

## Examples

### 1. Falcon Environment (`falcon.rb`)

Uses `Falcon::Environment::Limiter` for turn-key setup:

```bash
falcon-host ./falcon.rb
```

**Endpoints:**
- `/fast` - Quick response without long task
- `/slow` - I/O bound task using long task management  
- `/cpu` - CPU bound task without long task
- `/stats` - Show limiter statistics

### 2. Rack Application (`config.ru`)

Basic Rack app with manual limiter middleware:

```bash
falcon serve -c config.ru
```

**Endpoints:**
- `/long-io` - Long I/O operation with long task
- `/short` - Short operation (long task delay avoids overhead)
- `/token-info` - Shows connection token information
- `/` - Simple hello response

## Key Concepts

### Long Task Management

```ruby
# For I/O bound operations
request.long_task&.start
external_api_call()  # Long I/O operation
request.long_task&.stop  # Optional - auto cleanup on response end
```

### Connection Token Release

Long tasks automatically:
1. Extract and release connection tokens during I/O operations
2. Acquire long task tokens from a separate semaphore
3. Allow more connections to be accepted while I/O is pending
4. Clean up automatically when response finishes

### Configuration

```ruby
# Environment-based
ENV["FALCON_LIMITER_MAX_LONG_TASKS"] = "8"
ENV["FALCON_LIMITER_MAX_ACCEPTS"] = "2"

# Or programmatic
Falcon::Limiter.configure do |config|
  config.max_long_tasks = 8
  config.max_accepts = 2
  config.start_delay = 0.6
end
```

## Testing Load Scenarios

Test with multiple concurrent requests:

```bash
# Test slow endpoint concurrency
curl -s "http://localhost:9292/slow" &
curl -s "http://localhost:9292/slow" &
curl -s "http://localhost:9292/slow" &

# Should still be responsive for fast requests
curl -s "http://localhost:9292/fast"
```

## Benefits

1. **Better Concurrency**: I/O operations don't block connection acceptance
2. **Graceful Degradation**: System remains responsive under high load  
3. **Resource Management**: Prevents GVL contention for CPU work
4. **Automatic Cleanup**: Long tasks clean up automatically on response completion
