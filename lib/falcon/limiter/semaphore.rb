# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Josh Teeter.
# Copyright, 2025, by Samuel Williams.

require "async/limiter"
require "async/limiter/token"
require "async/priority_queue"

module Falcon
	module Limiter
		# Simple wrapper around Async::Limiter::Queued that provides the interface
		# expected by Falcon while leveraging async-limiter's implementation.
		module Semaphore
			# Create a new limiter with the specified capacity.
			# @parameter limit [Integer] The maximum number of concurrent operations allowed (default: 1).
			# @returns [Async::Limiter::Queued] A new limiter instance with pre-allocated tokens.
			def self.new(limit = 1)
				# Create priority queue and pre-populate with tokens
				queue = Async::PriorityQueue.new
				limit.times{queue.push(true)}
				
				return Async::Limiter::Queued.new(queue)
			end
		end
	end
end
