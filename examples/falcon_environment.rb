#!/usr/bin/env falcon-host
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "../lib/falcon/limiter"

service "limiter-example.localhost" do
	include Falcon::Limiter::Environment
	
	# Configure concurrency limits by overriding methods
	def limiter_max_long_tasks = 4
	def limiter_max_accepts = 2
	def limiter_start_delay = 0.5
	
	scheme "http"
	url "http://localhost:9292"
	
	rack_app do
		run lambda {|env|
			request = env["protocol.http.request"]
			
			case env["PATH_INFO"]
			when "/fast"
				# Fast response - no need for long task
				[200, { "Content-Type" => "text/plain" }, ["Fast response"]]
				
			when "/slow"
				# Slow response - use long task management
				Falcon::Limiter::LongTask.current&.start
				
				# Simulate I/O operation (database query, API call, etc.)
				sleep(2)
				
				Falcon::Limiter::LongTask.current&.stop
				
				[200, { "Content-Type" => "text/plain" }, ["Slow response completed"]]
				
			when "/stats"
				# Show limiter statistics
				stats = if respond_to?(:statistics)
					statistics
				else
					{ message: "Statistics not available" }
				end
				
				[200, { "Content-Type" => "application/json" }, [stats.to_json]]
				
			else
				[404, { "Content-Type" => "text/plain" }, ["Not found"]]
			end
		}
	end
end
