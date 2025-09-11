# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

source "https://rubygems.org"

gemspec

# Use local development version of async-limiter
gem "async-limiter", path: "../async-limiter"

group :maintenance, optional: true do
	gem "bake-gem"
	gem "utopia-project"
end

group :test do
	gem "sus"
	gem "covered"
	gem "sus-fixtures-async"
	gem "sus-fixtures-async-http"
	
	gem "bake"
	gem "bake-test"
end
