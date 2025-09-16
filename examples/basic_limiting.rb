#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "../lib/falcon/limiter"

# Create a semaphore with a limit of 3 concurrent resources
semaphore = Falcon::Limiter::Semaphore.new(3)

puts "Available resources: #{semaphore.available_count}"
puts "Acquired resources: #{semaphore.acquired_count}"

# Simulate acquiring and releasing resources
tasks = []

10.times do |i|
	tasks << Thread.new do
		puts "Task #{i}: Waiting for resource..."
		
		# Acquire a resource token
		token = semaphore.acquire
		
		puts "Task #{i}: Acquired resource (#{semaphore.available_count} remaining)"
		
		# Simulate work
		sleep(rand * 2)
		
		# Release the resource
		token.release
		
		puts "Task #{i}: Released resource (#{semaphore.available_count} available)"
	end
end

# Wait for all tasks to complete
tasks.each(&:join)

puts "Final state - Available: #{semaphore.available_count}, Acquired: #{semaphore.acquired_count}"
