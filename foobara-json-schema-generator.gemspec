require_relative "version"

Gem::Specification.new do |spec|
  spec.name = "foobara-json-schema-generator"
  spec.version = Foobara::JsonSchemaGenerator::VERSION
  spec.authors = ["Miles Georgi"]
  spec.email = ["azimux@gmail.com"]

  spec.summary = "Takes a Foobara type and converts it to a json schema"
  spec.homepage = "https://github.com/foobara/json-schema-generator"
  spec.license = "Apache-2.0 OR MIT"
  spec.required_ruby_version = Foobara::JsonSchemaGenerator::MINIMUM_RUBY_VERSION

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir[
    "lib/**/*",
    "src/**/*",
    "LICENSE*.txt",
    "README.md",
    "CHANGELOG.md"
  ]

  spec.add_dependency "foobara", ">= 0.0.136", "< 2.0.0"

  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"
end
