# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "io/endpoint/wrapper"
require_relative "semaphore"

module Falcon
	module Limiter
		# An endpoint wrapper that limits concurrent connections using a semaphore.
		# This provides backpressure by limiting how many connections can be accepted simultaneously.
		# Based on https://github.com/socketry/falcon/tree/main/examples/limited
		class Wrapper < IO::Endpoint::Wrapper
			def initialize(endpoint, semaphore: nil, **options)
				super(endpoint, **options)
				@semaphore = semaphore
			end
			
			attr_reader :semaphore
			
			# Wait for an inbound connection to be ready to be accepted.
			def wait_for_inbound_connection(server)
				# Wait until there is a connection ready to be accepted:
				loop do
					server.wait_readable
					
					# Acquire the semaphore:
					if token = @semaphore&.acquire
						return token
					end
				end
			end
			
			# Once the server is readable and we've acquired the token, 
			# we can accept the connection (if it's still there).
			def socket_accept_nonblock(server, token)
				result = server.accept_nonblock
				
				success = true
				result
			rescue IO::WaitReadable
				nil
			ensure
				token&.release unless success
			end
			
			# Accept a connection from the server, limited by the semaphore.
			def socket_accept(server)
				socket = nil
				address = nil
				token = nil
				
				loop do
					next unless token = wait_for_inbound_connection(server)
					
					# In principle, there is a connection ready to be accepted:
					socket, address = socket_accept_nonblock(server, token)
					
					if socket
						break
					end
				end
				
				# Provide access to the token, so that the connection limit 
				# can be released prematurely if needed (for long tasks):
				socket.define_singleton_method(:token) do
					token
				end
				
				# Provide a way to release the semaphore when the connection is closed:
				socket.define_singleton_method(:close) do
					super()
				ensure
					token&.release
				end
				
				return socket, address
			end
			
			# Provide statistics about connection limiting
			def statistics
				return {} unless @semaphore
				
				{
					available: @semaphore.available_count,
					acquired: @semaphore.acquired_count,
					limit: @semaphore.limit,
					waiting: @semaphore.waiting_count,
					reacquire: @semaphore.reacquire_count
				}
			end
		end
	end
end
