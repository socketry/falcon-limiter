# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Josh Teeter.
# Copyright, 2025, by Samuel Williams.

require_relative "middleware"
require_relative "semaphore"
require_relative "wrapper"

module Falcon
	module Limiter
		# A flat environment module for falcon-limiter services.
		#
		# Provides simple, declarative configuration for concurrency limiting.
		# Override these methods in your service to customize behavior.
		module Environment
			# Maximum number of concurrent long tasks (default: 10).
			# If this is nil or non-positive, long task support will be disabled.
			# @returns [Integer] The maximum number of concurrent long tasks.
			def limiter_maximum_long_tasks
				10
			end
			
			# @returns [Integer] The maximum number of concurrent connection accepts.
			def limiter_maximum_connections
				1
			end
			
			# @returns [Float] The delay before starting long task in seconds.
			def limiter_start_delay
				0.1
			end
			
			# @returns [Async::Limiter::Queued] The limiter for coordinating long tasks and connection accepts.
			def connection_limiter
				# Create priority queue and pre-populate with tokens:
				queue = Async::PriorityQueue.new
				limiter_maximum_connections.times{queue.push(true)}
				
				Async::Limiter::Queued.new(queue)
			end
			
			# @returns [Class] The middleware class to use for long task support.
			def limiter_middleware_class
				Middleware
			end
			
			# @returns [Protocol::HTTP::Middleware] The middleware with long task support, if enabled.
			def limiter_middleware(middleware)
				# Create middleware with long task support if enabled:
				if limiter_maximum_long_tasks&.positive?
					limiter_middleware_class.new(
						middleware, 
						connection_limiter: connection_limiter,
						maximum_long_tasks: limiter_maximum_long_tasks,
						start_delay: limiter_start_delay
					)
				else
					middleware
				end
			end
			
			# @returns [Protocol::HTTP::Middleware] The middleware with long task support, if enabled.
			def middleware
				limiter_middleware(super)
			end
			
			# @returns [Falcon::Limiter::Wrapper] The wrapper for the connection limiter.
			def limiter_wrapper
				Wrapper.new(connection_limiter)
			end
			
			# @returns [IO::Endpoint::Wrapper] The endpoint with connection limiting.
			def endpoint
				super.with(wrapper: limiter_wrapper)
			end
		end
	end
end
