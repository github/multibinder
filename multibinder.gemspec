# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'multibinder/version'

Gem::Specification.new do |spec|
  spec.name          = "multibinder"
  spec.version       = MultiBinder::VERSION
  spec.authors       = ["Theo Julienne"]
  spec.email         = ["theojulienne@github.com"]
  spec.summary       = %q{multibinder is a tiny ruby server that makes writing zero-downtime-reload services simpler.}
  spec.homepage      = "https://github.com/theojulienne/multibinder"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake", "~> 10.0"
end
