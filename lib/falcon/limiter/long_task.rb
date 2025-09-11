# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/task"
require_relative "semaphore"

module Falcon
	module Limiter
		# Manages long-running tasks by releasing connection tokens during I/O operations
		# to prevent GVL contention and maintain server responsiveness.
		# 
		# A long task is any long (1+ sec) operation that doesn't lock the GVL. Usually long I/O.
		# Starting a long task lets the server accept one more (potentially CPU-bound) request.
		# This allows us to handle many concurrent I/O bound requests, without adding contention on the GVL.
		class LongTask
			START_DELAY = 0.6 # 600ms - avoid overhead for short operations
			
			ConnectionWentAwayError = Class.new(StandardError)
			
			def initialize(request, long_task_semaphore:, socket_accept_semaphore:, start_delay: START_DELAY)
				@request = request
				@long_task_semaphore = long_task_semaphore
				@socket_accept_semaphore = socket_accept_semaphore
				@start_delay = start_delay
				@started = false
				@long_task_token = nil
				@delayed_start_task = nil
				@start_time = nil
			end
			
			attr_reader :request
			
			def started?
				@started
			end
			
			# Start the long task, optionally with a delay to avoid overhead for short operations
			def start(delayed: true)
				return if started?
				
				# Must have socket accept token to proceed
				unless socket_accept_token
					return
				end
				
				if delayed && @start_delay > 0
					# Wait specified delay before starting the long task
					@delayed_start_task = Async do
						sleep(@start_delay)
						release_socket_accept_semaphore unless started?
					end
				else
					# Start the long task immediately
					release_socket_accept_semaphore
				end
			end
			
			# Stop the long task and restore connection token
			def stop(force: false)
				unless started?
					# If we haven't started the long task yet, cancel the delayed start
					if @delayed_start_task
						@delayed_start_task.stop
						@delayed_start_task = nil
					end
					return
				end
				
				# Release the long_task token first to avoid deadlocks
				if @long_task_token
					@long_task_token.release
					@long_task_token = nil
				end
				
				@started = false
				
				# Reacquire socket accept token unless forced
				unless force
					# Reacquire socket accept token with high priority
					if socket_accept_token && @socket_accept_semaphore
						@socket_accept_token = @socket_accept_semaphore.reacquire
					end
				end
			end
			
			private
			
			def release_socket_accept_semaphore
				@start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
				
				# Wait if we've reached our limit of ongoing long tasks
				@long_task_token = @long_task_semaphore.acquire(timeout: nil)
				@started = true
				
				# Release the socket accept token
				socket_accept_token&.release
				
				# Mark connection as non-persistent since we released the token
				make_non_persistent
			end
			
			def socket_accept_token
				return @socket_accept_token if defined?(@socket_accept_token)
				
				# Get token from connection if available
				@socket_accept_token = @request&.connection&.stream&.io&.token
			rescue NoMethodError
				raise ConnectionWentAwayError
			end
			
			def make_non_persistent
				# Keeping the connection alive here is problematic because if the next request is slow,
				# it will "block the server" since we have relinquished the token already.
				@request&.connection&.persistent = false
			rescue NoMethodError
				# Connection may not support persistent flag
			end
		end
	end
end
