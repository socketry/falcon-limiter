# Long Tasks

This guide explains how to use {ruby Falcon::Limiter::LongTask} to effectively manage I/O vs CPU bound workloads in your Falcon applications.

## Understanding Long Tasks

A **long task** in `falcon-limiter` is any operation that takes significant time (1+ seconds) and isn't CPU-bound, typically I/O operations like:

- Database queries.
- External API calls.
- File system operations.
- Network requests.
- Message queue operations.

The key insight is that during I/O operations, your application is waiting rather than consuming CPU resources. Long tasks allow the server to:

1. **Release the connection token** during I/O, allowing other requests to be accepted.
2. **Maintain responsiveness** by not blocking CPU-bound requests.
3. **Optimize resource utilization** by running multiple I/O operations concurrently.

## Usage

When using {ruby Falcon::Limiter::Environment}, a long task is automatically created for each request:

```ruby
# In your Rack application
run do |env|
	# Long task is available via Falcon::Limiter::LongTask.current
	long_task = Falcon::Limiter::LongTask.current
	
	if long_task
		# Start the long task for I/O operations
		long_task.start
		
		# Perform I/O operation
		database_query
		
		# Long task automatically stops when request completes
	end
	
	[200, {}, ["Response"]]
end
```

### Custom Delays

A delay is used to avoid starting a long task until we know that it's likely to be slow.

```ruby
run do |env|
	path = env["PATH_INFO"]
	
	case path
	when "/io"
		# Start long task with default delay (0.1 seconds):
		Falcon::Limiter::LongTask.current.start
		
		# Perform I/O operation:
		external_api_call
		
	when "/io-immediate"
		# Start immediately without delay:
		Falcon::Limiter::LongTask.current.start(delay: false)
		
		# Perform I/O operation:
		database_query
		
	when "/io-custom-delay"
		# Start with custom delay:
		Falcon::Limiter::LongTask.current.start(delay: 0.5)
		
		# Perform I/O operation:
		slow_file_operation
		
	when "/cpu"
		# Don't start long task for CPU-bound work:
		cpu_intensive_calculation
	end
	
	[200, {}, ["Completed"]]
end
```

### Block-based Long Tasks

You can use long tasks with blocks for automatic cleanup:

```ruby
require "net/http"

run do |env|
	path = env["PATH_INFO"]
	
	case path
	when "/api/weather"
		# Use block-based long task for automatic cleanup:
		response = Falcon::Limiter::LongTask.current.start do |long_task|
			# Make external API call:
			uri = URI("https://api.openweathermap.org/data/2.5/weather?q=London")
			Net::HTTP.get_response(uri)
			# Automatic LongTask#stop when block exits.
		end
		
		# CPU work happens outside the long task:
		result = JSON.parse(response.body)
		[200, {"content-type" => "application/json"}, [result.to_json]]
		
	when "/api/database"
		# Multiple I/O operations in one long task:
		users, enriched_data = Falcon::Limiter::LongTask.current.start do
			# Database query
			users = database.query("SELECT * FROM users WHERE active = true")
			
			# External service call:
			uri = URI("https://api.example.com/enrich")
			enriched_data = Net::HTTP.post_form(uri, {user_ids: users.map(&:id)})
			
			[users, enriched_data]
		end
		
		# CPU work happens outside the long task:
		parsed_data = JSON.parse(enriched_data.body)
		result = users.zip(parsed_data)
		[200, {"content-type" => "application/json"}, [result.to_json]]
	end
end
```

The block form ensures the long task is properly stopped even if an exception occurs. They can also be nested.

## Long Task Lifecycle

### 1. Creation

Long tasks are created automatically by {ruby Falcon::Limiter::Middleware} for each request when long task support is enabled.

### 2. Starting

When you call `start()`, the long task:

- Waits for the configured delay (default: 0.1 seconds).
- Acquires a long task token from the limiter.
- Releases the connection token, allowing new connections.
- Marks the connection as non-persistent to prevent token leakage

### 3. Execution

During long task execution:

- The connection token is released, so new requests can be accepted.
- The long task token prevents too many I/O operations from running concurrently.
- Your I/O operation runs normally.

### 4. Completion

When the request completes, the long task automatically:

- Releases the long task token.
- Re-acquires the connection token with high priority.
- Cleans up resources.
