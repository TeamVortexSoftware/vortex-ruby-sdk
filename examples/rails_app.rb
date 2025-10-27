#!/usr/bin/env ruby
# frozen_string_literal: true

# Rails application example for Vortex Ruby SDK
#
# This example shows how to integrate the Vortex SDK with a Rails application,
# providing the same API routes as other SDK integrations (Express, Java Spring, Python Flask).

# Gemfile additions needed:
# gem 'rails', '~> 7.0'
# gem 'vortex-ruby-sdk'

require 'rails'
require 'action_controller/railtie'
require 'vortex/rails'

class VortexExampleApp < Rails::Application
  config.api_only = true
  config.eager_load = false
  config.logger = Logger.new(STDOUT)
end

# Example Vortex controller with authentication
class VortexController < ActionController::Base
  include Vortex::Rails::Controller

  private

  # Implement user authentication - return user data hash or nil
  def authenticate_vortex_user
    # Example: get user from session/JWT/etc.
    user_id = session[:user_id] || request.headers['X-User-ID']
    return nil unless user_id

    # Return user data in the format expected by Vortex
    {
      user_id: user_id,
      identifiers: [
        { type: 'email', value: session[:user_email] || 'user@example.com' }
      ],
      groups: [
        { id: 'team1', type: 'team', name: 'Engineering' }
      ],
      role: session[:user_role] || 'user'
    }
  end

  # Implement authorization - return true/false
  def authorize_vortex_operation(operation, user)
    # Example: check user permissions
    case operation
    when 'JWT'
      true # Everyone can generate JWT if authenticated
    when 'GET_INVITATIONS', 'GET_INVITATION'
      true # Everyone can view invitations
    when 'ACCEPT_INVITATIONS'
      true # Everyone can accept invitations
    when 'REVOKE_INVITATION', 'DELETE_GROUP_INVITATIONS'
      user[:role] == 'admin' # Only admins can delete
    when 'GET_GROUP_INVITATIONS', 'REINVITE'
      user[:role] == 'admin' # Only admins can manage groups
    else
      false
    end
  end

  # Provide Vortex client instance
  def vortex_client
    @vortex_client ||= Vortex::Client.new(
      ENV['VORTEX_API_KEY'] || 'your-api-key-here'
    )
  end
end

# Configure routes - these match exactly with other SDK routes
Rails.application.routes.draw do
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

  # Health check
  get '/health', to: proc { [200, {}, ['OK']] }

  # Root route with API documentation
  root to: proc do
    [200, { 'Content-Type' => 'application/json' }, [
      {
        name: 'Vortex Rails API',
        version: Vortex::VERSION,
        endpoints: {
          jwt: 'POST /api/vortex/jwt',
          invitations: 'GET /api/vortex/invitations?targetType=email&targetValue=user@example.com',
          invitation: 'GET /api/vortex/invitations/:id',
          revoke: 'DELETE /api/vortex/invitations/:id',
          accept: 'POST /api/vortex/invitations/accept',
          group_invitations: 'GET /api/vortex/invitations/by-group/:type/:id',
          delete_group: 'DELETE /api/vortex/invitations/by-group/:type/:id',
          reinvite: 'POST /api/vortex/invitations/:id/reinvite'
        }
      }.to_json
    ]]
  end
end

if __FILE__ == $0
  puts "🚀 Starting Vortex Rails API server..."
  puts "📊 Health check: http://localhost:3000/health"
  puts "🔧 Vortex API routes available at http://localhost:3000/api/vortex"
  puts
  puts "Available endpoints:"
  puts "  POST /api/vortex/jwt"
  puts "  GET  /api/vortex/invitations?targetType=email&targetValue=user@example.com"
  puts "  GET  /api/vortex/invitations/:id"
  puts "  DELETE /api/vortex/invitations/:id"
  puts "  POST /api/vortex/invitations/accept"
  puts "  GET  /api/vortex/invitations/by-group/:type/:id"
  puts "  DELETE /api/vortex/invitations/by-group/:type/:id"
  puts "  POST /api/vortex/invitations/:id/reinvite"

  Rails.application.initialize!
  Rails.application.run(Port: 3000)
end