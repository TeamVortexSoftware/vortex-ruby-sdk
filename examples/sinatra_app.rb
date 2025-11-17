#!/usr/bin/env ruby
# frozen_string_literal: true

# Sinatra application example for Vortex Ruby SDK
#
# This example shows how to integrate the Vortex SDK with a Sinatra application,
# providing the same API routes as other SDK integrations (Express, Java Spring, Python Flask).

require 'bundler/setup'
require 'sinatra/base'
require 'json'
require 'vortex/sinatra'

class VortexSinatraApp < Sinatra::Base
  register Vortex::Sinatra

  configure do
    set :vortex_api_key, ENV['VORTEX_API_KEY'] || 'your-api-key-here'
    set :vortex_base_url, ENV['VORTEX_BASE_URL'] # optional
  end

  # Implement user authentication
  def authenticate_vortex_user
    # Example: get user from headers/session/JWT
    user_id = request.env['HTTP_X_USER_ID'] || 'demo-user'
    return nil unless user_id

    # Build admin_scopes array
    admin_scopes = []
    admin_scopes << 'autoJoin' if request.env['HTTP_X_USER_ROLE'] == 'admin'

    # Return user data
    {
      id: user_id,
      email: request.env['HTTP_X_USER_EMAIL'] || 'demo@example.com',
      admin_scopes: admin_scopes
    }
  end

  # Implement authorization
  def authorize_vortex_operation(operation, user)
    case operation
    when 'JWT'
      true # Everyone can generate JWT if authenticated
    when 'GET_INVITATIONS', 'GET_INVITATION'
      true # Everyone can view invitations
    when 'ACCEPT_INVITATIONS'
      true # Everyone can accept invitations
    when 'REVOKE_INVITATION', 'DELETE_GROUP_INVITATIONS'
      user[:admin_scopes]&.include?('autoJoin') # Only admins can delete
    when 'GET_GROUP_INVITATIONS', 'REINVITE'
      user[:admin_scopes]&.include?('autoJoin') # Only admins can manage groups
    else
      false
    end
  end

  # Health check endpoint
  get '/health' do
    content_type :json
    { status: 'OK', version: Vortex::VERSION }.to_json
  end

  # Root endpoint with API documentation
  get '/' do
    content_type :json
    {
      name: 'Vortex Sinatra API',
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
  end

  # Error handlers
  error Vortex::VortexError do
    content_type :json
    status 500
    { error: env['sinatra.error'].message }.to_json
  end

  error do
    content_type :json
    status 500
    { error: 'Internal server error' }.to_json
  end
end

if __FILE__ == $0
  puts "🚀 Starting Vortex Sinatra API server..."
  puts "📊 Health check: http://localhost:4567/health"
  puts "🔧 Vortex API routes available at http://localhost:4567/api/vortex"
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
  puts
  puts "Authentication headers (for testing):"
  puts "  X-User-ID: your-user-id"
  puts "  X-User-Email: your-email@example.com"
  puts "  X-User-Role: user|admin"

  VortexSinatraApp.run!
end