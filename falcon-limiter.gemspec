# frozen_string_literal: true

require_relative "lib/falcon/limiter/version"

Gem::Specification.new do |spec|
	spec.name = "falcon-limiter"
	spec.version = Falcon::Limiter::VERSION
	
	spec.summary = "Advanced concurrency control and resource limiting for Falcon web server."
	spec.authors = ["Samuel Williams"]
	spec.license = "MIT"
	
	spec.cert_chain  = ["release.cert"]
	spec.signing_key = File.expand_path("~/.gem/release.pem")
	
	spec.homepage = "https://github.com/socketry/falcon-limiter"
	
	spec.metadata = {
		"documentation_uri" => "https://socketry.github.io/falcon-limiter/",
		"source_code_uri" => "https://github.com/socketry/falcon-limiter.git",
	}
	
	spec.files = Dir.glob(["{context,lib,examples}/**/*", "*.md"], File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 3.2"
	
	spec.add_dependency "async-limiter", ">= 1.5"
	spec.add_dependency "protocol-http", "~> 0.31"
	spec.add_dependency "async", ">= 2.31.0"
end
