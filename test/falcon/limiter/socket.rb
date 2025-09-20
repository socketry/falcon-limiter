# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "falcon/limiter"

describe Falcon::Limiter::Socket do
	let(:limiter) {Falcon::Limiter::Semaphore.new(1)}
	let(:token) {Async::Limiter::Token.acquire(limiter)}
	
	let(:mock_socket) do
		Object.new.tap do |socket|
			socket.define_singleton_method(:close) {@closed = true}
			socket.define_singleton_method(:closed?) {@closed || false}
			socket.define_singleton_method(:read) {"socket data"}
			socket.define_singleton_method(:write) {|data| data.length}
			socket.define_singleton_method(:inspect) {"#<MockSocket>"}
			socket.define_singleton_method(:to_s) {"MockSocket"}
			socket.define_singleton_method(:class) {Object}
		end
	end
	
	let(:limited_socket) {Falcon::Limiter::Socket.new(mock_socket, token)}
	
	it "provides transparent access to token" do
		expect(limited_socket.token).to be == token
	end
	
	it "delegates methods transparently to wrapped socket" do
		# Test delegation
		expect(limited_socket.read).to be == "socket data"
		expect(limited_socket.write("test")).to be == 4
		expect(limited_socket.closed?).to be == false
	end
	
	it "responds to socket methods correctly" do
		expect(limited_socket).to respond_to(:read)
		expect(limited_socket).to respond_to(:write)
		expect(limited_socket).to respond_to(:close)
		expect(limited_socket).to respond_to(:token)
		expect(limited_socket).not.to respond_to(:nonexistent_method)
	end
	
	it "handles respond_to_missing? correctly" do
		# Add a method to the delegate after socket creation
		mock_socket.define_singleton_method(:new_method) {"new method"}
		
		# Should delegate respond_to? check to the delegate
		expect(limited_socket).to respond_to(:new_method)
		expect(limited_socket).not.to respond_to(:truly_missing_method)
		
		# Test respond_to_missing? directly
		expect(limited_socket.respond_to?(:new_method)).to be == true
		expect(limited_socket.respond_to?(:truly_missing_method)).to be == false
		
		# Test respond_to_missing? with a method that neither delegate nor super responds to
		# This should trigger the || super path in respond_to_missing?
		expect(limited_socket.respond_to?(:completely_unknown_method)).to be == false
	end
	
	
	it "releases token when closed" do
		expect(token).not.to be(:released?)
		
		limited_socket.close
		
		expect(token).to be(:released?)
		expect(limited_socket.closed?).to be == true
	end
	
	it "provides proper string conversion" do
		string_result = limited_socket.to_s
		expect(string_result).to be == "MockSocket"
	end
	
	it "delegates method_missing calls" do
		# Add a custom method to the mock socket
		mock_socket.define_singleton_method(:custom_method) {"custom result"}
		
		# Should delegate transparently
		result = limited_socket.custom_method
		expect(result).to be == "custom result"
	end
end
