#!/usr/bin/env falcon-host
# frozen_string_literal: true

# Example of using falcon-limiter with Falcon environment

require "falcon-limiter"

service "limiter-example.localhost" do
  include Falcon::Environment::Limiter
  
  # Configure concurrency limits
  limiter_configuration.max_long_tasks = 4
  limiter_configuration.max_accepts = 2
  limiter_configuration.start_delay = 0.5
  
  scheme "http"
  url "http://localhost:9292"
  
  rack_app do
    run lambda { |env|
      request = env["protocol.http.request"]
      
      case env["PATH_INFO"]
      when "/fast"
        # Fast response - no need for long task
        [200, {"Content-Type" => "text/plain"}, ["Fast response"]]
      
      when "/slow"
        # Slow response - use long task management
        request.long_task&.start
        
        # Simulate I/O operation (database query, API call, etc.)
        sleep(2)
        
        request.long_task&.stop
        
        [200, {"Content-Type" => "text/plain"}, ["Slow response completed"]]
      
      when "/stats"
        # Show limiter statistics
        stats = if respond_to?(:statistics)
          statistics
        else
          { message: "Statistics not available" }
        end
        
        [200, {"Content-Type" => "application/json"}, [stats.to_json]]
      
      else
        [404, {"Content-Type" => "text/plain"}, ["Not found"]]
      end
    }
  end
end
