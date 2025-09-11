# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "limiter/configuration"
require_relative "limiter/semaphore"
require_relative "limiter/wrapper"
require_relative "limiter/long_task"
require_relative "limiter/middleware"

module Falcon
	# Limiter provides concurrency management for Falcon applications.
	# It handles the distinction between I/O bound vs CPU bound workloads,
	# allowing better resource utilization and server responsiveness.
	module Limiter
		# Global configuration access
		def self.configuration
			Configuration.default
		end
		
		# Configure the limiter system
		def self.configure
			yield configuration
		end
		
		# Create shared semaphores (thread-safe singletons)
		def self.socket_accept_semaphore(limit: configuration.max_accepts)
			@socket_accept_semaphore ||= {}
			@socket_accept_semaphore[limit] ||= limit > 0 ? Semaphore.new(limit) : nil
		end
		
		def self.long_task_semaphore(limit: configuration.max_long_tasks)
			@long_task_semaphore ||= {}
			@long_task_semaphore[limit] ||= limit > 0 ? Semaphore.new(limit) : nil
		end
		
		# Helper to create a limited endpoint
		def self.wrap_endpoint(endpoint, accept_limit: configuration.max_accepts)
			semaphore = socket_accept_semaphore(limit: accept_limit)
			Wrapper.new(endpoint, semaphore: semaphore)
		end
		
		# Helper to create middleware with custom configuration
		def self.middleware(app, **options)
			config = Configuration.new
			options.each { |key, value| config.send("#{key}=", value) }
			
			Middleware.new(
				app, 
				configuration: config,
				long_task_semaphore: long_task_semaphore(limit: config.max_long_tasks),
				socket_accept_semaphore: socket_accept_semaphore(limit: config.max_accepts)
			)
		end
	end
end
