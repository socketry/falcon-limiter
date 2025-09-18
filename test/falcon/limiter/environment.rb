# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "falcon/limiter"
require "async/service"
require "io/endpoint"
require "sus/fixtures/async"

module MockServer
	def middleware
		Protocol::HTTP::Middleware::HelloWorld
	end
	
	def endpoint
		# Use a real IO::Endpoint::Generic for proper behavior
		IO::Endpoint::Generic.new(
			scheme: "http",
			hostname: "localhost", 
			port: 8080
		)
	end
end

describe Falcon::Limiter::Environment do
	include Sus::Fixtures::Async::SchedulerContext
	
	let(:environment) {Async::Service::Environment.build(MockServer, subject)}
	let(:evaluator) {environment.evaluator}
	
	it "provides default configuration values" do
		expect(evaluator.limiter_maximum_long_tasks).to be == 4
		expect(evaluator.limiter_maximum_connections).to be == 1
		expect(evaluator.limiter_start_delay).to be == 0.1
	end
	
	it "creates limiter from configuration" do
		limiter = evaluator.connection_limiter
		
		expect(limiter).to be_a(Async::Limiter::Queued)
		expect(limiter.queue.size).to be == 1 # Based on limiter_maximum_connections
	end
	
	it "creates unified semaphore for coordination (memoized)" do
		semaphore1 = evaluator.connection_limiter
		semaphore2 = evaluator.connection_limiter
		
		expect(semaphore1).to be_a(Async::Limiter::Queued)
		# Should return the same memoized instance
		expect(semaphore2).to be_equal(semaphore1)
	end
	
	it "wraps middleware correctly" do
		middleware = evaluator.middleware
		
		expect(middleware).to be_a(Falcon::Limiter::Middleware)
		expect(middleware.maximum_long_tasks).to be == 4
		expect(middleware.start_delay).to be == 0.1
		expect(middleware.connection_limiter).to be_a(Async::Limiter::Queued)
	end
	
	it "wraps endpoint correctly" do
		endpoint = evaluator.endpoint
		
		expect(endpoint).to be_a(IO::Endpoint::Generic)
		# The wrapper should be stored as an option
		expect(endpoint.options[:wrapper]).to be_a(Falcon::Limiter::Wrapper)
		expect(endpoint.options[:wrapper].limiter).to be_a(Async::Limiter::Queued)
	end
	
	it "handles disabled long task configuration" do
		# Create a module with long tasks disabled
		disabled_module = Module.new do
			include MockServer
			include Falcon::Limiter::Environment
			
			def limiter_maximum_long_tasks
				0  # Disabled
			end
		end
		
		disabled_eval = Async::Service::Environment.build(disabled_module).evaluator
		base_middleware = Protocol::HTTP::Middleware::HelloWorld
		
		# This should trigger the missing coverage line 69 (fallback case)
		result = disabled_eval.limiter_middleware(base_middleware)
		
		# Should return the original middleware unwrapped
		expect(result).to be == base_middleware
	end
end
