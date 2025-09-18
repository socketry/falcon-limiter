# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Josh Teeter.
# Copyright, 2025, by Samuel Williams.

require "protocol/http/middleware"
require_relative "long_task"
require_relative "semaphore"

module Falcon
	module Limiter
		# Protocol::HTTP middleware that provides long task management for requests.
		# This allows applications to manage I/O vs CPU bound workloads effectively.
		class Middleware < Protocol::HTTP::Middleware
			# Initialize the middleware with limiting configuration.
			# @parameter delegate [Object] The next middleware in the chain to call.
			# @parameter connection_limiter [Async::Limiter] Connection limiter instance for managing accepts.
			# @parameter maximum_long_tasks [Integer] Maximum number of concurrent long tasks (default: 4).
			# @parameter start_delay [Float] Delay in seconds before starting long tasks (default: 0.1).
			def initialize(delegate, connection_limiter:, maximum_long_tasks: 4, start_delay: 0.1)
				super(delegate)
				
				@maximum_long_tasks = maximum_long_tasks
				@start_delay = start_delay
				@connection_limiter = connection_limiter
				@long_task_limiter = Semaphore.new(maximum_long_tasks)
			end
			
			attr_reader :maximum_long_tasks, :start_delay, :long_task_limiter, :connection_limiter
			
			# Process an HTTP request with long task management support.
			# Creates a long task context that applications can use to manage I/O operations.
			# @parameter request [Object] The HTTP request to process.
			# @returns [Object] The HTTP response from the downstream middleware.
			def call(request)
				# Create LongTask instance for this request if enabled
				long_task = LongTask.for(request, @long_task_limiter, start_delay: @start_delay)
				
				# Use scoped context for clean access
				long_task.with do
					response = super(request)
					
					if long_task.started?
						Protocol::HTTP::Body::Completable.wrap(response) do
							long_task.stop(force: true)
						end
					end
					
					response
				end
			end
			
			# Get semaphore statistics
			def statistics
				{
					long_task_limiter: @long_task_limiter.statistics,
					connection_limiter: @connection_limiter.statistics
				}
			end
		end
	end
end
