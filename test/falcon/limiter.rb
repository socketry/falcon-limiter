# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "sus/fixtures/async"
require "falcon/limiter"

describe Falcon::Limiter do
	include Sus::Fixtures::Async::SchedulerContext
	
	# The Falcon::Limiter module now just provides namespace - 
	# actual functionality comes through the Environment pattern
	
	describe Falcon::Limiter::LongTask do
		include Sus::Fixtures::Async::SchedulerContext
		
		it "initializes correctly" do
			# Mock request object
			request = Object.new
			
			# Create limiters
			long_task_limiter = Falcon::Limiter::Semaphore.new(2)
			connection_limiter = Falcon::Limiter::Semaphore.new(1)
			
			long_task = Falcon::Limiter::LongTask.for(request, long_task_limiter, start_delay: 0)
			
			expect(long_task).not.to be(:started?)
		end
		
		it "can stop without starting" do
			request = Object.new
			
			long_task_limiter = Falcon::Limiter::Semaphore.new(2)
			connection_limiter = Falcon::Limiter::Semaphore.new(1)
			
			long_task = Falcon::Limiter::LongTask.for(request, long_task_limiter, start_delay: 0.01)
			
			# Should be able to stop without starting
			long_task.stop
			expect(long_task).not.to be(:started?)
		end
	end
	
	describe Falcon::Limiter::Middleware do
		include Sus::Fixtures::Async::SchedulerContext
		
		it "creates middleware correctly" do
			app = ->(_request) {[200, {}, ["OK"]]}
			semaphore = Falcon::Limiter::Semaphore.new(2)
			
			middleware = Falcon::Limiter::Middleware.new(app, connection_limiter: semaphore, maximum_long_tasks: 8)
			expect(middleware.connection_limiter).to be == semaphore
			expect(middleware.long_task_limiter).to be_a(Async::Limiter::Queued)
			expect(middleware.maximum_long_tasks).to be == 8
		end
		
		it "provides statistics" do
			app = ->(_request) {[200, {}, ["OK"]]}
			semaphore = Falcon::Limiter::Semaphore.new(3)
			
			middleware = Falcon::Limiter::Middleware.new(app, connection_limiter: semaphore, maximum_long_tasks: 5)
			stats = middleware.statistics
			
			expect(stats).to be_a(Hash)
			if stats[:long_task]
				expect(stats[:long_task]).to be_a(Hash)
			end
			
			if stats[:socket_accept]
				expect(stats[:socket_accept]).to be_a(Hash)
			end
		end
	end
end
