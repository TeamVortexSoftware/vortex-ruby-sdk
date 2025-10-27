# frozen_string_literal: true

require 'json'
require 'vortex/client'
require 'vortex/error'

module Vortex
  module Sinatra
    # Sinatra application integration for Vortex SDK
    #
    # This module provides the same route structure as other SDKs (Express, Java, Python)
    # to ensure complete compatibility with React providers and frontend frameworks.
    #
    # Usage in Sinatra app:
    #   require 'sinatra/base'
    #   require 'vortex/sinatra'
    #
    #   class MyApp < Sinatra::Base
    #     register Vortex::Sinatra
    #
    #     configure do
    #       set :vortex_api_key, ENV['VORTEX_API_KEY']
    #       set :vortex_base_url, ENV['VORTEX_BASE_URL'] # optional
    #     end
    #
    #     # Implement authentication callbacks
    #     def authenticate_vortex_user
    #       # Return user hash or nil
    #     end
    #
    #     def authorize_vortex_operation(operation, user)
    #       # Return true/false
    #     end
    #   end
    def self.registered(app)
      app.helpers Helpers

      # Ensure these routes match exactly with other SDKs for React provider compatibility

      # Generate JWT for authenticated user
      # POST /api/vortex/jwt
      app.post '/api/vortex/jwt' do
        with_vortex_error_handling do
          user = authenticate_vortex_user
          return render_unauthorized('Authentication required') unless user

          unless authorize_vortex_operation('JWT', user)
            return render_forbidden('Not authorized to generate JWT')
          end

          jwt = vortex_client.generate_jwt(
            user_id: user[:user_id],
            identifiers: user[:identifiers],
            groups: user[:groups],
            role: user[:role]
          )

          render_json({ jwt: jwt })
        end
      end

      # Get invitations by target
      # GET /api/vortex/invitations?targetType=email&targetValue=user@example.com
      app.get '/api/vortex/invitations' do
        with_vortex_error_handling do
          user = authenticate_vortex_user
          return render_unauthorized('Authentication required') unless user

          unless authorize_vortex_operation('GET_INVITATIONS', user)
            return render_forbidden('Not authorized to get invitations')
          end

          target_type = params['targetType']
          target_value = params['targetValue']

          unless target_type && target_value
            return render_bad_request('Missing targetType or targetValue')
          end

          invitations = vortex_client.get_invitations_by_target(target_type, target_value)
          render_json({ invitations: invitations })
        end
      end

      # Get specific invitation by ID
      # GET /api/vortex/invitations/:invitation_id
      app.get '/api/vortex/invitations/:invitation_id' do
        with_vortex_error_handling do
          user = authenticate_vortex_user
          return render_unauthorized('Authentication required') unless user

          unless authorize_vortex_operation('GET_INVITATION', user)
            return render_forbidden('Not authorized to get invitation')
          end

          invitation_id = params['invitation_id']
          invitation = vortex_client.get_invitation(invitation_id)
          render_json(invitation)
        end
      end

      # Revoke (delete) invitation
      # DELETE /api/vortex/invitations/:invitation_id
      app.delete '/api/vortex/invitations/:invitation_id' do
        with_vortex_error_handling do
          user = authenticate_vortex_user
          return render_unauthorized('Authentication required') unless user

          unless authorize_vortex_operation('REVOKE_INVITATION', user)
            return render_forbidden('Not authorized to revoke invitation')
          end

          invitation_id = params['invitation_id']
          vortex_client.revoke_invitation(invitation_id)
          render_json({ success: true })
        end
      end

      # Accept invitations
      # POST /api/vortex/invitations/accept
      app.post '/api/vortex/invitations/accept' do
        with_vortex_error_handling do
          user = authenticate_vortex_user
          return render_unauthorized('Authentication required') unless user

          unless authorize_vortex_operation('ACCEPT_INVITATIONS', user)
            return render_forbidden('Not authorized to accept invitations')
          end

          request_body = parse_json_body

          invitation_ids = request_body['invitationIds']
          target = request_body['target']

          unless invitation_ids && target
            return render_bad_request('Missing invitationIds or target')
          end

          result = vortex_client.accept_invitations(invitation_ids, target)
          render_json(result)
        end
      end

      # Get invitations by group
      # GET /api/vortex/invitations/by-group/:group_type/:group_id
      app.get '/api/vortex/invitations/by-group/:group_type/:group_id' do
        with_vortex_error_handling do
          user = authenticate_vortex_user
          return render_unauthorized('Authentication required') unless user

          unless authorize_vortex_operation('GET_GROUP_INVITATIONS', user)
            return render_forbidden('Not authorized to get group invitations')
          end

          group_type = params['group_type']
          group_id = params['group_id']

          invitations = vortex_client.get_invitations_by_group(group_type, group_id)
          render_json({ invitations: invitations })
        end
      end

      # Delete invitations by group
      # DELETE /api/vortex/invitations/by-group/:group_type/:group_id
      app.delete '/api/vortex/invitations/by-group/:group_type/:group_id' do
        with_vortex_error_handling do
          user = authenticate_vortex_user
          return render_unauthorized('Authentication required') unless user

          unless authorize_vortex_operation('DELETE_GROUP_INVITATIONS', user)
            return render_forbidden('Not authorized to delete group invitations')
          end

          group_type = params['group_type']
          group_id = params['group_id']

          vortex_client.delete_invitations_by_group(group_type, group_id)
          render_json({ success: true })
        end
      end

      # Reinvite user
      # POST /api/vortex/invitations/:invitation_id/reinvite
      app.post '/api/vortex/invitations/:invitation_id/reinvite' do
        with_vortex_error_handling do
          user = authenticate_vortex_user
          return render_unauthorized('Authentication required') unless user

          unless authorize_vortex_operation('REINVITE', user)
            return render_forbidden('Not authorized to reinvite')
          end

          invitation_id = params['invitation_id']
          result = vortex_client.reinvite(invitation_id)
          render_json(result)
        end
      end

      # Configure Vortex client
      app.configure do
        unless app.respond_to?(:vortex_client)
          app.set :vortex_client, nil
        end
      end
    end

    # Helper methods for Sinatra apps using Vortex
    module Helpers
      def vortex_client
        @vortex_client ||= begin
          api_key = settings.vortex_api_key
          base_url = settings.respond_to?(:vortex_base_url) ? settings.vortex_base_url : nil

          raise 'Vortex API key not configured' unless api_key

          Vortex::Client.new(api_key, base_url: base_url)
        end
      end

      def authenticate_vortex_user
        # Default implementation - should be overridden in app
        nil
      end

      def authorize_vortex_operation(operation, user)
        # Default implementation - should be overridden in app
        user != nil
      end

      def with_vortex_error_handling(&block)
        yield
      rescue Vortex::VortexError => e
        logger.error("Vortex error: #{e.message}") if respond_to?(:logger)
        render_server_error("Vortex error: #{e.message}")
      rescue => e
        logger.error("Unexpected error: #{e.message}") if respond_to?(:logger)
        render_server_error("Internal server error")
      end

      def parse_json_body
        request.body.rewind
        body = request.body.read
        return {} if body.empty?

        JSON.parse(body)
      rescue JSON::ParserError
        halt 400, render_json({ error: 'Invalid JSON in request body' })
      end

      def render_json(data)
        content_type :json
        JSON.generate(data)
      end

      def render_unauthorized(message)
        halt 401, render_json({ error: message })
      end

      def render_forbidden(message)
        halt 403, render_json({ error: message })
      end

      def render_bad_request(message)
        halt 400, render_json({ error: message })
      end

      def render_not_found(message)
        halt 404, render_json({ error: message })
      end

      def render_server_error(message)
        halt 500, render_json({ error: message })
      end
    end
  end
end