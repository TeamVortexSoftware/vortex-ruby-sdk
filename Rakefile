# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'yard'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new(:rubocop)
YARD::Rake::YardocTask.new

desc 'Run all tests and linting'
task test: [:spec, :rubocop]

desc 'Run tests with coverage'
task :coverage do
  ENV['COVERAGE'] = 'true'
  Rake::Task['spec'].execute
end

desc 'Generate documentation'
task :docs do
  Rake::Task['yard'].execute
end

desc 'Setup development environment'
task :setup do
  sh 'bundle install'
  puts 'Development environment ready!'
end

desc 'Run interactive console'
task :console do
  require 'bundler/setup'
  require 'vortex'
  require 'irb'
  IRB.start(__FILE__)
end

task default: :test