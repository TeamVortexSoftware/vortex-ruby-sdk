# frozen_string_literal: true

module Vortex
  # Webhook event type constants
  module WebhookEventTypes
    # Invitation Lifecycle
    INVITATION_CREATED = 'invitation.created'
    INVITATION_ACCEPTED = 'invitation.accepted'
    INVITATION_DEACTIVATED = 'invitation.deactivated'
    INVITATION_EMAIL_DELIVERED = 'invitation.email.delivered'
    INVITATION_EMAIL_BOUNCED = 'invitation.email.bounced'
    INVITATION_EMAIL_OPENED = 'invitation.email.opened'
    INVITATION_LINK_CLICKED = 'invitation.link.clicked'
    INVITATION_REMINDER_SENT = 'invitation.reminder.sent'

    # Deployment Lifecycle
    DEPLOYMENT_CREATED = 'deployment.created'
    DEPLOYMENT_DEACTIVATED = 'deployment.deactivated'

    # A/B Testing
    ABTEST_STARTED = 'abtest.started'
    ABTEST_WINNER_DECLARED = 'abtest.winner_declared'

    # Member/Group
    MEMBER_CREATED = 'member.created'
    GROUP_MEMBER_ADDED = 'group.member.added'

    # Email
    EMAIL_COMPLAINED = 'email.complained'

    ALL = [
      INVITATION_CREATED, INVITATION_ACCEPTED, INVITATION_DEACTIVATED,
      INVITATION_EMAIL_DELIVERED, INVITATION_EMAIL_BOUNCED, INVITATION_EMAIL_OPENED,
      INVITATION_LINK_CLICKED, INVITATION_REMINDER_SENT,
      DEPLOYMENT_CREATED, DEPLOYMENT_DEACTIVATED,
      ABTEST_STARTED, ABTEST_WINNER_DECLARED,
      MEMBER_CREATED, GROUP_MEMBER_ADDED,
      EMAIL_COMPLAINED
    ].freeze
  end

  # Analytics event type constants
  module AnalyticsEventTypes
    WIDGET_LOADED = 'widget_loaded'
    INVITATION_SENT = 'invitation_sent'
    INVITATION_CLICKED = 'invitation_clicked'
    INVITATION_ACCEPTED = 'invitation_accepted'
    SHARE_TRIGGERED = 'share_triggered'
  end

  # A Vortex webhook event representing a server-side state change
  #
  # @attr_reader id [String] Unique event ID
  # @attr_reader type [String] The semantic event type
  # @attr_reader timestamp [String] ISO-8601 timestamp
  # @attr_reader account_id [String] The account ID
  # @attr_reader environment_id [String, nil] The environment ID
  # @attr_reader source_table [String] The source table
  # @attr_reader operation [String] The database operation
  # @attr_reader data [Hash] Event-specific payload data
  class WebhookEvent
    attr_reader :id, :type, :timestamp, :account_id, :environment_id,
                :source_table, :operation, :data

    def initialize(attrs)
      @id = attrs['id']
      @type = attrs['type']
      @timestamp = attrs['timestamp']
      @account_id = attrs['accountId']
      @environment_id = attrs['environmentId']
      @source_table = attrs['sourceTable']
      @operation = attrs['operation']
      @data = attrs['data'] || {}
    end
  end

  # An analytics event representing client-side behavioral telemetry
  class AnalyticsEvent
    attr_reader :id, :name, :account_id, :organization_id, :project_id,
                :environment_id, :deployment_id, :widget_configuration_id,
                :foreign_user_id, :session_id, :payload, :platform,
                :segmentation, :timestamp

    def initialize(attrs)
      @id = attrs['id']
      @name = attrs['name']
      @account_id = attrs['accountId']
      @organization_id = attrs['organizationId']
      @project_id = attrs['projectId']
      @environment_id = attrs['environmentId']
      @deployment_id = attrs['deploymentId']
      @widget_configuration_id = attrs['widgetConfigurationId']
      @foreign_user_id = attrs['foreignUserId']
      @session_id = attrs['sessionId']
      @payload = attrs['payload']
      @platform = attrs['platform']
      @segmentation = attrs['segmentation']
      @timestamp = attrs['timestamp']
    end
  end

  # Returns true if the parsed hash is a webhook event
  def self.webhook_event?(parsed)
    parsed.key?('type') && !parsed.key?('name')
  end

  # Returns true if the parsed hash is an analytics event
  def self.analytics_event?(parsed)
    parsed.key?('name')
  end
end
