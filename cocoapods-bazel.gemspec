# frozen_string_literal: true

require_relative 'lib/cocoapods/bazel/version'

Gem::Specification.new do |spec|
  spec.name          = 'cocoapods-bazel'
  spec.version       = Pod::Bazel::VERSION
  spec.authors       = ['Shawn Chen', 'Samuel Giddins']
  spec.email         = ['swchen@linkedin.com', 'segiddins@squareup.com']

  spec.summary       = 'A plugin for CocoaPods that generates Bazel build files for pods'
  spec.homepage      = 'https://github.com/ob/cocoapods-bazel'
  spec.license       = 'apache2'

  spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '>= 2.1'

  spec.add_runtime_dependency 'starlark_compiler'

  spec.required_ruby_version = '>= 2.6'
end
