# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vortex do
  describe '.new' do
    it 'creates a new client instance' do
      client = Vortex.new(test_api_key)
      expect(client).to be_a(Vortex::Client)
    end

    it 'passes base_url option to client' do
      client = Vortex.new(test_api_key, base_url: 'https://custom.api.com')
      expect(client).to be_a(Vortex::Client)
    end
  end

  describe '.version' do
    it 'returns the version string' do
      expect(Vortex.version).to eq(Vortex::VERSION)
      expect(Vortex.version).to match(/\d+\.\d+\.\d+/)
    end
  end

  it 'has a version number' do
    expect(Vortex::VERSION).not_to be_nil
  end
end