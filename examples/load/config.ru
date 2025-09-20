# frozen_string_literal: true

require "falcon/limiter/long_task"

run do |env|
	path = env["PATH_INFO"]
	
	case path
	when "/io"
		Console.info(self, "Starting \"I/O intensive\" task...")
		Falcon::Limiter::LongTask.current.start(delay: 0.1)
		sleep(10)
	when "/cpu"
		Console.info(self, "Starting \"CPU intensive\" task...")
		sleep(10)
	end

	Console.info(self, "Request completed");
	
	[200, {"content-type" => "text/plain"}, ["Hello from Falcon Limiter!"]]
end
