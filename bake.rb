# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

def initialize(context)
	super
	
	context.load_file(File.expand_path("bake/falcon/limiter.rb", context.root))
end
