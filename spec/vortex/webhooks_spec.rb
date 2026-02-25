# frozen_string_literal: true

require 'spec_helper'
require 'openssl'
require 'json'

RSpec.describe Vortex::Webhooks do
  let(:secret) { 'whsec_test_secret_123' }
  let(:webhooks) { described_class.new(secret: secret) }

  let(:webhook_event_payload) do
    JSON.generate({
      'id' => 'evt_123',
      'type' => 'invitation.accepted',
      'timestamp' => '2025-01-15T12:00:00.000Z',
      'accountId' => 'acc_123',
      'environmentId' => 'env_456',
      'sourceTable' => 'invitations',
      'operation' => 'update',
      'data' => { 'invitationId' => 'inv_789', 'targetEmail' => 'user@example.com' }
    })
  end

  let(:analytics_event_payload) do
    JSON.generate({
      'id' => 'evt_456',
      'name' => 'widget_loaded',
      'accountId' => 'acc_123',
      'organizationId' => 'org_123',
      'projectId' => 'proj_123',
      'environmentId' => 'env_456',
      'timestamp' => '2025-01-15T12:00:00.000Z'
    })
  end

  def sign(payload, sec = secret)
    OpenSSL::HMAC.hexdigest('SHA256', sec, payload)
  end

  describe '.new' do
    it 'raises ArgumentError for empty secret' do
      expect { described_class.new(secret: '') }.to raise_error(ArgumentError)
    end

    it 'raises ArgumentError for nil secret' do
      expect { described_class.new(secret: nil) }.to raise_error(ArgumentError)
    end
  end

  describe '#verify_signature' do
    it 'returns true for valid signature' do
      expect(webhooks.verify_signature(webhook_event_payload, sign(webhook_event_payload))).to be true
    end

    it 'returns false for invalid signature' do
      expect(webhooks.verify_signature(webhook_event_payload, 'bad_sig')).to be false
    end

    it 'returns false for empty signature' do
      expect(webhooks.verify_signature(webhook_event_payload, '')).to be false
    end

    it 'returns false for wrong secret' do
      expect(webhooks.verify_signature(webhook_event_payload, sign(webhook_event_payload, 'wrong'))).to be false
    end
  end

  describe '#construct_event' do
    it 'returns a WebhookEvent for webhook payloads' do
      sig = sign(webhook_event_payload)
      event = webhooks.construct_event(webhook_event_payload, sig)
      expect(event).to be_a(Vortex::WebhookEvent)
      expect(event.id).to eq('evt_123')
      expect(event.type).to eq('invitation.accepted')
      expect(event.account_id).to eq('acc_123')
    end

    it 'returns an AnalyticsEvent for analytics payloads' do
      sig = sign(analytics_event_payload)
      event = webhooks.construct_event(analytics_event_payload, sig)
      expect(event).to be_a(Vortex::AnalyticsEvent)
      expect(event.name).to eq('widget_loaded')
    end

    it 'raises WebhookSignatureError for bad signature' do
      expect { webhooks.construct_event(webhook_event_payload, 'bad') }
        .to raise_error(Vortex::WebhookSignatureError)
    end
  end
end
