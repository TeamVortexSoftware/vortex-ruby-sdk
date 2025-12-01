# frozen_string_literal: true

module Vortex
  # Type documentation for Vortex SDK responses
  # Ruby uses dynamic typing with Hashes, but this documents the expected structure
  module Types
    # Group structure for JWT generation (input)
    # @example
    #   {
    #     type: 'workspace',
    #     id: 'workspace-123',       # Legacy field (deprecated, use groupId)
    #     groupId: 'workspace-123',  # Preferred field
    #     name: 'My Workspace'
    #   }
    GROUP_INPUT = {
      type: String,      # Required: Group type (e.g., "workspace", "team")
      id: String,        # Optional: Legacy field (deprecated, use groupId)
      groupId: String,   # Optional: Preferred - Customer's group ID
      name: String       # Required: Group name
    }.freeze

    # InvitationGroup structure from API responses
    # This matches the MemberGroups table structure from the API
    # @example
    #   {
    #     id: '550e8400-e29b-41d4-a716-446655440000',
    #     accountId: '6ba7b810-9dad-11d1-80b4-00c04fd430c8',
    #     groupId: 'workspace-123',
    #     type: 'workspace',
    #     name: 'My Workspace',
    #     createdAt: '2025-01-27T12:00:00.000Z'
    #   }
    INVITATION_GROUP = {
      id: String,          # Vortex internal UUID
      accountId: String,   # Vortex account ID
      groupId: String,     # Customer's group ID (the ID they provided to Vortex)
      type: String,        # Group type (e.g., "workspace", "team")
      name: String,        # Group name
      createdAt: String    # ISO 8601 timestamp when the group was created
    }.freeze

    # Invitation structure from API responses
    # @example
    #   {
    #     id: '550e8400-e29b-41d4-a716-446655440000',
    #     accountId: '6ba7b810-9dad-11d1-80b4-00c04fd430c8',
    #     groups: [INVITATION_GROUP, ...],
    #     # ... other fields
    #   }
    INVITATION = {
      id: String,
      accountId: String,
      clickThroughs: Integer,
      configurationAttributes: Hash,
      attributes: Hash,
      createdAt: String,
      deactivated: :boolean,
      deliveryCount: Integer,
      deliveryTypes: Array, # of String
      foreignCreatorId: String,
      invitationType: String,
      modifiedAt: String,
      status: String,
      target: Array, # of { type: String, value: String }
      views: Integer,
      widgetConfigurationId: String,
      projectId: String,
      groups: Array, # of INVITATION_GROUP structures
      accepts: Array, # of acceptance structures
      expired: :boolean,
      expires: String # ISO 8601 timestamp (optional)
    }.freeze
  end
end
