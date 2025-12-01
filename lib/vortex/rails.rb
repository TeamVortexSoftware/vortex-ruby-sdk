# frozen_string_literal: true

require 'logger'
require 'vortex/client'
require 'vortex/error'

module Vortex
  module Rails
    # Rails controller integration for Vortex SDK
    #
    # This module provides the same route structure as other SDKs (Express, Java, Python)
    # to ensure complete compatibility with React providers and frontend frameworks.
    #
    # Usage in Rails controller:
    #   class VortexController < ApplicationController
    #     include Vortex::Rails::Controller
    #
    #     private
    #
    #     def authenticate_vortex_user
    #       # Return user data or nil
    #     end
    #
    #     def authorize_vortex_operation(operation, user)
    #       # Return true/false
    #     end
    #
    #     def vortex_client
    #       @vortex_client ||= Vortex::Client.new(ENV['VORTEX_API_KEY'])
    #     end
    #   end
    #
    # Configure logging:
    #   Vortex::Rails.logger = MyLogger.new
    class << self
      attr_writer :logger

      def logger
        @logger ||= defined?(::Rails) ? ::Rails.logger : Logger.new(nil)
      end
    end

    module Controller
      extend ActiveSupport::Concern

      included do
        # Ensure these routes match exactly with other SDKs for React provider compatibility
        rescue_from Vortex::VortexError, with: :handle_vortex_error
      end

      # Generate JWT for authenticated user
      # POST /api/vortex/jwt
      def generate_jwt
        Vortex::Rails.logger.debug("Vortex::Rails::Controller#generate_jwt invoked")

        user = authenticate_vortex_user
        return render_unauthorized('Authentication required') unless user

        unless authorize_vortex_operation('JWT', user)
          Vortex::Rails.logger.warn("Vortex JWT authorization failed for user #{user[:user_id]}")
          return render_forbidden('Not authorized to generate JWT')
        end

        # Extract email from identifiers for the user hash
        email = user[:identifiers]&.find { |i| i[:type] == 'email' }&.dig(:value)

        # Build the JWT
        jwt_params = {
          user: {
            id: user[:user_id],
            email: email
          }
        }

        # Add adminScopes if present
        if user[:admin_scopes]&.any?
          jwt_params[:user][:admin_scopes] = user[:admin_scopes]
        end

        # Add attributes if present
        if user[:attributes]
          jwt_params[:attributes] = user[:attributes]
        end

        jwt = vortex_client.generate_jwt(jwt_params)

        Vortex::Rails.logger.debug("Vortex JWT generated successfully for user #{user[:user_id]}")
        render json: { jwt: jwt }
      rescue Vortex::VortexError => e
        Vortex::Rails.logger.error("Vortex error generating JWT: #{e.message}")
        render_server_error("Failed to generate JWT: #{e.message}")
      rescue StandardError => e
        Vortex::Rails.logger.error("Unexpected error generating JWT: #{e.class} - #{e.message}")
        render_server_error("Unexpected error: #{e.message}")
      end

      # Get invitations by target
      # GET /api/vortex/invitations?targetType=email&targetValue=user@example.com
      def get_invitations_by_target
        Vortex::Rails.logger.debug("Vortex::Rails::Controller#get_invitations_by_target invoked")

        user = authenticate_vortex_user
        return render_unauthorized('Authentication required') unless user

        unless authorize_vortex_operation('GET_INVITATIONS', user)
          return render_forbidden('Not authorized to get invitations')
        end

        target_type = params[:targetType]
        target_value = params[:targetValue]

        return render_bad_request('Missing targetType or targetValue') unless target_type && target_value

        invitations = vortex_client.get_invitations_by_target(target_type, target_value)
        render json: { invitations: invitations }
      rescue Vortex::VortexError => e
        render_server_error("Failed to get invitations: #{e.message}")
      end

      # Get specific invitation by ID
      # GET /api/vortex/invitations/:invitation_id
      def get_invitation
        Vortex::Rails.logger.debug("Vortex::Rails::Controller#get_invitation invoked")

        user = authenticate_vortex_user
        return render_unauthorized('Authentication required') unless user

        unless authorize_vortex_operation('GET_INVITATION', user)
          return render_forbidden('Not authorized to get invitation')
        end

        invitation_id = params[:invitation_id]
        invitation = vortex_client.get_invitation(invitation_id)
        render json: invitation
      rescue Vortex::VortexError => e
        render_not_found("Invitation not found: #{e.message}")
      end

      # Revoke (delete) invitation
      # DELETE /api/vortex/invitations/:invitation_id
      def revoke_invitation
        Vortex::Rails.logger.debug("Vortex::Rails::Controller#revoke_invitation invoked")

        user = authenticate_vortex_user
        return render_unauthorized('Authentication required') unless user

        unless authorize_vortex_operation('REVOKE_INVITATION', user)
          return render_forbidden('Not authorized to revoke invitation')
        end

        invitation_id = params[:invitation_id]
        vortex_client.revoke_invitation(invitation_id)
        render json: { success: true }
      rescue Vortex::VortexError => e
        render_server_error("Failed to revoke invitation: #{e.message}")
      end

      # Accept invitations
      # POST /api/vortex/invitations/accept
      def accept_invitations
        Vortex::Rails.logger.debug("Vortex::Rails::Controller#accept_invitations invoked")

        user = authenticate_vortex_user
        return render_unauthorized('Authentication required') unless user

        unless authorize_vortex_operation('ACCEPT_INVITATIONS', user)
          return render_forbidden('Not authorized to accept invitations')
        end

        invitation_ids = params[:invitationIds]
        target = params[:target]

        unless invitation_ids && target
          return render_bad_request('Missing invitationIds or target')
        end

        result = vortex_client.accept_invitations(invitation_ids, target)
        render json: result
      rescue Vortex::VortexError => e
        render_server_error("Failed to accept invitations: #{e.message}")
      end

      # Get invitations by group
      # GET /api/vortex/invitations/by-group/:group_type/:group_id
      def get_invitations_by_group
        Vortex::Rails.logger.debug("Vortex::Rails::Controller#get_invitations_by_group invoked")

        user = authenticate_vortex_user
        return render_unauthorized('Authentication required') unless user

        unless authorize_vortex_operation('GET_GROUP_INVITATIONS', user)
          return render_forbidden('Not authorized to get group invitations')
        end

        group_type = params[:group_type]
        group_id = params[:group_id]

        invitations = vortex_client.get_invitations_by_group(group_type, group_id)
        render json: { invitations: invitations }
      rescue Vortex::VortexError => e
        render_server_error("Failed to get group invitations: #{e.message}")
      end

      # Delete invitations by group
      # DELETE /api/vortex/invitations/by-group/:group_type/:group_id
      def delete_invitations_by_group
        Vortex::Rails.logger.debug("Vortex::Rails::Controller#delete_invitations_by_group invoked")

        user = authenticate_vortex_user
        return render_unauthorized('Authentication required') unless user

        unless authorize_vortex_operation('DELETE_GROUP_INVITATIONS', user)
          return render_forbidden('Not authorized to delete group invitations')
        end

        group_type = params[:group_type]
        group_id = params[:group_id]

        vortex_client.delete_invitations_by_group(group_type, group_id)
        render json: { success: true }
      rescue Vortex::VortexError => e
        render_server_error("Failed to delete group invitations: #{e.message}")
      end

      # Reinvite user
      # POST /api/vortex/invitations/:invitation_id/reinvite
      def reinvite
        Vortex::Rails.logger.debug("Vortex::Rails::Controller#reinvite invoked")

        user = authenticate_vortex_user
        return render_unauthorized('Authentication required') unless user

        unless authorize_vortex_operation('REINVITE', user)
          return render_forbidden('Not authorized to reinvite')
        end

        invitation_id = params[:invitation_id]
        result = vortex_client.reinvite(invitation_id)
        render json: result
      rescue Vortex::VortexError => e
        render_server_error("Failed to reinvite: #{e.message}")
      end

      private

      # These methods should be implemented in the including controller
      def authenticate_vortex_user
        raise NotImplementedError, 'authenticate_vortex_user must be implemented'
      end

      def authorize_vortex_operation(operation, user)
        raise NotImplementedError, 'authorize_vortex_operation must be implemented'
      end

      def vortex_client
        raise NotImplementedError, 'vortex_client must be implemented'
      end

      # Error response helpers
      def render_unauthorized(message)
        render json: { error: message }, status: :unauthorized
      end

      def render_forbidden(message)
        render json: { error: message }, status: :forbidden
      end

      def render_bad_request(message)
        render json: { error: message }, status: :bad_request
      end

      def render_not_found(message)
        render json: { error: message }, status: :not_found
      end

      def render_server_error(message)
        render json: { error: message }, status: :internal_server_error
      end

      def handle_vortex_error(error)
        render_server_error(error.message)
      end
    end

    # Rails routes helper
    #
    # Usage in routes.rb:
    #   Rails.application.routes.draw do
    #     mount Vortex::Rails.routes => '/api/vortex'
    #   end
    def self.routes
      proc do
        scope '/api/vortex', controller: 'vortex' do
          post 'jwt', action: 'generate_jwt'
          get 'invitations', action: 'get_invitations_by_target'
          get 'invitations/:invitation_id', action: 'get_invitation'
          delete 'invitations/:invitation_id', action: 'revoke_invitation'
          post 'invitations/accept', action: 'accept_invitations'
          get 'invitations/by-group/:group_type/:group_id', action: 'get_invitations_by_group'
          delete 'invitations/by-group/:group_type/:group_id', action: 'delete_invitations_by_group'
          post 'invitations/:invitation_id/reinvite', action: 'reinvite'
        end
      end
    end
  end
end