# frozen_string_literal: true

module Vortex
  # Custom error class for Vortex SDK exceptions
  #
  # All Vortex-related errors inherit from this class, making it easy
  # to catch and handle Vortex-specific exceptions.
  class VortexError < StandardError
    # @param message [String] Error message
    # @param cause [Exception, nil] Original exception that caused this error
    def initialize(message = nil, cause = nil)
      super(message)
      @cause = cause
    end

    # @return [Exception, nil] The original exception that caused this error
    attr_reader :cause
  end
end