# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rezept/version'

Gem::Specification.new do |spec|
  spec.name          = "rezept"
  spec.version       = Rezept::VERSION
  spec.authors       = ["Serverworks Co.,Ltd."]
  spec.email         = ["terui@serverworks.co.jp"]

  spec.summary       = %q{A tool to manage EC2 Systems Manager Documents.}
  spec.description   = %q{A tool to manage EC2 Systems Manager Documents.}
  spec.homepage      = "https://github.com/serverworks/rezept"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "aws-sdk", "~> 2.7.4"
  spec.add_dependency "dslh", ">= 0.4.8"
  spec.add_dependency "thor"
  spec.add_dependency "coderay"
  spec.add_dependency "diffy"
  spec.add_dependency "hashie"

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
