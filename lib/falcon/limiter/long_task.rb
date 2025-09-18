# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Marc-André Cournoyer.
# Copyright, 2025, by Francisco Mejia.
# Copyright, 2025, by Samuel Williams.

require "async/task"
require_relative "semaphore"

Fiber.attr_accessor :falcon_limiter_long_task

module Falcon
	module Limiter
		# Manages long-running tasks by releasing connection tokens during I/O operations to prevent contention and maintain server responsiveness.
		#
		# A long task is any long (1+ sec) operation that isn't CPU-bound (usually long I/O). Starting a long task lets the server accept one more (potentially CPU-bound) request. This allows us to handle many concurrent I/O bound requests, without adding contention (which impacts latency).
		class LongTask
			# The priority to use when stopping a long task to re-acquire the connection token.
			STOP_PRIORITY = 1000
			
			# @returns [LongTask] The current long task.
			def self.current
				Fiber.current.falcon_limiter_long_task
			end
			
			# Assign the current long task.
			def self.current=(long_task)
				Fiber.current.falcon_limiter_long_task = long_task
			end
			
			# Execute the block with the current long task.
			def with
				previous = self.class.current
				self.class.current = self
				yield
			ensure
				self.class.current = previous
			end
			
			# Create a long task for the given request.
			# Extracts connection token from the request if available for proper token management.
			# @parameter limiter [Async::Limiter] The limiter instance for managing concurrent long tasks.
			# @parameter request [Object] The HTTP request object to extract connection information from.
			# @parameter options [Hash] Additional options passed to the constructor.
			# @returns [LongTask] A new long task instance ready for use.
			def self.for(request, limiter, **options)
				# Get connection token from request if possible:
				connection_token = request&.connection&.stream&.io&.token rescue nil
				
				return new(request, limiter, connection_token, **options)
			end
			
			# Initialize a new long task with the specified configuration.
			# @parameter limiter [Async::Limiter] The limiter instance for controlling concurrency.
			# @parameter connection_token [Async::Limiter::Token, nil] Optional connection token to manage.
			# @parameter start_delay [Float] Delay in seconds before starting the long task (default: 0.1).
			def initialize(request, limiter, connection_token = nil, start_delay: 0.1)
				@request = request
				@limiter = limiter
				@connection_token = connection_token
				@start_delay = start_delay
				
				@token = Async::Limiter::Token.new(@limiter)
				@delayed_start_task = nil
			end
			
			# Check if the long task has been started.
			# @returns [Boolean] True if the long task token has been acquired, false otherwise.
			def started?
				@token.acquired? || @delayed_start_task
			end
			
			# Start the long task, optionally with a delay to avoid overhead for short operations
			def start(start_delay: @start_delay)
				# If already started, nothing to do:
				if started?
					if block_given?
						return yield self
					else
						return self
					end
				end
				
				# Otherwise, start the long task:
				if start_delay&.positive?
					# Wait specified delay before starting the long task:
					@delayed_start_task = Async do
						sleep(start_delay)
						self.acquire
					rescue Async::Stop
						# Gracefully exit on stop.
					ensure
						@delayed_start_task = nil
					end
				else
					# Start the long task immediately:
					self.acquire
				end
				
				return self unless block_given?
				
				begin
					yield self
				ensure
					self.stop
				end
			end
			
			# Stop the long task and restore connection token
			def stop(force: false, **options)
				if delayed_start_task = @delayed_start_task
					@delayed_start_task = nil
					delayed_start_task.stop
				end
				
				# Re-acquire the connection token with high priority than inbound requests:
				options[:priority] ||= STOP_PRIORITY
				
				# Release the long task token:
				release(force, **options)
			end
			
			private
			
			# This acquires the long task token and releases the connection token if it exists.
			# This marks the beginning of a long task.
			# @parameter options [Hash] The options to pass to the long task token acquisition.
			def acquire(**options)
				return if @token.acquired?
				
				# Wait if we've reached our limit of ongoing long tasks.
				if @token.acquire(**options)
					# Release the socket accept token.
					@connection_token&.release
					
					# Mark connection as non-persistent since we released the token.
					make_non_persistent!
				end
			end
			
			# This releases the long task token and re-acquires the connection token if it exists.
			# This marks the end of a long task.
			# @parameter force [Boolean] Whether to force the release of the long task token without re-acquiring the connection token.
			# @parameter options [Hash] The options to pass to the connection token re-acquisition.
			def release(force = false, **options)
				return if @token.released?
				
				@token.release
				
				return if force
				
				# Re-acquire the connection token to prevent overloading the connection limiter:
				@connection_token&.acquire(**options)
			end
			
			def make_non_persistent!
				# Keeping the connection alive here is problematic because if the next request is slow,
				# it will "block the server" since we have relinquished the token already.
				@request&.connection&.persistent = false
			rescue NoMethodError
				# Connection may not support persistent flag
			end
		end
	end
end
