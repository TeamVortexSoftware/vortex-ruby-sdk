# frozen_string_literal: true

require 'vortex/version'
require 'vortex/error'
require 'vortex/client'

# Vortex Ruby SDK
#
# This gem provides a Ruby interface to the Vortex invitation system,
# with the same functionality and API compatibility as other Vortex SDKs
# (Node.js, Python, Java, Go).
#
# Features:
# - JWT generation with identical algorithm to other SDKs
# - Complete invitation management API
# - Rails and Sinatra framework integrations
# - Same route structure for React provider compatibility
#
# Basic usage:
#   require 'vortex'
#
#   client = Vortex::Client.new(ENV['VORTEX_API_KEY'])
#
#   jwt = client.generate_jwt(
#     user_id: 'user123',
#     identifiers: [{ type: 'email', value: 'user@example.com' }],
#     groups: [{ id: 'team1', type: 'team', name: 'Engineering' }],
#     role: 'admin'
#   )
#
# Framework integrations:
#   # Rails
#   require 'vortex/rails'
#
#   # Sinatra
#   require 'vortex/sinatra'
module Vortex
  class << self
    # Create a new Vortex client instance
    #
    # @param api_key [String] Your Vortex API key
    # @param base_url [String] Custom base URL (optional)
    # @return [Vortex::Client] A new client instance
    def new(api_key, base_url: nil)
      Client.new(api_key, base_url: base_url)
    end

    # Get the current version of the SDK
    #
    # @return [String] Version string
    def version
      VERSION
    end
  end
end