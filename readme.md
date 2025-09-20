# Falcon Limiter

Advanced concurrency control and resource limiting for Falcon web server, built on top of [async-limiter](https://github.com/socketry/async-limiter).

[![Development Status](https://github.com/socketry/falcon-limiter/workflows/Test/badge.svg)](https://github.com/socketry/falcon-limiter/actions?workflow=Test)

## Features

This gem provides sophisticated concurrency management for Falcon applications by:

  - **Connection Limiting**: Control the number of concurrent connections to prevent server overload
  - **Long Task Management**: Handle I/O vs CPU bound workloads effectively by releasing resources during long operations
  - **Priority-based Resource Allocation**: Higher priority tasks get preferential access to limited resources
  - **Automatic Resource Cleanup**: Ensures proper resource release even when exceptions occur
  - **Built-in Statistics**: Monitor resource utilization and contention

## Installation

Add this line to your application's Gemfile:

``` ruby
gem 'falcon-limiter'
```

## Usage

Please see the [project documentation](https://socketry.github.io/falcon-limiter/) for more details.

### Basic Falcon Environment Integration

``` ruby
#!/usr/bin/env falcon-host

require "falcon-limiter"

service "myapp.localhost" do
  include Falcon::Environment::Limiter
  
  # Configure concurrency limits
  limiter_configuration.max_long_tasks = 8
  limiter_configuration.max_accepts = 2
  
  scheme "http"
  url "http://localhost:9292"
  
  rack_app do
    run lambda { |env|
      # Start long task for I/O bound work
      Falcon::Limiter::LongTask.current&.start
      
      # Long I/O operation (database query, external API call, etc.)
      external_api_call
      
      # Optional manual stop (auto-cleanup on response end)
      Falcon::Limiter::LongTask.current&.stop
      
      [200, {}, ["OK"]]
    }
  end
end
```

### Manual Middleware Setup

``` ruby
require "falcon-limiter"
require "protocol/http/middleware"

# Configure middleware stack
middleware = Protocol::HTTP::Middleware.build do
  use Falcon::Limiter::Middleware, 
      max_long_tasks: 4,
      max_accepts: 2
  use Protocol::Rack::Adapter
  run rack_app
end
```

### Direct Semaphore Usage

``` ruby
require "falcon-limiter"

# Create a semaphore for database connections
db_semaphore = Falcon::Limiter::Semaphore.new(5)

# Acquire a connection
token = db_semaphore.acquire

begin
  # Use database connection
  database_operation
ensure
  # Release the connection
  token.release
end
```

## Configuration

Configure limits using environment variables or programmatically:

``` bash
export FALCON_LIMITER_MAX_LONG_TASKS=8
export FALCON_LIMITER_MAX_ACCEPTS=2
export FALCON_LIMITER_START_DELAY=0.6
```

Or in code:

``` ruby
Falcon::Limiter.configure do |config|
  config.max_long_tasks = 8
  config.max_accepts = 2
  config.start_delay = 0.6
end
```

## Architecture

Falcon Limiter is built on top of [async-limiter](https://github.com/socketry/async-limiter), providing:

  - **Thread-safe resource management** using priority queues
  - **Integration with Falcon's HTTP pipeline** through Protocol::HTTP::Middleware
  - **Automatic connection token management** for optimal resource utilization
  - **Priority-based task scheduling** to prevent resource starvation

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `bundle exec sus` to run the tests.

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

## Releases

Please see the [project releases](https://socketry.github.io/falcon-limiter/releases/index) for all releases.

### v0.1.0

  - Initial implementation.

## See Also

  - [falcon](https://github.com/socketry/falcon) - A fast, asynchronous, rack-compatible web server.
  - [async-limiter](https://github.com/socketry/async-limiter) - Execution rate limiting for Async.
  - [async](https://github.com/socketry/async) - A concurrency framework for Ruby.
