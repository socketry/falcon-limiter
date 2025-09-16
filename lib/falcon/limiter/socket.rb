# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Falcon
	module Limiter
		# A transparent socket wrapper that automatically manages token release.
		# Behaves exactly like the wrapped socket but releases the limiter token on close.
		class Socket
			# Initialize the socket wrapper with delegation and token management.
			# @parameter delegate [Object] The socket object to wrap and delegate to.
			# @parameter token [Async::Limiter::Token] The limiter token to release when socket closes.
			def initialize(delegate, token)
				@delegate = delegate
				@token = token
			end
			
			# Provide access to the token for manual management if needed.
			attr_reader :token
			
			# Override close to release the token.
			def close
				@delegate.close
			ensure
				if token = @token
					@token = nil
					token.release
				end
			end
			
			# Transparent delegation to the wrapped delegate.
			def method_missing(method, *args, &block)
				@delegate.send(method, *args, &block)
			end
			
			# Check if this wrapper or the delegate responds to a method.
			# @parameter method [Symbol] The method name to check.
			# @parameter include_private [Boolean] Whether to include private methods (default: false).
			# @returns [Boolean] True if either wrapper or delegate responds to the method.
			def respond_to?(method, include_private = false)
				super || @delegate.respond_to?(method, include_private)
			end
			
			# Support for method_missing delegation by checking delegate's methods.
			# @parameter method [Symbol] The method name to check.
			# @parameter include_private [Boolean] Whether to include private methods (default: false).
			# @returns [Boolean] True if the delegate responds to the method.
			def respond_to_missing?(method, include_private = false)
				@delegate.respond_to?(method, include_private) || super
			end
			
			# Forward common inspection methods
			def inspect
				"#<#{self.class}(#{@delegate.class}) #{@delegate.inspect}>"
			end
			
			# String representation of the wrapped socket.
			# @returns [String] The string representation of the delegate socket.
			def to_s
				@delegate.to_s
			end
		end
	end
end
