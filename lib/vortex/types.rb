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

    # AcceptUser structure for accepting invitations (new format - preferred)
    # @example
    #   {
    #     email: 'user@example.com',
    #     phone: '+1234567890',      # Optional
    #     name: 'John Doe'           # Optional
    #   }
    ACCEPT_USER = {
      email: String,  # Optional but either email or phone must be provided
      phone: String,  # Optional but either email or phone must be provided
      name: String    # Optional
    }.freeze

    # Invitation structure from API responses
    # @example
    #   {
    #     id: '550e8400-e29b-41d4-a716-446655440000',
    #     accountId: '6ba7b810-9dad-11d1-80b4-00c04fd430c8',
    #     groups: [INVITATION_GROUP, ...],
    #     # ... other fields
    #   }
    # InvitationTarget represents the target of an invitation
    # @example
    #   {
    #     type: 'email',         # 'email', 'phone', 'share', or 'internal'
    #     value: 'user@example.com',
    #     name: 'Jane Smith',    # Optional: Display name of the person being invited
    #     avatarUrl: 'https://...' # Optional: Avatar URL for display in invitation lists
    #   }
    INVITATION_TARGET = {
      type: String,       # Required: 'email', 'phone', 'share', or 'internal'
      value: String,      # Required: Email, phone, or internal ID
      name: String,       # Optional: Display name of the person being invited
      avatarUrl: String   # Optional: Avatar URL for the person being invited
    }.freeze

    INVITATION = {
      id: String,
      accountId: String,
      clickThroughs: Integer,
      configurationAttributes: Hash,
      attributes: Hash,
      createdAt: String,
      deactivated: :boolean,
      deliveryCount: Integer,
      deliveryTypes: Array, # of String - valid values: "email", "phone", "share", "internal"
      foreignCreatorId: String,
      invitationType: String,
      modifiedAt: String,
      status: String,
      target: Array, # of INVITATION_TARGET structures
      views: Integer,
      widgetConfigurationId: String,
      projectId: String,
      groups: Array, # of INVITATION_GROUP structures
      accepts: Array, # of acceptance structures
      expired: :boolean,
      expires: String # ISO 8601 timestamp (optional)
    }.freeze

    # CreateInvitationTarget for creating invitations
    # @example
    #   {
    #     type: 'email',
    #     value: 'invitee@example.com',
    #     name: 'Jane Smith',       # Optional
    #     avatarUrl: 'https://...'  # Optional
    #   }
    CREATE_INVITATION_TARGET = {
      type: String,       # Required: 'email', 'phone', or 'internal'
      value: String,      # Required: Email, phone, or internal ID
      name: String,       # Optional: Display name of the person being invited
      avatarUrl: String   # Optional: Avatar URL for the person being invited
    }.freeze

    # AutojoinDomain structure for autojoin domain configuration
    # @example
    #   {
    #     id: '550e8400-e29b-41d4-a716-446655440000',
    #     domain: 'acme.com'
    #   }
    AUTOJOIN_DOMAIN = {
      id: String,     # Vortex internal UUID
      domain: String  # The domain configured for autojoin
    }.freeze

    # AutojoinDomainsResponse from autojoin API endpoints
    # @example
    #   {
    #     autojoinDomains: [AUTOJOIN_DOMAIN, ...],
    #     invitation: INVITATION  # or nil
    #   }
    AUTOJOIN_DOMAINS_RESPONSE = {
      autojoinDomains: Array,  # Array of AUTOJOIN_DOMAIN structures
      invitation: Hash         # INVITATION structure or nil
    }.freeze

    # ConfigureAutojoinRequest for configuring autojoin domains
    # @example
    #   {
    #     scope: 'acme-org',
    #     scopeType: 'organization',
    #     scopeName: 'Acme Corporation',  # Optional
    #     domains: ['acme.com', 'acme.org'],
    #     widgetId: 'widget-123',
    #     metadata: { ... }  # Optional
    #   }
    CONFIGURE_AUTOJOIN_REQUEST = {
      scope: String,       # Required: Customer's group ID
      scopeType: String,   # Required: Type of scope (e.g., "organization", "team")
      scopeName: String,   # Optional: Display name for the scope
      domains: Array,      # Required: Array of domain strings
      widgetId: String,    # Required: Widget configuration ID
      metadata: Hash       # Optional: Metadata to attach to the invitation
    }.freeze
  end
end
