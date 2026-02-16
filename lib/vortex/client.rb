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

    # Generate a JWT token for a user
    #
    # @param params [Hash] JWT parameters with :user (required) and optional :attributes
    # @return [String] JWT token
    # @raise [VortexError] If API key is invalid or JWT generation fails
    #
    # @example Simple usage
    #   client = Vortex::Client.new(ENV['VORTEX_API_KEY'])
    #   jwt = client.generate_jwt({
    #     user: {
    #       id: 'user-123',
    #       email: 'user@example.com',
    #       admin_scopes: ['autojoin']
    #     }
    #   })
    #
    # @example With additional attributes
    #   jwt = client.generate_jwt({
    #     user: { id: 'user-123', email: 'user@example.com' },
    #     attributes: { role: 'admin', department: 'Engineering' }
    #   })
    def generate_jwt(params)
      user = params[:user]
      attributes = params[:attributes]

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

      # Step 2: Build header + payload
      header = {
        iat: Time.now.to_i,
        alg: 'HS256',
        typ: 'JWT',
        kid: id
      }

      # Build payload - start with required fields
      payload = {
        userId: user[:id],
        userEmail: user[:email],
        expires: expires
      }

      # Add name if present (convert snake_case to camelCase for JWT)
      if user[:user_name]
        payload[:userName] = user[:user_name]
      end

      # Add userAvatarUrl if present (convert snake_case to camelCase for JWT)
      if user[:user_avatar_url]
        payload[:userAvatarUrl] = user[:user_avatar_url]
      end

      # Add adminScopes if present
      if user[:admin_scopes]
        payload[:adminScopes] = user[:admin_scopes]
      end

      # Add allowedEmailDomains if present (for domain-restricted invitations)
      if user[:allowed_email_domains] && !user[:allowed_email_domains].empty?
        payload[:allowedEmailDomains] = user[:allowed_email_domains]
      end

      # Add any additional properties from attributes
      if attributes && !attributes.empty?
        payload.merge!(attributes)
      end

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

    public

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

    # Accept invitations using the new User format (preferred)
    #
    # Supports three formats:
    # 1. User hash (preferred): { email: '...', phone: '...', name: '...' }
    # 2. Target hash (deprecated): { type: 'email', value: '...' }
    # 3. Array of targets (deprecated): [{ type: 'email', value: '...' }, ...]
    #
    # @param invitation_ids [Array<String>] List of invitation IDs to accept
    # @param user_or_target [Hash, Array] User hash with :email/:phone/:name keys, OR legacy target(s)
    # @return [Hash] The accepted invitation result
    # @raise [VortexError] If the request fails
    #
    # @example New format (preferred)
    #   user = { email: 'user@example.com', name: 'John Doe' }
    #   result = client.accept_invitations(['inv-123'], user)
    #
    # @example Legacy format (deprecated)
    #   target = { type: 'email', value: 'user@example.com' }
    #   result = client.accept_invitations(['inv-123'], target)
    def accept_invitations(invitation_ids, user_or_target)
      # Check if it's an array of targets (legacy format with multiple targets)
      if user_or_target.is_a?(Array)
        warn '[Vortex SDK] DEPRECATED: Passing an array of targets is deprecated. ' \
             'Use the User format instead: accept_invitations(invitation_ids, { email: "user@example.com" })'

        raise VortexError, 'No targets provided' if user_or_target.empty?

        last_result = nil
        last_exception = nil

        user_or_target.each do |target|
          begin
            last_result = accept_invitations(invitation_ids, target)
          rescue => e
            last_exception = e
          end
        end

        raise last_exception if last_exception

        return last_result || {}
      end

      # Check if it's a legacy target format (has :type and :value keys)
      is_legacy_target = user_or_target.key?(:type) && user_or_target.key?(:value)

      if is_legacy_target
        warn '[Vortex SDK] DEPRECATED: Passing a target hash is deprecated. ' \
             'Use the User format instead: accept_invitations(invitation_ids, { email: "user@example.com" })'

        # Convert target to User format
        target_type = user_or_target[:type]
        target_value = user_or_target[:value]

        user = {}
        case target_type
        when 'email'
          user[:email] = target_value
        when 'phone', 'phoneNumber'
          user[:phone] = target_value
        else
          # For other types, try to use as email
          user[:email] = target_value
        end

        # Recursively call with User format
        return accept_invitations(invitation_ids, user)
      end

      # New User format
      user = user_or_target

      # Validate that either email or phone is provided
      raise VortexError, 'User must have either email or phone' if user[:email].nil? && user[:phone].nil?

      body = {
        invitationIds: invitation_ids,
        user: user.compact # Remove nil values
      }

      response = @connection.post('/api/v1/invitations/accept') do |req|
        req.headers['Content-Type'] = 'application/json'
        req.body = JSON.generate(body)
      end

      handle_response(response)
    rescue VortexError
      raise
    rescue => e
      raise VortexError, "Failed to accept invitations: #{e.message}"
    end

    # Accept a single invitation (recommended method)
    #
    # This is the recommended method for accepting invitations.
    #
    # @param invitation_id [String] Single invitation ID to accept
    # @param user [Hash] User hash with :email and/or :phone
    # @return [Hash] The accepted invitation result
    # @raise [VortexError] If the request fails
    #
    # @example
    #   user = { email: 'user@example.com', name: 'John Doe' }
    #   result = client.accept_invitation('inv-123', user)
    def accept_invitation(invitation_id, user)
      accept_invitations([invitation_id], user)
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

    # Create an invitation from your backend
    #
    # This method allows you to create invitations programmatically using your API key,
    # without requiring a user JWT token. Useful for server-side invitation creation,
    # such as "People You May Know" flows or admin-initiated invitations.
    #
    # Target types:
    # - 'email': Send an email invitation
    # - 'phone': Create a phone invitation (short link returned for you to send)
    # - 'internal': Create an internal invitation for PYMK flows (no email sent)
    #
    # @param widget_configuration_id [String] The widget configuration ID to use
    # @param target [Hash] The invitation target: { type: 'email|sms|internal', value: '...' }
    # @param inviter [Hash] The inviter info: { user_id: '...', user_email: '...', name: '...' }
    # @param groups [Array<Hash>, nil] Optional groups: [{ type: '...', group_id: '...', name: '...' }]
    # @param source [String, nil] Optional source for analytics (defaults to 'api')
    # @param subtype [String, nil] Optional subtype for analytics segmentation (e.g., 'pymk', 'find-friends')
    # @param template_variables [Hash, nil] Optional template variables for email customization
    # @param metadata [Hash, nil] Optional metadata passed through to webhooks
    # @param unfurl_config [Hash, nil] Optional link unfurl (Open Graph) config: { title: '...', description: '...', image: '...', type: '...', site_name: '...' }
    # @return [Hash] Created invitation with :id, :short_link, :status, :created_at
    # @raise [VortexError] If the request fails
    #
    # @example Create an email invitation with custom link preview
    #   result = client.create_invitation(
    #     'widget-config-123',
    #     { type: 'email', value: 'invitee@example.com' },
    #     { user_id: 'user-456', user_email: 'inviter@example.com', name: 'John Doe' },
    #     [{ type: 'team', group_id: 'team-789', name: 'Engineering' }],
    #     nil,
    #     nil,
    #     nil,
    #     { title: 'Join the team!', description: 'You have been invited', image: 'https://example.com/og.png' }
    #   )
    #
    # @example Create an internal invitation (PYMK flow - no email sent)
    #   result = client.create_invitation(
    #     'widget-config-123',
    #     { type: 'internal', value: 'internal-user-abc' },
    #     { user_id: 'user-456' },
    #     nil,
    #     'pymk'
    #   )
    def create_invitation(widget_configuration_id, target, inviter, groups = nil, source = nil, subtype = nil, template_variables = nil, metadata = nil, unfurl_config = nil)
      raise VortexError, 'widget_configuration_id is required' if widget_configuration_id.nil? || widget_configuration_id.empty?
      raise VortexError, 'target must have type and value' if target[:type].nil? || target[:value].nil?
      raise VortexError, 'inviter must have user_id' if inviter[:user_id].nil?

      # Build request body with camelCase keys for the API
      body = {
        widgetConfigurationId: widget_configuration_id,
        target: target,
        inviter: {
          userId: inviter[:user_id],
          userEmail: inviter[:user_email],
          userName: inviter[:user_name],
          userAvatarUrl: inviter[:user_avatar_url]
        }.compact
      }

      if groups && !groups.empty?
        body[:groups] = groups.map do |g|
          {
            type: g[:type],
            groupId: g[:group_id],
            name: g[:name]
          }
        end
      end

      body[:source] = source if source
      body[:subtype] = subtype if subtype
      body[:templateVariables] = template_variables if template_variables
      body[:metadata] = metadata if metadata
      if unfurl_config
        body[:unfurlConfig] = {
          title: unfurl_config[:title],
          description: unfurl_config[:description],
          image: unfurl_config[:image],
          type: unfurl_config[:type],
          siteName: unfurl_config[:site_name]
        }.compact
      end

      response = @connection.post('/api/v1/invitations') do |req|
        req.headers['Content-Type'] = 'application/json'
        req.body = JSON.generate(body)
      end

      handle_response(response)
    rescue VortexError
      raise
    rescue => e
      raise VortexError, "Failed to create invitation: #{e.message}"
    end

    # Get autojoin domains configured for a specific scope
    #
    # @param scope_type [String] The type of scope (e.g., "organization", "team", "project")
    # @param scope [String] The scope identifier (customer's group ID)
    # @return [Hash] Response with :autojoin_domains array and :invitation
    # @raise [VortexError] If the request fails
    #
    # @example
    #   result = client.get_autojoin_domains('organization', 'acme-org')
    #   result['autojoinDomains'].each do |domain|
    #     puts "Domain: #{domain['domain']}"
    #   end
    def get_autojoin_domains(scope_type, scope)
      encoded_scope_type = URI.encode_www_form_component(scope_type)
      encoded_scope = URI.encode_www_form_component(scope)

      response = @connection.get("/api/v1/invitations/by-scope/#{encoded_scope_type}/#{encoded_scope}/autojoin")
      handle_response(response)
    rescue VortexError
      raise
    rescue => e
      raise VortexError, "Failed to get autojoin domains: #{e.message}"
    end

    # Configure autojoin domains for a specific scope
    #
    # This endpoint syncs autojoin domains - it will add new domains, remove domains
    # not in the provided list, and deactivate the autojoin invitation if all domains
    # are removed (empty array).
    #
    # @param scope [String] The scope identifier (customer's group ID)
    # @param scope_type [String] The type of scope (e.g., "organization", "team")
    # @param domains [Array<String>] Array of domains to configure for autojoin
    # @param widget_id [String] The widget configuration ID
    # @param scope_name [String, nil] Optional display name for the scope
    # @param metadata [Hash, nil] Optional metadata to attach to the invitation
    # @return [Hash] Response with :autojoin_domains array and :invitation
    # @raise [VortexError] If the request fails
    #
    # @example
    #   result = client.configure_autojoin(
    #     'acme-org',
    #     'organization',
    #     ['acme.com', 'acme.org'],
    #     'widget-123',
    #     'Acme Corporation'
    #   )
    def configure_autojoin(scope, scope_type, domains, widget_id, scope_name = nil, metadata = nil)
      raise VortexError, 'scope is required' if scope.nil? || scope.empty?
      raise VortexError, 'scope_type is required' if scope_type.nil? || scope_type.empty?
      raise VortexError, 'widget_id is required' if widget_id.nil? || widget_id.empty?
      raise VortexError, 'domains must be an array' unless domains.is_a?(Array)

      body = {
        scope: scope,
        scopeType: scope_type,
        domains: domains,
        widgetId: widget_id
      }

      body[:scopeName] = scope_name if scope_name
      body[:metadata] = metadata if metadata

      response = @connection.post('/api/v1/invitations/autojoin') do |req|
        req.headers['Content-Type'] = 'application/json'
        req.body = JSON.generate(body)
      end

      handle_response(response)
    rescue VortexError
      raise
    rescue => e
      raise VortexError, "Failed to configure autojoin: #{e.message}"
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
        conn.headers['x-vortex-sdk-name'] = 'vortex-ruby-sdk'
        conn.headers['x-vortex-sdk-version'] = Vortex::VERSION
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