
lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "fauxhai_generator/version"

Gem::Specification.new do |spec|
  spec.name          = "fauxhai_generator"
  spec.version       = FauxhaiGenerator::VERSION
  spec.authors       = ["Tim Smith"]
  spec.email         = ["tsmith@chef.io"]

  spec.summary       = "Spin up systems in AWS and generate new Fauxhai dumps"
  spec.description   = "Spin up systems in AWS and generate new Fauxhai dumps"
  spec.homepage      = "http://www.github.com/chefspec/fauxhai_generator"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "aws-sdk-ec2"
  spec.add_dependency "train-core"
  spec.add_dependency "deepsort"

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
end
