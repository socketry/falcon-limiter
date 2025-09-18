# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "falcon/limiter"
require "sus/fixtures/async"
require "async/clock"

describe Falcon::Limiter::Wrapper do
	include Sus::Fixtures::Async::SchedulerContext
	
	let(:limiter) {Falcon::Limiter::Semaphore.new(2)}
	let(:wrapper) {Falcon::Limiter::Wrapper.new(limiter)}
	
	# Mock server that can simulate accept behavior
	let(:mock_server) do
		accept_count = 0
		should_block = false
		
		Object.new.tap do |server|
			server.define_singleton_method(:wait_readable) do
				# Simulate server becoming readable.
			end
			
			server.define_singleton_method(:accept_nonblock) do
				accept_count += 1
				
				if should_block
					# Create a proper IO::WaitReadable exception.
					error = Errno::EAGAIN.new("Resource temporarily unavailable")
					error.extend(IO::WaitReadable)
					raise error
				end
				
				# Return mock socket that behaves like a real socket.
				socket = Class.new do
					def close
						# Simulate real socket close behavior.
					end
				end.new
				
				[socket, "127.0.0.1"]
			end
			
			# Helper methods for test control
			server.define_singleton_method(:set_blocking) {|block| should_block = block}
			server.define_singleton_method(:accept_count) {accept_count}
		end
	end
	
	it "initializes with limiter" do
		expect(wrapper.limiter).to be == limiter
	end
	
	it "waits for inbound connection and acquires semaphore" do
		token = wrapper.wait_for_inbound_connection(mock_server)
		
		expect(token).to be_a(Async::Limiter::Token)
		expect(token).not.to be(:released?)
		expect(limiter.queue.size).to be == 1  # One token remaining
		
		# Clean up
		token.release
	end
	
	it "blocks when semaphore is at capacity" do
		# Fill up the limiter
		token1 = Async::Limiter::Token.acquire(limiter)
		token2 = Async::Limiter::Token.acquire(limiter)
		
		expect(limiter.queue.size).to be == 0  # At capacity (no tokens available)
		
		# This should not complete immediately
		start_time = Time.now
		
		# Release one token after a short delay to unblock
		Async do |task|
			task.sleep(0.1)
			token1.release
		end
		
		# This should block until token1 is released
		token = wrapper.wait_for_inbound_connection(mock_server)
		
		elapsed = Time.now - start_time
		expect(elapsed).to be >= 0.09  # Should have waited
		expect(token).to be_a(Async::Limiter::Token)
		
		token.release
		
		# Clean up
		token2.release
	end
	
	it "handles socket_accept_nonblock successfully" do
		token = Async::Limiter::Token.acquire(limiter)
		
		result = wrapper.socket_accept_nonblock(mock_server, token)
		
		expect(result).not.to be_nil
		expect(result).to be_a(Array)  # [socket, address]
		# Token should not be released on success
		expect(token).not.to be(:released?)
		
		# Clean up
		token.release
	end
	
	it "handles socket_accept_nonblock with WaitReadable" do
		token = Async::Limiter::Token.acquire(limiter)
		mock_server.set_blocking(true)
		
		socket = wrapper.socket_accept_nonblock(mock_server, token)
		
		expect(socket).to be_nil
		# Token should be released when no socket returned
		expect(token).to be(:released?)
	end
	
	it "accepts connections with full coordination" do
		Async do
			socket, address = wrapper.socket_accept(mock_server)
			
			expect(socket).not.to be_nil
			expect(socket).to respond_to(:token)
			expect(socket.token).to be_a(Async::Limiter::Token)
			expect(socket.token).not.to be(:released?)
			
			# Keep reference to token before closing
			token = socket.token
			
			# Verify socket close releases token
			expect(limiter.queue.size).to be == 1  # One token remaining
			socket.close
			expect(token).to be(:released?)
			expect(limiter.queue.size).to be == 2  # All tokens returned
		end
	end
	
	it "handles concurrent socket accepts" do
		results = []
		
		# Start multiple concurrent accept operations
		tasks = 3.times.map do |i|
			Async do |task|
				socket, address = wrapper.socket_accept(mock_server)
				results << { socket: socket, task_id: i }
				
				# Hold the connection briefly
				task.sleep(0.1)
				socket.close
			end
		end
		
		tasks.each(&:wait)
		
		expect(results.length).to be == 3
		expect(results.all? {|r| r[:socket]}).to be == true
		expect(limiter.queue.size).to be == 2  # All tokens returned
	end
	
	it "respects semaphore limits during burst" do
		# Fill up limiter capacity
		token1 = Async::Limiter::Token.acquire(limiter)
		token2 = Async::Limiter::Token.acquire(limiter)
		
		results = []
		completed = 0
		
		# Start 3 accept tasks (should only 1 can run initially due to capacity)
		tasks = 3.times.map do |i|
			Async do |task|
				start_time = Time.now
				socket, address = wrapper.socket_accept(mock_server)
				
				results << { 
																				task_id: i, 
																				socket: socket,
																				wait_time: Time.now - start_time
																}
				
				completed += 1
				socket.close
			end
		end
		
		# Release tokens gradually to allow tasks to proceed
		sleep(0.05)
		token1.release  # Allow 1 task to proceed
		
		sleep(0.05)
		token2.release  # Allow 2nd task to proceed
		
		tasks.each(&:wait)
		
		expect(results.length).to be == 3
		expect(completed).to be == 3
		expect(limiter.queue.size).to be == 2  # All tokens returned
		
		# At least some tasks should have waited
		wait_times = results.map {|r| r[:wait_time]}
		expect(wait_times.any? {|t| t > 0.04}).to be == true
	end
	
	it "properly releases tokens on connection errors" do
		original_count = limiter.queue.size
		
		# Mock server that always throws IO::WaitReadable
		error_server = Object.new
		error_server.define_singleton_method(:wait_readable) {}
		error_server.define_singleton_method(:accept_nonblock) do
			error = Errno::EAGAIN.new("Resource temporarily unavailable")
			error.extend(IO::WaitReadable)
			raise error
		end
		
		# Try to accept - should get token, fail, and release it
		token = wrapper.wait_for_inbound_connection(mock_server)
		result = wrapper.socket_accept_nonblock(error_server, token)
		
		expect(result).to be_nil
		expect(token).to be(:released?)
		expect(limiter.queue.size).to be == original_count  # Token returned
	end
end
