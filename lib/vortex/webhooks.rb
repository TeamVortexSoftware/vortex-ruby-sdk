# frozen_string_literal: true

require 'openssl'
require 'json'

module Vortex
  # Error raised when webhook signature verification fails
  class WebhookSignatureError < VortexError
    def initialize(message = nil)
      super(message || 'Webhook signature verification failed. Ensure you are using the raw request body and the correct signing secret.')
    end
  end

  # Core webhook verification and parsing.
  #
  # This class is framework-agnostic — use it directly or with
  # the Rails/Sinatra framework integrations.
  #
  # @example
  #   webhooks = Vortex::Webhooks.new(secret: ENV['VORTEX_WEBHOOK_SECRET'])
  #   event = webhooks.construct_event(request.body.read, request.env['HTTP_X_VORTEX_SIGNATURE'])
  class Webhooks
    # @param secret [String] The webhook signing secret from your Vortex dashboard
    def initialize(secret:)
      raise ArgumentError, 'Vortex::Webhooks requires a secret' if secret.nil? || secret.empty?

      @secret = secret
    end

    # Verify the HMAC-SHA256 signature of an incoming webhook payload.
    #
    # @param payload [String] The raw request body
    # @param signature [String] The value of the X-Vortex-Signature header
    # @return [Boolean] true if the signature is valid
    def verify_signature(payload, signature)
      return false if signature.nil? || signature.empty?

      expected = OpenSSL::HMAC.hexdigest('SHA256', @secret, payload)

      # Timing-safe comparison to prevent timing attacks
      secure_compare(signature, expected)
    end

    # Verify and parse an incoming webhook payload.
    #
    # @param payload [String] The raw request body
    # @param signature [String] The value of the X-Vortex-Signature header
    # @return [WebhookEvent, AnalyticsEvent] A typed event object
    # @raise [WebhookSignatureError] If the signature is invalid
    def construct_event(payload, signature)
      raise WebhookSignatureError unless verify_signature(payload, signature)

      parsed = JSON.parse(payload)

      if Vortex.webhook_event?(parsed)
        WebhookEvent.new(parsed)
      elsif Vortex.analytics_event?(parsed)
        AnalyticsEvent.new(parsed)
      else
        WebhookEvent.new(parsed)
      end
    end

    private

    # Timing-safe string comparison
    def secure_compare(a, b)
      return false unless a.bytesize == b.bytesize

      OpenSSL.fixed_length_secure_compare(a, b)
    rescue StandardError
      false
    end
  end
end
