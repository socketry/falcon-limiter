# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "io/endpoint/wrapper"
require "async/limiter/token"
require_relative "socket"

module Falcon
	module Limiter
		# An endpoint wrapper that limits concurrent connections using a semaphore.
		# This provides backpressure by limiting how many connections can be accepted simultaneously.
		class Wrapper < IO::Endpoint::Wrapper
			# Initialize the wrapper with a connection limiter.
			# @parameter limiter [Async::Limiter] The limiter instance for controlling concurrent connections.
			def initialize(limiter)
				super()
				@limiter = limiter
			end
			
			attr_reader :limiter
			
			# Wait for an inbound connection to be ready to be accepted.
			def wait_for_inbound_connection(server)
				loop do
					# Wait until there is a connection ready to be accepted:
					server.wait_readable
					
					# Acquire the limiter:
					if token = Async::Limiter::Token.acquire(@limiter)
						return token
					end
				end
			end
			
			# Once the server is readable and we've acquired the token, we can accept the connection (if it's still there).
			def socket_accept_nonblock(server, token)
				socket = server.accept_nonblock
			rescue IO::WaitReadable
				nil
			ensure
				token.release unless socket
			end
			
			# Wrap the socket with a transparent token management.
			# @parameter socket [Object] The socket to wrap.
			# @parameter token [Async::Limiter::Token] The limiter token to release when socket closes.
			# @returns [Falcon::Limiter::Socket] The wrapped socket.
			def wrap_socket(socket, token)
				Socket.new(socket, token)
			end
			
			# Accept a connection from the server, limited by the per-worker (thread or process) semaphore.
			def socket_accept(server)
				socket = nil
				address = nil
				token = nil
				
				loop do
					next unless token = wait_for_inbound_connection(server)
					
					# In principle, there is a connection ready to be accepted:
					socket, address = socket_accept_nonblock(server, token)
					
					break if socket
				end
				
				# Wrap socket with transparent token management
				return wrap_socket(socket, token), address
			end
		end
	end
end
