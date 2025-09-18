#!/usr/bin/env falcon-host
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "falcon/limiter/environment"
require "falcon/environment/rack"

service "hello.localhost" do
	include Falcon::Environment::Rack
	include Falcon::Limiter::Environment
	
	endpoint do
		Async::HTTP::Endpoint.parse("http://localhost:9292").with(wrapper: limiter_wrapper)
	end
	
	count {1}
end
