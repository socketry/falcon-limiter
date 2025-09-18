# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "falcon/limiter"
require "sus/fixtures/async"

describe Falcon::Limiter::LongTask do
	include Sus::Fixtures::Async::SchedulerContext
	
	let(:long_task_limiter) {Falcon::Limiter::Semaphore.new(2)}
	let(:connection_limiter) {Falcon::Limiter::Semaphore.new(1)}
	
	# Mock request with connection and stream
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
		
		request = Object.new
		request.define_singleton_method(:connection) {connection}
		request
	end
	
	it "initializes correctly" do
		long_task = Falcon::Limiter::LongTask.new(mock_request, long_task_limiter, nil, start_delay: 0.1)
		
		expect(long_task).not.to be(:started?)
	end
	
	it "can start and stop long task immediately" do
		long_task = Falcon::Limiter::LongTask.for(mock_request, long_task_limiter, start_delay: 0)
		
		expect(long_task).not.to be(:started?)
		
		# Start immediately (no delay)
		long_task.start(delay: 0)
		expect(long_task).to be(:started?)
		
		# Stop the long task
		long_task.stop
		expect(long_task).not.to be(:started?)
	end
	
	it "can start with delay" do
		long_task = Falcon::Limiter::LongTask.for(mock_request, long_task_limiter, start_delay: 0.01)
		
		# Start with delay
		long_task.start(delay: 0.01)
		expect(long_task).not.to be(:acquired?)  # Not started yet due to delay
		
		# Wait for delay to complete
		sleep(0.02)
		expect(long_task).to be(:acquired?)
		
		# Stop the long task
		long_task.stop
		expect(long_task).not.to be(:acquired?)
	end
	
	it "can stop before delayed start completes" do
		long_task = Falcon::Limiter::LongTask.for(mock_request, long_task_limiter, start_delay: 0.1)
		
		# Start with delay
		long_task.start(delay: 0.1)
		expect(long_task).not.to be(:acquired?)
		
		# Stop before delay completes
		long_task.stop
		expect(long_task).not.to be(:acquired?)
	end
	
	it "can force stop" do
		long_task = Falcon::Limiter::LongTask.for(mock_request, long_task_limiter, start_delay: 0)
		
		# Start and then force stop
		long_task.start(delay: 0)
		expect(long_task).to be(:started?)
		
		long_task.stop(force: true)
		expect(long_task).not.to be(:started?)
	end
	
	it "handles connection going away gracefully" do
		# Mock request without proper connection chain
		broken_request = Object.new
		
		long_task = Falcon::Limiter::LongTask.for(broken_request, long_task_limiter, start_delay: 0)
		
		# Should handle missing connection gracefully (no exception raised)
		expect do
			long_task.start(delay: 0) 
		end.not.to raise_exception
		
		# Long task should still work even without connection token
		expect(long_task).to be(:started?)
	end
	
	it "handles connection without persistent flag" do
		# Mock request without persistent support
		token = Async::Limiter::Token.acquire(connection_limiter)
		
		io = Object.new
		io.define_singleton_method(:token) {token}
		
		stream = Object.new  
		stream.define_singleton_method(:io) {io}
		
		connection = Object.new
		connection.define_singleton_method(:stream) {stream}
		# No persistent= method defined
		
		request = Object.new
		request.define_singleton_method(:connection) {connection}
		
		long_task = Falcon::Limiter::LongTask.for(request, long_task_limiter, start_delay: 0)
		
		# Should not crash when persistent flag is not supported
		expect do
			long_task.start(delay: 0)
		end.not.to raise_exception
	end
	
	it "makes connection non-persistent when long task is acquired" do
		# Mock request with a connection that supports persistence
		token = Async::Limiter::Token.acquire(connection_limiter)
		
		io = Object.new
		io.define_singleton_method(:token) {token}
		
		stream = Object.new  
		stream.define_singleton_method(:io) {io}
		
		persistent_connection = Object.new
		persistent_connection.define_singleton_method(:stream) {stream}
		persistent_connection.define_singleton_method(:persistent) {@persistent}
		persistent_connection.define_singleton_method(:persistent=) {|value| @persistent = value}
		
		# Set initial state to persistent
		persistent_connection.persistent = true
		expect(persistent_connection.persistent).to be == true
		
		request = Object.new
		request.define_singleton_method(:connection) {persistent_connection}
		
		long_task = Falcon::Limiter::LongTask.for(request, long_task_limiter, start_delay: 0)
		
		# Start the long task which should acquire the token and make connection non-persistent
		long_task.start(delay: 0)
		
		# Verify the connection is now non-persistent
		expect(persistent_connection.persistent).to be == false
		expect(long_task).to be(:started?)
		
		# Clean up
		long_task.stop(force: true)
		token.release
	end
end
