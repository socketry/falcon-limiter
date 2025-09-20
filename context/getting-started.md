# Getting Started

This guide explains how to get started with `falcon-limiter` for advanced concurrency control and resource limiting in Falcon web applications.

## Installation

Add the gem to your project:

```bash
$ bundle add falcon-limiter
```

## Core Concepts

`falcon-limiter` has one main concept:

- {ruby Falcon::Limiter::LongTask} represents operations that take significant time but aren't CPU-intensive (like database queries or API calls).

When you start a Long Task, the server:

- Releases the connection token so new requests can be accepted.
- Continues processing your I/O operation in the background.
- Prevents too many I/O operations from running simultaneously.
- Maintains responsiveness for CPU-bound requests.

This means your server can handle many concurrent I/O operations without blocking quick CPU-bound requests.

## Usage

The easiest way to get started is using the {ruby Falcon::Limiter::Environment} module:

```ruby
#!/usr/bin/env falcon-host
# frozen_string_literal: true

require "falcon/limiter/environment"
require "falcon/environment/rack"

service "myapp.localhost" do
	include Falcon::Environment::Rack
	include Falcon::Limiter::Environment
	
	# If you use a custom endpoint, you need to use it with the limiter wrapper:
	endpoint do
		Async::HTTP::Endpoint.parse("http://localhost:9292").with(wrapper: limiter_wrapper)
	end
end
```

Then in your Rack application:

```ruby
# config.ru
require "falcon/limiter/long_task"

run do |env|
	path = env["PATH_INFO"]
	
	case path
	when "/io"
		# For I/O bound work, start a long task to release the connection token:
		Falcon::Limiter::LongTask.current.start
		
		# Long I/O operation (database query, external API call, etc.).
		sleep(5) # Simulating I/O.
		
	when "/cpu"
		# For CPU bound work, keep the connection token.
		# This ensures only limited CPU work happens concurrently.
		sleep(5) # Simulating CPU work.
	end
	
	[200, {"content-type" => "text/plain"}, ["Request completed"]]
end
```

### Understanding the Behavior

With the default configuration:

- **Connection limit**: 1 (only 1 connection accepted at a time)
- **Long task limit**: 10 (up to 10 concurrent I/O operations)

This means:

1. **CPU-bound requests** (`/cpu`) will be processed sequentially - only one at a time
2. **I/O-bound requests** (`/io`) can run concurrently (up to 10) because they release their connection token
3. **Mixed workloads** work optimally - I/O requests don't block CPU requests from being accepted

### Configuration

You can customize the limits by overriding the environment methods:

```ruby
service "myapp.localhost" do
	include Falcon::Environment::Rack
	include Falcon::Limiter::Environment
	
	# Override default limits
	def limiter_maximum_connections
		2  # Allow 2 concurrent connections
	end
	
	def limiter_maximum_long_tasks
		8  # Allow 8 concurrent I/O operations
	end
	
	def limiter_start_delay
		0.05  # Reduce delay before starting long tasks
	end
	
	endpoint do
		Async::HTTP::Endpoint.parse("http://localhost:9292").with(wrapper: limiter_wrapper)
	end
end
```

## Testing Your Setup

You can test the behavior using the included [load example](../../examples/load/):

```bash
# Start the server
$ cd examples/load
$ bundle exec ./falcon.rb

# In another terminal, test CPU-bound requests (will be sequential)
$ curl http://localhost:9292/cpu &
$ curl http://localhost:9292/cpu &

# Test I/O-bound requests (will be concurrent)
$ curl http://localhost:9292/io &
$ curl http://localhost:9292/io &
$ curl http://localhost:9292/io &
```
