#!/usr/bin/env falcon-host
# frozen_string_literal: true

require "falcon/limiter"

service "limiter-example.localhost" do
	include Falcon::Environment::Limiter
	
	# Configure limiter settings
	limiter_configuration.max_long_tasks = 4
	limiter_configuration.max_accepts = 2
	limiter_configuration.start_delay = 0.1  # Shorter delay for demo
	
	scheme "http"
	url "http://localhost:9292"
	
	rack_app do
		run lambda { |env|
			# Access HTTP request directly
			request = env["protocol.http.request"]
			path = env["PATH_INFO"]
			
			case path
			when "/fast"
				# Fast request - no long task needed
				[200, {"content-type" => "text/plain"}, ["Fast response: #{Time.now}"]]
				
			when "/slow"
				# Slow I/O bound request - use long task
				request.long_task&.start
				
				# Simulate I/O operation
				sleep(2.0)
				
				# Optional manual stop (auto-cleanup on response end)
				request.long_task&.stop
				
				[200, {"content-type" => "text/plain"}, ["Slow response: #{Time.now}"]]
				
			when "/cpu"
				# CPU bound request - don't use long task to prevent GVL contention
				# Simulate CPU work
				result = (1..1000000).sum
				
				[200, {"content-type" => "text/plain"}, ["CPU result: #{result}"]]
				
			when "/stats"
				# Show limiter statistics
				stats = statistics
				[200, {"content-type" => "application/json"}, [stats.to_json]]
				
			else
				[404, {"content-type" => "text/plain"}, ["Not found"]]
			end
		}
	end
end
