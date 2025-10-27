# frozen_string_literal: true

require_relative 'lib/vortex/version'

Gem::Specification.new do |spec|
  spec.name = 'vortex-ruby-sdk'
  spec.version = Vortex::VERSION
  spec.authors = ['Vortex Software']
  spec.email = ['support@vortexsoftware.io']

  spec.summary = 'Ruby SDK for Vortex invitation system'
  spec.description = 'A Ruby SDK that provides seamless integration with the Vortex invitation system, including JWT generation and invitation management.'
  spec.homepage = 'https://github.com/vortexsoftware/vortex-ruby-sdk'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'faraday', '~> 2.0'
  spec.add_dependency 'faraday-net_http', '~> 3.0'

  # Framework integration dependencies (optional)
  spec.add_dependency 'rack', '>= 2.0'

  # Development dependencies
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'webmock', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 1.0'
  spec.add_development_dependency 'yard', '~> 0.9'
  spec.add_development_dependency 'bundler', '>= 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
end