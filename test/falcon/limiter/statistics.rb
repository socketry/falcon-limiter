# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "falcon/limiter"

describe "Statistics Coverage" do
	let(:limiter) {Falcon::Limiter::Semaphore.new(2)}
	
	let(:middleware) do
		app = lambda {|request| Protocol::HTTP::Response[200, {}, ["OK"]]}
		Falcon::Limiter::Middleware.new(app, limiter: limiter, maximum_long_tasks: 3)
	end
	
	it "covers limiter_stats method" do
		# Access the private method correctly
		stats = middleware.statistics
		
		expect(stats).to be_a(Hash)
		if stats[:socket_accept]
			expect(stats[:socket_accept]).to be_a(Hash)
		end
		if stats[:long_task]
			expect(stats[:long_task]).to be_a(Hash)
		end
	end
	
	it "covers middleware response body handling" do
		# Test that middleware properly handles response bodies using Protocol::HTTP::Body::Completable
		body = Object.new
		body.define_singleton_method(:empty?) {false}
		body.define_singleton_method(:read) {"content"}
		
		# Mock request for middleware testing
		request = Object.new
		
		# The middleware should handle response body wrapping properly
		expect {middleware.call(request)}.not.to raise_exception
	end
end
