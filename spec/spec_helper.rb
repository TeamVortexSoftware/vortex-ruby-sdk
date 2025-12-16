# frozen_string_literal: true

require 'bundler/setup'
require 'webmock/rspec'
require 'vortex'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Configure WebMock - allow real HTTP for integration tests
  config.before(:each) do |example|
    WebMock.reset!
    if example.metadata[:integration]
      WebMock.allow_net_connect!
    else
      WebMock.disable_net_connect!(allow_localhost: false)
    end
  end

  # Test helpers
  config.include Module.new {
    def test_api_key
      'VRTX.dGVzdC11dWlkLTEyMzQ1Njc4LTkwYWItY2RlZi0xMjM0LTU2Nzg5MGFiY2RlZg.test-secret-key-12345'
    end

    def test_user_data
      {
        user_id: 'user123',
        identifiers: [{ type: 'email', value: 'test@example.com' }],
        groups: [{ id: 'team1', type: 'team', name: 'Engineering' }],
        role: 'admin'
      }
    end

    def mock_successful_response(body = {})
      {
        status: 200,
        body: body.to_json,
        headers: { 'Content-Type' => 'application/json' }
      }
    end

    def mock_error_response(status, message)
      {
        status: status,
        body: { error: message }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      }
    end
  }
end