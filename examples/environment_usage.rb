#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "../lib/falcon/limiter"

# Example service module that includes the limiter environment
module MyService
	include Falcon::Limiter::Environment
	
	# Customize limiter configuration by overriding methods
	def limiter_maximum_long_tasks
		8  # Override default of 4
	end
	
	def limiter_maximum_accepts
		3  # Override default of 1
	end
	
	def limiter_start_delay
		0.8 # Override default of 0.1
	end
	
	# Mock middleware method
	def middleware
		proc {|_env| [200, {}, ["Base middleware"]]}
	end
	
	# Mock endpoint method
	def endpoint
		Object.new.tap do |endpoint|
			endpoint.define_singleton_method(:to_s) {"MockEndpoint"}
		end
	end
end

# Demonstrate the environment with proper async-service pattern
require "async/service"
environment = Async::Service::Environment.build(MyService)
service = environment.evaluator

puts "=== Falcon Limiter Environment Demo ==="
puts
puts "Configuration:"
options = service.limiter_semaphore_options
puts "  Max Long Tasks: #{options[:maximum_long_tasks]}"
puts "  Max Accepts: #{options[:maximum_accepts]}"
puts "  Start Delay: #{options[:start_delay]}s"
puts

puts "Semaphore:"
semaphore = service.limiter_semaphore
puts "  Limiter Semaphore: #{semaphore.available_count}/#{semaphore.limit} available"
puts "  Limited: #{semaphore.limited?}"
puts "  Waiting: #{semaphore.waiting_count}"
puts

puts "Middleware Integration:"
base_middleware = service.middleware
wrapped_middleware = service.limiter_middleware(base_middleware)
puts "  Base middleware: #{base_middleware.class}"
puts "  Wrapped middleware: #{wrapped_middleware.class}"
puts

puts "Endpoint Integration:"
endpoint = service.endpoint
puts "  Final Endpoint: #{endpoint.class}"

# Check if it's actually wrapped (only if it's a Wrapper)
if endpoint.respond_to?(:semaphore)
	puts "  Semaphore: #{endpoint.semaphore.class}"
	puts "  Same semaphore instance: #{endpoint.semaphore == service.limiter_semaphore}"
else
	puts "  Note: Endpoint is not wrapped (likely mock object)"
end
