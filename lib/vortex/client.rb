# frozen_string_literal: true

require 'base64'
require 'json'
require 'openssl'
require 'securerandom'
require 'faraday'

module Vortex
  # Vortex API client for Ruby
  #
  # Provides the same functionality as other Vortex SDKs with JWT generation,
  # invitation management, and full API compatibility.
  class Client
    # Base URL for Vortex API
    DEFAULT_BASE_URL = 'https://api.vortexsoftware.com'

    # @param api_key [String] Your Vortex API key
    # @param base_url [String] Custom base URL (optional)
    def initialize(api_key, base_url: nil)
      @api_key = api_key
      @base_url = base_url || DEFAULT_BASE_URL
      @connection = build_connection
    end

    # Generate a JWT for the given user data
    #
    # This uses the exact same algorithm as the Node.js SDK to ensure
    # complete compatibility across all platforms.
    #
    # @param user_id [String] Unique identifier for the user
    # @param identifiers [Array<Hash>] Array of identifier hashes with :type and :value
    # @param groups [Array<Hash>] Array of group hashes with :id, :type, and :name
    # @param role [String, nil] Optional user role
    # @return [String] JWT token
    # @raise [VortexError] If API key is invalid or JWT generation fails
    def generate_jwt(user_id:, identifiers:, groups:, role: nil)
      # Parse API key - same format as Node.js SDK
      prefix, encoded_id, key = @api_key.split('.')

      raise VortexError, 'Invalid API key format' unless prefix && encoded_id && key
      raise VortexError, 'Invalid API key prefix' unless prefix == 'VRTX'

      # Decode the ID from base64url (same as Node.js Buffer.from(encodedId, 'base64url'))
      decoded_bytes = Base64.urlsafe_decode64(encoded_id)

      # Convert to UUID string format (same as uuidStringify in Node.js)
      id = format_uuid(decoded_bytes)

      expires = Time.now.to_i + 3600

      # Step 1: Derive signing key from API key + ID (same as Node.js)
      signing_key = OpenSSL::HMAC.digest('sha256', key, id)

      # Step 2: Build header + payload (same structure as Node.js)
      header = {
        iat: Time.now.to_i,
        alg: 'HS256',
        typ: 'JWT',
        kid: id
      }

      payload = {
        userId: user_id,
        groups: groups,
        role: role,
        expires: expires,
        identifiers: identifiers
      }

      # Step 3: Base64URL encode (same as Node.js)
      header_b64 = base64url_encode(JSON.generate(header))
      payload_b64 = base64url_encode(JSON.generate(payload))

      # Step 4: Sign with HMAC-SHA256 (same as Node.js)
      signature = OpenSSL::HMAC.digest('sha256', signing_key, "#{header_b64}.#{payload_b64}")
      signature_b64 = base64url_encode(signature)

      "#{header_b64}.#{payload_b64}.#{signature_b64}"
    rescue => e
      raise VortexError, "JWT generation failed: #{e.message}"
    end

    # Get invitations by target
    #
    # @param target_type [String] Type of target (email, sms)
    # @param target_value [String] Value of target (email address, phone number)
    # @return [Array<Hash>] List of invitations
    # @raise [VortexError] If the request fails
    def get_invitations_by_target(target_type, target_value)
      response = @connection.get('/api/v1/invitations') do |req|
        req.params['targetType'] = target_type
        req.params['targetValue'] = target_value
      end

      handle_response(response)['invitations'] || []
    rescue => e
      raise VortexError, "Failed to get invitations by target: #{e.message}"
    end

    # Get a specific invitation by ID
    #
    # @param invitation_id [String] The invitation ID
    # @return [Hash] The invitation data
    # @raise [VortexError] If the request fails
    def get_invitation(invitation_id)
      response = @connection.get("/api/v1/invitations/#{invitation_id}")
      handle_response(response)
    rescue => e
      raise VortexError, "Failed to get invitation: #{e.message}"
    end

    # Revoke (delete) an invitation
    #
    # @param invitation_id [String] The invitation ID to revoke
    # @return [Hash] Success response
    # @raise [VortexError] If the request fails
    def revoke_invitation(invitation_id)
      response = @connection.delete("/api/v1/invitations/#{invitation_id}")
      handle_response(response)
    rescue => e
      raise VortexError, "Failed to revoke invitation: #{e.message}"
    end

    # Accept invitations
    #
    # @param invitation_ids [Array<String>] List of invitation IDs to accept
    # @param target [Hash] Target hash with :type and :value
    # @return [Hash] The accepted invitation result
    # @raise [VortexError] If the request fails
    def accept_invitations(invitation_ids, target)
      body = {
        invitationIds: invitation_ids,
        target: target
      }

      response = @connection.post('/api/v1/invitations/accept') do |req|
        req.headers['Content-Type'] = 'application/json'
        req.body = JSON.generate(body)
      end

      handle_response(response)
    rescue => e
      raise VortexError, "Failed to accept invitations: #{e.message}"
    end

    # Get invitations by group
    #
    # @param group_type [String] The group type
    # @param group_id [String] The group ID
    # @return [Array<Hash>] List of invitations for the group
    # @raise [VortexError] If the request fails
    def get_invitations_by_group(group_type, group_id)
      response = @connection.get("/api/v1/invitations/by-group/#{group_type}/#{group_id}")
      result = handle_response(response)
      result['invitations'] || []
    rescue => e
      raise VortexError, "Failed to get group invitations: #{e.message}"
    end

    # Delete invitations by group
    #
    # @param group_type [String] The group type
    # @param group_id [String] The group ID
    # @return [Hash] Success response
    # @raise [VortexError] If the request fails
    def delete_invitations_by_group(group_type, group_id)
      response = @connection.delete("/api/v1/invitations/by-group/#{group_type}/#{group_id}")
      handle_response(response)
    rescue => e
      raise VortexError, "Failed to delete group invitations: #{e.message}"
    end

    # Reinvite a user
    #
    # @param invitation_id [String] The invitation ID to reinvite
    # @return [Hash] The reinvited invitation result
    # @raise [VortexError] If the request fails
    def reinvite(invitation_id)
      response = @connection.post("/api/v1/invitations/#{invitation_id}/reinvite")
      handle_response(response)
    rescue => e
      raise VortexError, "Failed to reinvite: #{e.message}"
    end

    private

    def build_connection
      Faraday.new(@base_url) do |conn|
        conn.request :json
        conn.response :json, content_type: /\bjson$/
        conn.adapter Faraday.default_adapter

        # Add API key header (same as Node.js SDK)
        conn.headers['x-api-key'] = @api_key
        conn.headers['User-Agent'] = "vortex-ruby-sdk/#{Vortex::VERSION}"
      end
    end

    def handle_response(response)
      case response.status
      when 200..299
        response.body || {}
      when 400..499
        error_msg = response.body.is_a?(Hash) ? response.body['error'] || response.body['message'] : 'Client error'
        raise VortexError, "Client error (#{response.status}): #{error_msg}"
      when 500..599
        error_msg = response.body.is_a?(Hash) ? response.body['error'] || response.body['message'] : 'Server error'
        raise VortexError, "Server error (#{response.status}): #{error_msg}"
      else
        raise VortexError, "Unexpected response (#{response.status}): #{response.body}"
      end
    end

    # Base64URL encode (no padding, URL-safe)
    def base64url_encode(data)
      Base64.urlsafe_encode64(data).tr('=', '')
    end

    # Format binary UUID data as string (same as Node.js uuidStringify)
    def format_uuid(bytes)
      return nil unless bytes.length == 16

      # Convert to hex and format as UUID
      hex = bytes.unpack1('H*')
      "#{hex[0, 8]}-#{hex[8, 4]}-#{hex[12, 4]}-#{hex[16, 4]}-#{hex[20, 12]}"
    end
  end
end