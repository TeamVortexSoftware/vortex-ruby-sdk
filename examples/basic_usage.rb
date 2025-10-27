#!/usr/bin/env ruby
# frozen_string_literal: true

# Basic usage example for Vortex Ruby SDK
#
# This example demonstrates how to use the core functionality of the Vortex Ruby SDK,
# showing the same operations available in all other Vortex SDKs (Node.js, Python, Java, Go).

require 'bundler/setup'
require 'vortex'

# Initialize the client with your API key
API_KEY = ENV['VORTEX_API_KEY'] || 'your-api-key-here'
client = Vortex::Client.new(API_KEY)

# Example user data - same structure as other SDKs
user_data = {
  user_id: 'user123',
  identifiers: [
    { type: 'email', value: 'user@example.com' }
  ],
  groups: [
    { id: 'team1', type: 'team', name: 'Engineering Team' },
    { id: 'dept1', type: 'department', name: 'Product Development' }
  ],
  role: 'admin'
}

begin
  puts "=== Vortex Ruby SDK Example ==="
  puts

  # 1. Generate JWT
  puts "1. Generating JWT for user..."
  jwt = client.generate_jwt(**user_data)
  puts "JWT generated: #{jwt[0..50]}..."
  puts

  # 2. Get invitations by target
  puts "2. Getting invitations by email target..."
  invitations = client.get_invitations_by_target('email', 'user@example.com')
  puts "Found #{invitations.length} invitation(s)"
  puts

  # 3. Get invitations by group
  puts "3. Getting invitations for team group..."
  group_invitations = client.get_invitations_by_group('team', 'team1')
  puts "Found #{group_invitations.length} group invitation(s)"
  puts

  # 4. Example of accepting invitations (if any exist)
  if invitations.any?
    puts "4. Accepting first invitation..."
    invitation_ids = [invitations.first['id']]
    target = { type: 'email', value: 'user@example.com' }

    result = client.accept_invitations(invitation_ids, target)
    puts "Invitation accepted: #{result['id']}"
  else
    puts "4. No invitations to accept"
  end
  puts

  puts "=== All operations completed successfully! ==="

rescue Vortex::VortexError => e
  puts "Vortex error: #{e.message}"
  exit 1
rescue => e
  puts "Unexpected error: #{e.message}"
  exit 1
end