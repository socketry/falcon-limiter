# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "protocol/http/middleware"
require_relative "long_task"
require_relative "semaphore"
require_relative "configuration"

module Falcon
	module Limiter
		# Protocol::HTTP middleware that provides long task management for requests.
		# This allows applications to manage I/O vs CPU bound workloads effectively.
		class Middleware < Protocol::HTTP::Middleware
			def initialize(app, configuration: Configuration.default, long_task_semaphore: nil, socket_accept_semaphore: nil)
				super(app)
				@configuration = configuration
				@long_task_semaphore = long_task_semaphore || create_long_task_semaphore
				@socket_accept_semaphore = socket_accept_semaphore || create_socket_accept_semaphore
			end
			
			attr_reader :configuration, :long_task_semaphore, :socket_accept_semaphore
			
			def call(request)
				# Create LongTask instance for this request if enabled
				long_task = nil
				if @configuration.max_long_tasks > 0
					long_task = LongTask.new(
						request,
						long_task_semaphore: @long_task_semaphore,
						socket_accept_semaphore: @socket_accept_semaphore,
						start_delay: @configuration.start_delay
					)
					
					# Add long_task method to request for easy access
					request.define_singleton_method(:long_task) { long_task }
				end
				
				# Process the request
				response = super(request)
				
				# Wrap response body to ensure cleanup
				if long_task
					response.body = ResponseBodyWrapper.new(response.body, long_task)
				end
				
				return response
			ensure
				# Ensure long task is stopped even if exception occurs
				long_task&.stop(force: true)
			end
			
			# Get semaphore statistics
			def statistics
				{
					long_task: semaphore_stats(@long_task_semaphore),
					socket_accept: semaphore_stats(@socket_accept_semaphore)
				}
			end
			
			private
			
			def semaphore_stats(semaphore)
				{
					available: semaphore.available_count,
					acquired: semaphore.acquired_count,
					limit: semaphore.limit,
					waiting: semaphore.waiting_count,
					reacquire: semaphore.reacquire_count,
					limited: semaphore.limited?
				}
			end
			
			def create_long_task_semaphore
				if @configuration.max_long_tasks > 0
					Semaphore.new(@configuration.max_long_tasks)
				else
					# Null semaphore that always succeeds
					NullSemaphore.new
				end
			end
			
			def create_socket_accept_semaphore
				if @configuration.max_accepts > 0
					Semaphore.new(@configuration.max_accepts)
				else
					# Null semaphore that always succeeds
					NullSemaphore.new
				end
			end
			
			# Null semaphore for when limits are disabled
			class NullSemaphore
				def available_count; Float::INFINITY; end
				def acquired_count; 0; end
				def limit; Float::INFINITY; end
				def waiting_count; 0; end
				def reacquire_count; 0; end
				def limited?; false; end
				
				# For consistency with Statistics module interface
				def queue; self; end
				def size; Float::INFINITY; end
			end
			
			# Null token for when limits are disabled
			class NullToken
				def release; end
				def released?; false; end
			end
			
			# Wraps response body to ensure long task cleanup when response finishes
			class ResponseBodyWrapper
				def initialize(body, long_task)
					@body = body
					@long_task = long_task
				end
				
				# Delegate most methods to wrapped body
				def method_missing(method, *args, &block)
					@body.send(method, *args, &block)
				end
				
				def respond_to_missing?(method, include_private = false)
					@body.respond_to?(method, include_private) || super
				end
				
				# Ensure cleanup on close
				def close
					@body.close if @body.respond_to?(:close)
				ensure
					@long_task&.stop(force: true)
				end
				
				# Handle streaming by wrapping each call
				def each
					return to_enum(:each) unless block_given?
					
					begin
						@body.each do |chunk|
							yield chunk
						end
					ensure
						@long_task&.stop(force: true)
					end
				end
				
				# Forward common body methods
				%i[empty? read].each do |method|
					define_method(method) do |*args, &block|
						@body.send(method, *args, &block)
					end
				end
			end
		end
	end
end
