# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "falcon/limiter"

describe Falcon::Limiter do
	it "has a version" do
		expect(Falcon::Limiter::VERSION).to be =~ /\A\d+\.\d+\.\d+\z/
	end
end
