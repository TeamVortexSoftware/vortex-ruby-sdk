# frozen_string_literal: true

require 'spec_helper'
require 'vortex'
require 'net/http'
require 'json'

RSpec.describe 'Integration Test', :integration do
  let(:api_key) do
    ENV['TEST_INTEGRATION_SDKS_VORTEX_API_KEY'] || raise(StandardError, 'Missing required environment variable: TEST_INTEGRATION_SDKS_VORTEX_API_KEY')
  end

  let(:client_api_url) do
    ENV['TEST_INTEGRATION_SDKS_VORTEX_CLIENT_API_URL'] || raise(StandardError, 'Missing required environment variable: TEST_INTEGRATION_SDKS_VORTEX_CLIENT_API_URL')
  end

  let(:public_api_url) do
    ENV['TEST_INTEGRATION_SDKS_VORTEX_PUBLIC_API_URL'] || raise(StandardError, 'Missing required environment variable: TEST_INTEGRATION_SDKS_VORTEX_PUBLIC_API_URL')
  end

  let(:session_id) do
    ENV['TEST_INTEGRATION_SDKS_VORTEX_SESSION_ID'] || raise(StandardError, 'Missing required environment variable: TEST_INTEGRATION_SDKS_VORTEX_SESSION_ID')
  end

  let!(:user_email) do
    email = ENV['TEST_INTEGRATION_SDKS_USER_EMAIL'] || raise(StandardError, 'Missing required environment variable: TEST_INTEGRATION_SDKS_USER_EMAIL')
    email.gsub('{timestamp}', Time.now.to_i.to_s)
  end

  let(:group_type) do
    ENV['TEST_INTEGRATION_SDKS_GROUP_TYPE'] || raise(StandardError, 'Missing required environment variable: TEST_INTEGRATION_SDKS_GROUP_TYPE')
  end

  # TEST_INTEGRATION_SDKS_GROUP_ID is dynamic - generated from timestamp
  let(:group_id) { "test-group-#{Time.now.to_i}" }

  let(:group_name) do
    ENV['TEST_INTEGRATION_SDKS_GROUP_NAME'] || raise(StandardError, 'Missing required environment variable: TEST_INTEGRATION_SDKS_GROUP_NAME')
  end

  let(:public_client) { Vortex::Client.new(api_key, base_url: public_api_url) }
  let(:invitation_id) { @invitation_id }

  it 'completes full invitation flow' do
    puts "\n--- Starting Ruby SDK Integration Test ---"

    # Step 1: Create invitation
    puts 'Step 1: Creating invitation...'
    @invitation_id = create_invitation
    expect(@invitation_id).not_to be_nil
    puts "✓ Created invitation: #{@invitation_id}"

    # Step 2: Get invitation
    puts 'Step 2: Getting invitation...'
    invitations = public_client.get_invitations_by_target('email', user_email)
    expect(invitations).not_to be_empty
    puts '✓ Retrieved invitation successfully'

    # Step 3: Accept invitation
    puts 'Step 3: Accepting invitation...'
    result = public_client.accept_invitations(
      [@invitation_id],
      { type: 'email', value: user_email }
    )
    expect(result).not_to be_nil
    puts '✓ Accepted invitation successfully'

    puts "--- Ruby SDK Integration Test Complete ---\n"
  end

  def create_invitation
    # Generate JWT for authentication
    jwt_client = Vortex::Client.new(api_key, base_url: client_api_url)
    user_id = ENV['TEST_INTEGRATION_SDKS_USER_ID'] || raise(StandardError, 'Missing required environment variable: TEST_INTEGRATION_SDKS_USER_ID')
    jwt = jwt_client.generate_jwt({
      user: {
        id: user_id,
        email: user_email
      },
      attributes: {
      }
    })

    # Step 1: Fetch widget configuration to get the widget configuration ID and sessionAttestation
    component_id = ENV['TEST_INTEGRATION_SDKS_VORTEX_COMPONENT_ID'] || raise(StandardError, 'Missing required environment variable: TEST_INTEGRATION_SDKS_VORTEX_COMPONENT_ID')
    widget_uri = URI("#{client_api_url}/api/v1/widgets/#{component_id}?templateVariables=lzstr:N4Ig5gTg9grgDgfQHYEMC2BTEAuEBlAEQGkACAFQwGcAXEgcWnhABoQBLJANzeowmXRZcBCCQBqUCLwAeLcI0SY0AIz4IAxrCTUcIAMxzNaOCiQBPAZl0SpGaSQCSSdQDoQAXyA")
    widget_http = Net::HTTP.new(widget_uri.host, widget_uri.port)
    widget_request = Net::HTTP::Get.new(widget_uri.request_uri, {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{jwt}",
      'x-session-id' => session_id
    })

    widget_response = widget_http.request(widget_request)
    raise "Failed to fetch widget configuration: #{widget_response.code}" unless widget_response.is_a?(Net::HTTPSuccess)

    widget_data = JSON.parse(widget_response.body)
    widget_config_id = widget_data.dig('data', 'widgetConfiguration', 'id')
    session_attestation = widget_data.dig('data', 'sessionAttestation')

    raise "Widget configuration ID not found in response" unless widget_config_id
    raise "Session attestation not found in widget response" unless session_attestation

    puts "Using widget configuration ID: #{widget_config_id}"

    # Now use the session attestation for subsequent requests
    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{jwt}",
      'x-session-id' => session_id,
      'x-session-attestation' => session_attestation
    }

    # Step 2: Create invitation with the widget configuration ID
    invitation_uri = URI("#{client_api_url}/api/v1/invitations")

    data = {
      payload: {
        emails: {
          value: user_email,
          type: 'email',
          role: 'member'
        }
      },
      group: {
        type: group_type,
        groupId: group_id,
        name: group_name
      },
      source: 'email',
      widgetConfigurationId: widget_config_id,
      templateVariables: {
        group_name: 'SDK Test Group',
        inviter_name: 'Dr Vortex',
        group_member_count: '3',
        company_name: 'Vortex Inc.'
      }
    }

    http = Net::HTTP.new(invitation_uri.host, invitation_uri.port)
    request = Net::HTTP::Post.new(invitation_uri.path, headers)
    request.body = data.to_json

    response = http.request(request)
    raise "Create invitation failed: #{response.code} - #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    result = JSON.parse(response.body)
    # The API returns the full widget configuration with invitation entries
    invitation_id = result.dig('data', 'invitationEntries', 0, 'id') || result['id']

    puts "Successfully extracted invitation ID: #{invitation_id}" if invitation_id
    invitation_id
  end
end
