#!/usr/bin/env falcon --verbose serve -c
# frozen_string_literal: true

require "falcon/limiter"

# Configure limiter globally
Falcon::Limiter.configure do |config|
	config.max_long_tasks = 4
	config.max_accepts = 2
	config.start_delay = 0.1
end

# Basic Rack app demonstrating limiter usage
run lambda { |env|
	request = env["protocol.http.request"]
	path = env["PATH_INFO"]
	
	case path
	when "/long-io"
		# Start long task for I/O bound work
		request.long_task&.start
		
		# Simulate database query or external API call
		sleep(1.5)
		
		[200, {"content-type" => "text/plain"}, ["Long I/O operation completed at #{Time.now}"]]
		
	when "/short"
		# Short operation - long task overhead avoided by delay
		sleep(0.05)
		[200, {"content-type" => "text/plain"}, ["Short operation at #{Time.now}"]]
		
	when "/token-info"
		# Show connection token information
		token_info = "No connection token"
		
		if request.respond_to?(:connection)
			io = request.connection.stream.io
			if io.respond_to?(:token)
				token = io.token
				token_info = "Token: #{token.inspect}, Released: #{token.released?}"
			end
		end
		
		[200, {"content-type" => "text/plain"}, [token_info]]
		
	else
		[200, {"content-type" => "text/plain"}, ["Hello from Falcon Limiter!"]]
	end
}
