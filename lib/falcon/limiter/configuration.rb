# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Falcon
	module Limiter
		# Configuration for the limiter system with environment-based defaults
		class Configuration
			def initialize
				@max_long_tasks = Integer(ENV["FALCON_LIMITER_MAX_LONG_TASKS"] || 4)
				@max_accepts = Integer(ENV["FALCON_LIMITER_MAX_ACCEPTS"] || 1)
				@start_delay = Float(ENV["FALCON_LIMITER_START_DELAY"] || 0.6)
			end
			
			# Maximum number of concurrent long tasks
			attr_accessor :max_long_tasks
			
			# Maximum number of concurrent connection accepts
			attr_accessor :max_accepts
			
			# Delay before starting long task (to avoid overhead for short operations)
			attr_accessor :start_delay
			
			# Global default configuration instance
			def self.default
				@default ||= new
			end
			
			# Reset the default configuration (useful for testing)
			def self.reset_default!
				@default = nil
			end
			
			def to_h
				{
					max_long_tasks: @max_long_tasks,
					max_accepts: @max_accepts,
					start_delay: @start_delay
				}
			end
		end
	end
end
