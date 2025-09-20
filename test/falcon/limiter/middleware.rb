# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "falcon/limiter"
require "sus/fixtures/async"
require "sus/fixtures/async/http"
require "protocol/http"
require "protocol/http/body/completable"

describe Falcon::Limiter::Middleware do
	include Sus::Fixtures::Async::SchedulerContext
	
	let(:connection_limiter) {Falcon::Limiter::Semaphore.new(2)}
	
	let(:mock_app) do
		lambda do |request|
			# Simulate some request processing
			Protocol::HTTP::Response[200, {}, ["Hello, World!"]]
		end
	end
	
	let(:middleware) do
		Falcon::Limiter::Middleware.new(
			mock_app,
			connection_limiter: connection_limiter,
			maximum_long_tasks: 3,
			start_delay: 0.01
		)
	end
	
	# Mock HTTP request with connection chain
	let(:mock_request) do
		token = Async::Limiter::Token.acquire(connection_limiter)
		
		io = Object.new
		io.define_singleton_method(:token) {token}
		
		stream = Object.new  
		stream.define_singleton_method(:io) {io}
		
		connection = Object.new
		connection.define_singleton_method(:stream) {stream}
		connection.define_singleton_method(:persistent=) {|value| @persistent = value}
		connection.define_singleton_method(:persistent) {@persistent}
		
		request = Protocol::HTTP::Request.new
		request.define_singleton_method(:connection) {connection}
		request
	end
	
	it "processes requests with long task support" do
		response = middleware.call(mock_request)
		
		expect(response).to be_a(Protocol::HTTP::Response)
		expect(response.status).to be == 200
		
		# Long task should have been processed (response returned)
		expect(response.body).not.to be == nil
	end
	
	it "handles requests without long task support" do
		# Middleware with no long tasks
		no_long_task_middleware = Falcon::Limiter::Middleware.new(
			mock_app,
			connection_limiter: connection_limiter,
			maximum_long_tasks: 0  # Disabled
		)
		
		response = no_long_task_middleware.call(mock_request)
		
		expect(response).to be_a(Protocol::HTTP::Response)
		# No long task should mean response is processed normally
		expect(response.body).not.to be == nil
	end
	
	it "handles long task lifecycle properly" do
		# Test that long tasks are properly managed during request processing
		response = middleware.call(mock_request)
		
		expect(response).to be_a(Protocol::HTTP::Response)
		# Long task should have been processed, response body should exist
		expect(response.body).not.to be == nil
	end
	
	it "handles different response body types gracefully" do
		# Test that the middleware handles various body types without issues
		string_body = "simple string body"
		response = middleware.call(mock_request)
		
		expect(response).to be_a(Protocol::HTTP::Response)
		# Should not crash with different body types
		expect {response.body.close if response.body.respond_to?(:close)}.not.to raise_exception
	end
	
	it "handles middleware exceptions" do
		failing_app = lambda {|request| raise "Middleware error"}
		
		failing_middleware = Falcon::Limiter::Middleware.new(
			failing_app,
			connection_limiter: connection_limiter,
			maximum_long_tasks: 2
		)
		
		# Should clean up even when exception occurs
		expect do
			failing_middleware.call(mock_request)
		end.to raise_exception(RuntimeError)
		
		# Exception should be propagated (no specific cleanup check needed with 'with' pattern)
	end
	
	it "wraps response body when long task is started by application" do
		# Create an app that starts a long task (like the example shows)
		app_that_starts_long_task = lambda {|request|
			# Application calls start on the long task (like in the example)
			Falcon::Limiter::LongTask.current&.start
			
			# Simulate some work that would require cleanup
			Protocol::HTTP::Response[200, {}, ["slow response"]]
		}
		
		test_middleware = Falcon::Limiter::Middleware.new(
			app_that_starts_long_task,
			connection_limiter: connection_limiter,
			maximum_long_tasks: 4,
			start_delay: 0  # No delay for immediate start
		)
		
		response = test_middleware.call(mock_request)
		expect(response).to be_a(Protocol::HTTP::Response)
		expect(response.body).not.to be == nil
		
		# Close the response body to trigger the completable callback (line 37)
		response.body.close
		
		# The long task should have been started and the cleanup code should execute
	end
	
	with "integration tests" do
		include Sus::Fixtures::Async::HTTP::ServerContext
		
		# Create an app that uses the Falcon::Limiter middleware
		let(:app) do
			# Base application that simulates different workloads
			base_app = Protocol::HTTP::Middleware.for do |request|
				case request.path
				when "/fast"
					# Fast response - no long task needed
					Protocol::HTTP::Response[200, {"content-type" => "text/plain"}, ["Fast response"]]
				when "/slow"
					# Slow response - should use long task management
					if current_task = Falcon::Limiter::LongTask.current
						current_task.start # Start long task for I/O operation
					end
					
					# Simulate I/O operation
					sleep(0.1) 
					
					if current_task = Falcon::Limiter::LongTask.current
						current_task.stop # Stop long task after I/O
					end
					
					Protocol::HTTP::Response[200, {"content-type" => "text/plain"}, ["Slow response completed"]]
				when "/error"
					# Test error handling with long tasks:
					if current_task = Falcon::Limiter::LongTask.current
						current_task.start
					end
					
					raise "Simulated error"
				else
					Protocol::HTTP::Response[404, {}, ["Not Found"]]
				end
			end
			
			# Wrap with Falcon::Limiter middleware
			Falcon::Limiter::Middleware.new(
				base_app,
				connection_limiter: connection_limiter,
				maximum_long_tasks: 2,
				start_delay: 0.05
			)
		end
		
		it "handles fast requests without long tasks" do
			response = client.get("/fast")
			
			expect(response.status).to be == 200
			expect(response.read).to be == "Fast response"
		end
		
		it "handles slow requests with long task management" do
			response = client.get("/slow")
			
			expect(response.status).to be == 200
			expect(response.read).to be == "Slow response completed"
		end
		
		it "handles multiple concurrent requests" do
			# Start multiple slow requests concurrently
			responses = 3.times.map do
				Async do
					client.get("/slow")
				end
			end.map(&:wait)
			
			# All requests should succeed
			responses.each do |response|
				expect(response.status).to be == 200
				expect(response.read).to be == "Slow response completed"
			end
		end
		
		it "handles errors during long task processing" do
			expect do
				client.get("/error")
			end.to raise_exception(EOFError)
			sleep 1
		end
		
		it "returns 404 for unknown paths" do
			response = client.get("/unknown")
			expect(response.status).to be == 404
		ensure
			response.close
		end
		
		it "supports different HTTP methods" do
			# Test that middleware works with various HTTP methods
			post_response = client.post("/fast", {}, ["test data"])
			expect(post_response.status).to be == 200
			
			put_response = client.put("/fast", {}, ["updated data"])
			expect(put_response.status).to be == 200
		ensure
			post_response.close
			put_response.close
		end
		
		it "maintains proper response headers" do
			response = client.get("/fast")
			
			expect(response.status).to be == 200
			expect(response.headers["content-type"]).to be == "text/plain"
		ensure
			response.close
		end
	end
	
	with "#statistics" do
		it "provides statistics" do
			statistics = middleware.statistics
			
			expect(statistics).to be_a(Hash)
			expect(statistics[:long_task_limiter]).to be_a(Hash)
			expect(statistics[:connection_limiter]).to be_a(Hash)
		end
	end
end
