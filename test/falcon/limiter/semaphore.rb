# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "falcon/limiter"
require "sus/fixtures/async"

describe Falcon::Limiter::Semaphore do
	include Sus::Fixtures::Async::SchedulerContext
	
	it "can acquire and release tokens" do
		limiter = Falcon::Limiter::Semaphore.new(2)
		
		expect(limiter.queue.size).to be == 2
		expect(limiter.queue.waiting).to be == 0
		
		token1 = Async::Limiter::Token.acquire(limiter, timeout: 0)
		expect(token1).not.to be_nil
		expect(limiter.queue.size).to be == 1
		
		token2 = Async::Limiter::Token.acquire(limiter, timeout: 0)
		expect(token2).not.to be_nil
		expect(limiter.queue.size).to be == 0
		
		# Should fail when limit reached
		token3 = Async::Limiter::Token.acquire(limiter, timeout: 0)
		expect(token3).to be_nil
		
		# Release and try again
		token1.release
		expect(limiter.queue.size).to be == 1
		expect(token1.released?).to be == true
		
		token3 = Async::Limiter::Token.acquire(limiter, timeout: 0)
		expect(token3).not.to be_nil
	end
	
	it "handles priority-based waiting" do
		limiter = Falcon::Limiter::Semaphore.new(1)
		
		# Acquire the only token
		token = Async::Limiter::Token.acquire(limiter, timeout: 0)
		expect(token).not.to be_nil
		
		high_priority_acquired = false
		low_priority_acquired = false
		results = []
		
		# Start low priority thread first
		low_priority_thread = Thread.new do
			token = Async::Limiter::Token.acquire(limiter, priority: 1)
			low_priority_acquired = true
			results << :low_priority
			sleep(0.01)
			token.release
		end
		
		# Give it time to start waiting
		sleep(0.02)
		
		# Start high priority thread
		high_priority_thread = Thread.new do
			token = Async::Limiter::Token.acquire(limiter, priority: 10)
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
		limiter = Falcon::Limiter::Semaphore.new(2)
		acquired_tokens = []
		threads = []
		mutex = Mutex.new
		
		# Start multiple threads trying to acquire tokens
		5.times do |i|
			threads << Thread.new do
				token = Async::Limiter::Token.acquire(limiter)
				mutex.synchronize {acquired_tokens << i}
				sleep(0.01) # Hold token briefly
				token.release
			end
		end
		
		# Wait for all threads to complete
		threads.each(&:join)
		
		# Should have processed all requests
		expect(acquired_tokens.size).to be == 5
	end
	
	it "supports reacquire for long task pattern" do
		limiter = Falcon::Limiter::Semaphore.new(1)
		
		token = Async::Limiter::Token.acquire(limiter, timeout: 0)
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
