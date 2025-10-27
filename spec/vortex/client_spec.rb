# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vortex::Client do
  let(:client) { described_class.new(test_api_key) }
  let(:base_url) { 'https://api.vortexsoftware.com' }

  describe '#initialize' do
    it 'creates client with API key' do
      expect(client).to be_a(Vortex::Client)
    end

    it 'accepts custom base URL' do
      custom_client = described_class.new(test_api_key, base_url: 'https://custom.api.com')
      expect(custom_client).to be_a(Vortex::Client)
    end
  end

  describe '#generate_jwt' do
    let(:user_data) { test_user_data }

    it 'generates JWT with valid API key' do
      jwt = client.generate_jwt(**user_data)

      expect(jwt).to be_a(String)
      expect(jwt.split('.').length).to eq(3)

      # Decode header to verify structure
      header_json = Base64.urlsafe_decode64(jwt.split('.')[0] + '==')
      header = JSON.parse(header_json)

      expect(header['alg']).to eq('HS256')
      expect(header['typ']).to eq('JWT')
      expect(header['kid']).to be_a(String)
      expect(header['iat']).to be_a(Integer)
    end

    it 'includes all user data in JWT payload' do
      jwt = client.generate_jwt(**user_data)

      # Decode payload to verify structure
      payload_json = Base64.urlsafe_decode64(jwt.split('.')[1] + '==')
      payload = JSON.parse(payload_json)

      expect(payload['userId']).to eq(user_data[:user_id])
      expect(payload['identifiers']).to eq(user_data[:identifiers].map(&:stringify_keys))
      expect(payload['groups']).to eq(user_data[:groups].map(&:stringify_keys))
      expect(payload['role']).to eq(user_data[:role])
      expect(payload['expires']).to be_a(Integer)
    end

    it 'raises error with invalid API key format' do
      invalid_client = described_class.new('invalid-key')

      expect {
        invalid_client.generate_jwt(**user_data)
      }.to raise_error(Vortex::VortexError, /Invalid API key format/)
    end

    it 'raises error with wrong prefix' do
      invalid_client = described_class.new('WRONG.dGVzdA.key')

      expect {
        invalid_client.generate_jwt(**user_data)
      }.to raise_error(Vortex::VortexError, /Invalid API key prefix/)
    end

    it 'generates different JWTs for different users' do
      user1 = user_data.merge(user_id: 'user1')
      user2 = user_data.merge(user_id: 'user2')

      jwt1 = client.generate_jwt(**user1)
      jwt2 = client.generate_jwt(**user2)

      expect(jwt1).not_to eq(jwt2)
    end
  end

  describe '#get_invitations_by_target' do
    it 'makes GET request with correct parameters' do
      stub_request(:get, "#{base_url}/api/v1/invitations")
        .with(query: { targetType: 'email', targetValue: 'test@example.com' })
        .to_return(mock_successful_response({ invitations: [] }))

      result = client.get_invitations_by_target('email', 'test@example.com')

      expect(result).to eq([])
    end

    it 'returns invitations list' do
      invitations = [{ id: 'inv1', status: 'pending' }]
      stub_request(:get, "#{base_url}/api/v1/invitations")
        .to_return(mock_successful_response({ invitations: invitations }))

      result = client.get_invitations_by_target('email', 'test@example.com')

      expect(result).to eq(invitations.map(&:stringify_keys))
    end

    it 'raises error on API failure' do
      stub_request(:get, "#{base_url}/api/v1/invitations")
        .to_return(mock_error_response(500, 'Server error'))

      expect {
        client.get_invitations_by_target('email', 'test@example.com')
      }.to raise_error(Vortex::VortexError, /Failed to get invitations by target/)
    end
  end

  describe '#get_invitation' do
    let(:invitation_id) { 'inv123' }

    it 'makes GET request to correct endpoint' do
      invitation = { id: invitation_id, status: 'pending' }
      stub_request(:get, "#{base_url}/api/v1/invitations/#{invitation_id}")
        .to_return(mock_successful_response(invitation))

      result = client.get_invitation(invitation_id)

      expect(result).to eq(invitation.stringify_keys)
    end

    it 'raises error when invitation not found' do
      stub_request(:get, "#{base_url}/api/v1/invitations/#{invitation_id}")
        .to_return(mock_error_response(404, 'Not found'))

      expect {
        client.get_invitation(invitation_id)
      }.to raise_error(Vortex::VortexError, /Failed to get invitation/)
    end
  end

  describe '#revoke_invitation' do
    let(:invitation_id) { 'inv123' }

    it 'makes DELETE request to correct endpoint' do
      stub_request(:delete, "#{base_url}/api/v1/invitations/#{invitation_id}")
        .to_return(mock_successful_response({ success: true }))

      result = client.revoke_invitation(invitation_id)

      expect(result).to eq({ 'success' => true })
    end

    it 'raises error on failure' do
      stub_request(:delete, "#{base_url}/api/v1/invitations/#{invitation_id}")
        .to_return(mock_error_response(400, 'Bad request'))

      expect {
        client.revoke_invitation(invitation_id)
      }.to raise_error(Vortex::VortexError, /Failed to revoke invitation/)
    end
  end

  describe '#accept_invitations' do
    let(:invitation_ids) { ['inv1', 'inv2'] }
    let(:target) { { type: 'email', value: 'test@example.com' } }

    it 'makes POST request with correct body' do
      expected_body = {
        invitationIds: invitation_ids,
        target: target
      }

      stub_request(:post, "#{base_url}/api/v1/invitations/accept")
        .with(body: expected_body.to_json)
        .to_return(mock_successful_response({ id: 'result123' }))

      result = client.accept_invitations(invitation_ids, target)

      expect(result).to eq({ 'id' => 'result123' })
    end

    it 'raises error on failure' do
      stub_request(:post, "#{base_url}/api/v1/invitations/accept")
        .to_return(mock_error_response(400, 'Invalid request'))

      expect {
        client.accept_invitations(invitation_ids, target)
      }.to raise_error(Vortex::VortexError, /Failed to accept invitations/)
    end
  end

  describe '#get_invitations_by_group' do
    let(:group_type) { 'team' }
    let(:group_id) { 'team123' }

    it 'makes GET request to correct endpoint' do
      invitations = [{ id: 'inv1' }, { id: 'inv2' }]
      stub_request(:get, "#{base_url}/api/v1/invitations/by-group/#{group_type}/#{group_id}")
        .to_return(mock_successful_response({ invitations: invitations }))

      result = client.get_invitations_by_group(group_type, group_id)

      expect(result).to eq(invitations.map(&:stringify_keys))
    end

    it 'returns empty array when no invitations field' do
      stub_request(:get, "#{base_url}/api/v1/invitations/by-group/#{group_type}/#{group_id}")
        .to_return(mock_successful_response({}))

      result = client.get_invitations_by_group(group_type, group_id)

      expect(result).to eq([])
    end
  end

  describe '#delete_invitations_by_group' do
    let(:group_type) { 'team' }
    let(:group_id) { 'team123' }

    it 'makes DELETE request to correct endpoint' do
      stub_request(:delete, "#{base_url}/api/v1/invitations/by-group/#{group_type}/#{group_id}")
        .to_return(mock_successful_response({ success: true }))

      result = client.delete_invitations_by_group(group_type, group_id)

      expect(result).to eq({ 'success' => true })
    end
  end

  describe '#reinvite' do
    let(:invitation_id) { 'inv123' }

    it 'makes POST request to correct endpoint' do
      result_data = { id: 'inv123', status: 'resent' }
      stub_request(:post, "#{base_url}/api/v1/invitations/#{invitation_id}/reinvite")
        .to_return(mock_successful_response(result_data))

      result = client.reinvite(invitation_id)

      expect(result).to eq(result_data.stringify_keys)
    end

    it 'raises error on failure' do
      stub_request(:post, "#{base_url}/api/v1/invitations/#{invitation_id}/reinvite")
        .to_return(mock_error_response(404, 'Invitation not found'))

      expect {
        client.reinvite(invitation_id)
      }.to raise_error(Vortex::VortexError, /Failed to reinvite/)
    end
  end

  describe 'error handling' do
    it 'handles 401 unauthorized' do
      stub_request(:get, "#{base_url}/api/v1/invitations")
        .to_return(mock_error_response(401, 'Unauthorized'))

      expect {
        client.get_invitations_by_target('email', 'test@example.com')
      }.to raise_error(Vortex::VortexError, /Client error \(401\): Unauthorized/)
    end

    it 'handles 500 server error' do
      stub_request(:get, "#{base_url}/api/v1/invitations")
        .to_return(mock_error_response(500, 'Internal server error'))

      expect {
        client.get_invitations_by_target('email', 'test@example.com')
      }.to raise_error(Vortex::VortexError, /Server error \(500\): Internal server error/)
    end

    it 'handles unexpected status codes' do
      stub_request(:get, "#{base_url}/api/v1/invitations")
        .to_return(status: 999, body: 'Unknown')

      expect {
        client.get_invitations_by_target('email', 'test@example.com')
      }.to raise_error(Vortex::VortexError, /Unexpected response \(999\)/)
    end
  end
end