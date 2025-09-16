# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "limiter/semaphore"
require_relative "limiter/socket"
require_relative "limiter/wrapper"
require_relative "limiter/long_task"
require_relative "limiter/middleware"
require_relative "limiter/environment"

# @namespace
module Falcon
	# @namespace
	module Limiter
	end
end
