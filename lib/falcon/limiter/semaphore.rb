# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/limiter"
require "async/limiter/token"
require "async/priority_queue"

module Falcon
	module Limiter
		# Simple wrapper around Async::Limiter::Queued that provides the interface 
		# expected by Falcon while leveraging async-limiter's implementation.
		class Semaphore
			def initialize(limit = 1)
				raise ArgumentError, "Limit required!" unless limit && limit > 0
				
				@limit = limit
				@reacquire_count = 0
				@reacquire_mutex = Mutex.new
				
				# Create priority queue and pre-populate with tokens
				queue = Async::PriorityQueue.new
				limit.times { queue.push(true) }
				
				@limiter = Async::Limiter::Queued.new(queue)
			end
			
			attr_reader :limit
			
			# Get number of available resources
			def available_count
				@limiter.queue.size
			end
			
			# Get number of acquired resources  
			def acquired_count
				@limit - available_count
			end
			
			# Get number of threads waiting 
			def waiting_count
				@limiter.queue.waiting
			end
			
			# Get number waiting to reacquire
			def reacquire_count
				@reacquire_mutex.synchronize { @reacquire_count }
			end
			
			# Check if the limiter is at capacity
			def limited?
				@limiter.limited?
			end
			
			# Acquire a token, may block until available
			# @param priority [Integer] Priority level (higher = more urgent)
			# @param timeout [Numeric] Timeout for acquisition
			# @returns [Async::Limiter::Token, nil] A token if successful
			def acquire(priority: 0, timeout: nil)
				Async::Limiter::Token.acquire(@limiter, priority: priority, timeout: timeout)
			end
			
			# Try to acquire without blocking
			# @param priority [Integer] Priority level
			# @returns [Async::Limiter::Token, nil] A token if available immediately
			def try_acquire(priority: 0)
				Async::Limiter::Token.acquire(@limiter, priority: priority, timeout: 0)
			end
			
			# Reacquire with higher priority (for long task pattern)
			# @param priority [Integer] Priority level (default: 1000 for high priority)  
			# @param timeout [Numeric] Timeout for acquisition
			# @returns [Async::Limiter::Token, nil] A token if successful
			def reacquire(priority: 1000, timeout: nil)
				@reacquire_mutex.synchronize { @reacquire_count += 1 }
				
				begin
					Async::Limiter::Token.acquire(@limiter, priority: priority, timeout: timeout)
				ensure
					@reacquire_mutex.synchronize { @reacquire_count = [@reacquire_count - 1, 0].max }
				end
			end
			
			# Direct access to the underlying limiter for advanced usage
			attr_reader :limiter
		end
	end
end
