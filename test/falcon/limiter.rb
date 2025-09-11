# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "sus/fixtures/async"
require "falcon/limiter"

describe Falcon::Limiter do
	include Sus::Fixtures::Async
	
	it "has default configuration" do
		config = Falcon::Limiter.configuration
		
		expect(config.max_long_tasks).to be == 4
		expect(config.max_accepts).to be == 1
		expect(config.start_delay).to be == 0.6
	end
	
	it "can configure globally" do
		original_default = Falcon::Limiter::Configuration.default
		
		Falcon::Limiter::Configuration.reset_default!
		
		Falcon::Limiter.configure do |config|
			config.max_long_tasks = 8
			config.max_accepts = 2
		end
		
		expect(Falcon::Limiter.configuration.max_long_tasks).to be == 8
		expect(Falcon::Limiter.configuration.max_accepts).to be == 2
		
		# Restore original for other tests
		Falcon::Limiter::Configuration.instance_variable_set(:@default, original_default)
	end
	
	describe Falcon::Limiter::Semaphore do
		it "can acquire and release tokens" do
			semaphore = Falcon::Limiter::Semaphore.new(2)
			
			expect(semaphore.available_count).to be == 2
			expect(semaphore.waiting_count).to be == 0
			
			token1 = semaphore.try_acquire
			expect(token1).not.to be_nil
			expect(semaphore.available_count).to be == 1
			
			token2 = semaphore.try_acquire
			expect(token2).not.to be_nil
			expect(semaphore.available_count).to be == 0
			
			# Should fail when limit reached
			token3 = semaphore.try_acquire
			expect(token3).to be_nil
			
			# Release and try again
			token1.release
			expect(semaphore.available_count).to be == 1
			expect(token1.released?).to be == true
			
			token3 = semaphore.try_acquire
			expect(token3).not.to be_nil
		end
		
		it "handles priority-based waiting" do
			semaphore = Falcon::Limiter::Semaphore.new(1)
			
			# Acquire the only token
			token = semaphore.try_acquire
			expect(token).not.to be_nil
			
			high_priority_acquired = false
			low_priority_acquired = false
			results = []
			
			# Start low priority thread first
			low_priority_thread = Thread.new do
				token = semaphore.acquire(priority: 1)
				low_priority_acquired = true
				results << :low_priority
				sleep(0.01)
				token.release
			end
			
			# Give it time to start waiting
			sleep(0.02)
			
			# Start high priority thread
			high_priority_thread = Thread.new do
				token = semaphore.acquire(priority: 10)
				high_priority_acquired = true
				results << :high_priority
				sleep(0.01)
				token.release
			end
			
			# Give both threads time to be waiting
			sleep(0.02)
			
			# Release original token - high priority should be resumed first
			token.release
			
			# Wait for threads to complete
			high_priority_thread.join
			low_priority_thread.join
			
			# Both should have acquired
			expect(high_priority_acquired).to be == true
			expect(low_priority_acquired).to be == true
			
			# High priority should have gone first
			expect(results.first).to be == :high_priority
		end
		
		it "handles concurrent access correctly" do
			semaphore = Falcon::Limiter::Semaphore.new(2)
			acquired_tokens = []
			threads = []
			mutex = Mutex.new
			
			# Start multiple threads trying to acquire tokens
			5.times do |i|
				threads << Thread.new do
					token = semaphore.acquire
					mutex.synchronize { acquired_tokens << i }
					sleep(0.01)  # Hold token briefly
					token.release
				end
			end
			
			# Wait for all threads to complete
			threads.each(&:join)
			
			# Should have processed all requests
			expect(acquired_tokens.size).to be == 5
		end
		
		it "supports reacquire for long task pattern" do
			semaphore = Falcon::Limiter::Semaphore.new(1)
			
			token = semaphore.try_acquire
			expect(token).not.to be_nil
			
			# Release token
			token.release
			expect(token.released?).to be == true
			
			# Reacquire should work with async-limiter API
			new_token = token.acquire(priority: 1000)
			expect(new_token).not.to be_nil
			expect(token.released?).to be == false
		end
	end
	
	describe Falcon::Limiter::LongTask do
		it "initializes correctly" do
			# Mock request object
			request = Object.new
			
			# Create semaphores
			long_task_semaphore = Falcon::Limiter::Semaphore.new(2)
			socket_accept_semaphore = Falcon::Limiter::Semaphore.new(1)
			
			long_task = Falcon::Limiter::LongTask.new(
				request,
				long_task_semaphore: long_task_semaphore,
				socket_accept_semaphore: socket_accept_semaphore,
				start_delay: 0
			)
			
			expect(long_task.started?).to be == false
			expect(long_task.request).to be == request
		end
		
		it "can stop without starting" do
			request = Object.new
			
			long_task_semaphore = Falcon::Limiter::Semaphore.new(2)
			socket_accept_semaphore = Falcon::Limiter::Semaphore.new(1)
			
			long_task = Falcon::Limiter::LongTask.new(
				request,
				long_task_semaphore: long_task_semaphore,
				socket_accept_semaphore: socket_accept_semaphore,
				start_delay: 0.01
			)
			
			# Should be able to stop without starting
			long_task.stop
			expect(long_task.started?).to be == false
		end
	end
	
	describe Falcon::Limiter::Middleware do
		it "creates middleware correctly" do
			app = lambda { |request| [200, {}, ["OK"]] }
			middleware = Falcon::Limiter::Middleware.new(app)
			
			expect(middleware.configuration).to be_a(Falcon::Limiter::Configuration)
			expect(middleware.long_task_semaphore).to be_a(Falcon::Limiter::Semaphore)
			expect(middleware.socket_accept_semaphore).to be_a(Falcon::Limiter::Semaphore)
		end
		
		it "provides statistics" do
			app = lambda { |request| [200, {}, ["OK"]] }
			middleware = Falcon::Limiter::Middleware.new(app)
			
			stats = middleware.statistics
			expect(stats).to be_a(Hash)
			expect(stats[:long_task]).to be_a(Hash)
			expect(stats[:socket_accept]).to be_a(Hash)
		end
	end
end
