# Vortex Ruby SDK Implementation Guide

**Gem:** `vortex-ruby-sdk`
**Type:** Base SDK (Core library for Ruby applications)
**Requires:** Ruby 3.0+

## Prerequisites
From integration contract you need: API endpoint prefix, scope entity, authentication pattern
From discovery data you need: Ruby framework (Rails, Sinatra), database ORM, auth pattern

## Key Facts
- Framework-agnostic Ruby SDK
- Client-based: instantiate `Vortex::Client` class and call methods
- Built-in Rails and Sinatra helpers
- Faraday-based HTTP client
- Accept invitations requires custom database logic (must implement)

---

## Step 1: Install

Add to `Gemfile`:
```ruby
gem 'vortex-ruby-sdk'
```

Then install:
```bash
bundle install
```

---

## Step 2: Set Environment Variable

Add to `.env`:

```bash
VORTEX_API_KEY=VRTX.your-api-key-here.secret
```

**Rails:** Use `config/credentials.yml.enc` or `dotenv-rails` gem
**Sinatra:** Use `dotenv` gem

**Never commit API key to version control.**

---

## Step 3: Create Vortex Client

### Rails Initializer (`config/initializers/vortex.rb`):
```ruby
Rails.application.config.vortex = Vortex::Client.new(
  Rails.application.credentials.vortex_api_key || ENV['VORTEX_API_KEY']
)
```

### Rails Concern (`app/controllers/concerns/vortex_helper.rb`):
```ruby
module VortexHelper
  extend ActiveSupport::Concern

  private

  def vortex_client
    @vortex_client ||= Vortex::Client.new(
      Rails.application.credentials.vortex_api_key || ENV['VORTEX_API_KEY']
    )
  end
end
```

### Sinatra Configuration:
```ruby
# app.rb or config.ru
require 'sinatra/base'
require 'vortex'

class MyApp < Sinatra::Base
  configure do
    set :vortex_client, Vortex::Client.new(ENV['VORTEX_API_KEY'])
  end

  helpers do
    def vortex
      settings.vortex_client
    end
  end
end
```

---

## Step 4: Extract Authenticated User

### Rails with Devise:
```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  private

  def current_vortex_user
    return nil unless current_user

    {
      id: current_user.id.to_s,
      email: current_user.email,
      admin_scopes: current_user.admin? ? ['autojoin'] : []
    }
  end

  def require_authentication!
    render json: { error: 'Unauthorized' }, status: :unauthorized unless current_user
  end
end
```

### Rails with JWT:
```ruby
class ApplicationController < ActionController::API
  before_action :authenticate_user_from_token!

  private

  def authenticate_user_from_token!
    token = request.headers['Authorization']&.split(' ')&.last
    return render json: { error: 'Unauthorized' }, status: :unauthorized unless token

    begin
      payload = JWT.decode(token, Rails.application.credentials.secret_key_base, true, algorithm: 'HS256')[0]
      @current_user = User.find(payload['user_id'])
    rescue JWT::DecodeError, ActiveRecord::RecordNotFound
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end

  def current_vortex_user
    return nil unless @current_user

    {
      id: @current_user.id.to_s,
      email: @current_user.email,
      admin_scopes: @current_user.admin? ? ['autojoin'] : []
    }
  end
end
```

### Sinatra:
```ruby
# app/helpers/auth_helper.rb
module AuthHelper
  def current_user
    return @current_user if defined?(@current_user)

    # Session-based
    if session[:user_id]
      @current_user = User.find(session[:user_id])
    # JWT-based
    elsif request.env['HTTP_AUTHORIZATION']
      token = request.env['HTTP_AUTHORIZATION'].split(' ').last
      payload = JWT.decode(token, ENV['SECRET_KEY_BASE'], true, algorithm: 'HS256')[0]
      @current_user = User.find(payload['user_id'])
    end

    @current_user
  rescue
    nil
  end

  def current_vortex_user
    return nil unless current_user

    {
      id: current_user.id.to_s,
      email: current_user.email,
      admin_scopes: current_user.admin? ? ['autojoin'] : []
    }
  end

  def require_authentication!
    halt 401, { error: 'Unauthorized' }.to_json unless current_user
  end
end
```

**Adapt to their patterns:**
- Match their auth mechanism (Devise, JWT, sessions)
- Match their user structure
- Match their admin detection logic

---

## Step 5: Implement JWT Generation Endpoint

### Rails (`app/controllers/vortex_controller.rb`):
```ruby
class VortexController < ApplicationController
  before_action :require_authentication!
  include VortexHelper

  def generate_jwt
    user = current_vortex_user
    extra = params.permit(:componentId, :scope, :scopeType).to_h.compact

    jwt = vortex_client.generate_jwt(
      user: user,
      attributes: extra.empty? ? nil : extra
    )

    render json: { jwt: jwt }
  rescue Vortex::VortexError => e
    Rails.logger.error("JWT generation error: #{e.message}")
    render json: { error: 'Internal server error' }, status: :internal_server_error
  end
end
```

### Sinatra:
```ruby
require 'sinatra/base'
require 'json'

class MyApp < Sinatra::Base
  helpers AuthHelper

  post '/api/vortex/jwt' do
    require_authentication!

    content_type :json

    begin
      user = current_vortex_user
      request_body = JSON.parse(request.body.read) rescue {}

      extra = request_body.slice('componentId', 'scope', 'scopeType').compact
      extra = nil if extra.empty?

      jwt = vortex.generate_jwt(
        user: user,
        attributes: extra
      )

      { jwt: jwt }.to_json
    rescue Vortex::VortexError => e
      logger.error("JWT generation error: #{e.message}")
      status 500
      { error: 'Internal server error' }.to_json
    end
  end
end
```

---

## Step 6: Implement Accept Invitations Endpoint (CRITICAL)

### Rails Routes (`config/routes.rb`):
```ruby
Rails.application.routes.draw do
  namespace :api do
    namespace :vortex do
      post 'jwt', to: 'vortex#generate_jwt'
      get 'invitations', to: 'vortex#get_invitations_by_target'
      get 'invitations/:invitation_id', to: 'vortex#get_invitation'
      post 'invitations/accept', to: 'vortex#accept_invitations'
      delete 'invitations/:invitation_id', to: 'vortex#revoke_invitation'
      post 'invitations/:invitation_id/reinvite', to: 'vortex#reinvite'
    end
  end
end
```

### Rails with ActiveRecord:
```ruby
class Api::VortexController < ApplicationController
  before_action :require_authentication!
  include VortexHelper

  def accept_invitations
    invitation_ids = params[:invitationIds] || []
    user = params[:user]

    return render json: { error: 'Missing invitationIds or user' }, status: :bad_request if invitation_ids.empty? || !user

    begin
      # 1. Mark as accepted in Vortex
      vortex_client.accept_invitations(invitation_ids, user)

      # 2. CRITICAL - Add to database
      ActiveRecord::Base.transaction do
        invitation_ids.each do |invitation_id|
          invitation = vortex_client.get_invitation(invitation_id)

          (invitation['groups'] || []).each do |group|
            GroupMembership.find_or_create_by!(
              user_id: current_user.id,
              group_type: group['type'],
              group_id: group['groupId']
            ) do |membership|
              membership.role = invitation['role'] || 'member'
            end
          end
        end
      end

      render json: {
        success: true,
        acceptedCount: invitation_ids.length
      }
    rescue Vortex::VortexError => e
      Rails.logger.error("Accept invitations error: #{e.message}")
      render json: { error: 'Internal server error' }, status: :internal_server_error
    rescue => e
      Rails.logger.error("Database error: #{e.message}")
      render json: { error: 'Internal server error' }, status: :internal_server_error
    end
  end
end
```

### Sinatra with Sequel:
```ruby
post '/api/vortex/invitations/accept' do
  require_authentication!
  content_type :json

  request_body = JSON.parse(request.body.read)
  invitation_ids = request_body['invitationIds'] || []
  user = request_body['user']

  halt 400, { error: 'Missing invitationIds or user' }.to_json if invitation_ids.empty? || !user

  begin
    # 1. Mark as accepted in Vortex
    vortex.accept_invitations(invitation_ids, user)

    # 2. CRITICAL - Add to database
    DB.transaction do
      invitation_ids.each do |invitation_id|
        invitation = vortex.get_invitation(invitation_id)

        (invitation['groups'] || []).each do |group|
          GroupMembership.insert_conflict(
            target: [:user_id, :group_type, :group_id],
            update: { role: invitation['role'] || 'member' }
          ).insert(
            user_id: current_user.id,
            group_type: group['type'],
            group_id: group['groupId'],
            role: invitation['role'] || 'member',
            joined_at: Time.now
          )
        end
      end
    end

    {
      success: true,
      acceptedCount: invitation_ids.length
    }.to_json
  rescue Vortex::VortexError => e
    logger.error("Accept invitations error: #{e.message}")
    status 500
    { error: 'Internal server error' }.to_json
  end
end
```

**Critical - Adapt database logic:**
- Use their actual table/model names (from discovery)
- Use their actual field names
- Use their ORM pattern (ActiveRecord, Sequel)
- Handle duplicate memberships if needed

---

## Step 7: Database Models

### Rails Migration:
```ruby
# db/migrate/YYYYMMDDHHMMSS_create_group_memberships.rb
class CreateGroupMemberships < ActiveRecord::Migration[7.0]
  def change
    create_table :group_memberships do |t|
      t.string :user_id, null: false
      t.string :group_type, null: false, limit: 100
      t.string :group_id, null: false
      t.string :role, default: 'member', limit: 50
      t.timestamp :joined_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }

      t.index [:user_id, :group_type, :group_id], unique: true, name: 'unique_membership'
      t.index [:group_type, :group_id], name: 'idx_group'
      t.index [:user_id], name: 'idx_user'
    end
  end
end
```

### Rails Model:
```ruby
# app/models/group_membership.rb
class GroupMembership < ApplicationRecord
  validates :user_id, presence: true
  validates :group_type, presence: true
  validates :group_id, presence: true
  validates :role, presence: true

  validates :user_id, uniqueness: { scope: [:group_type, :group_id] }
end
```

### Sequel Migration:
```ruby
# db/migrations/001_create_group_memberships.rb
Sequel.migration do
  change do
    create_table(:group_memberships) do
      primary_key :id
      String :user_id, null: false
      String :group_type, size: 100, null: false
      String :group_id, null: false
      String :role, size: 50, default: 'member'
      DateTime :joined_at, null: false, default: Sequel::CURRENT_TIMESTAMP

      index [:user_id, :group_type, :group_id], unique: true, name: :unique_membership
      index [:group_type, :group_id], name: :idx_group
      index [:user_id], name: :idx_user
    end
  end
end
```

---

## Step 8: Build and Test

```bash
# Run migrations
rails db:migrate  # Rails
sequel -m db/migrations $DATABASE_URL  # Sequel

# Start server
rails server  # Rails
bundle exec rackup  # Sinatra

# Test JWT endpoint
curl -X POST http://localhost:3000/api/vortex/jwt \
  -H "Authorization: Bearer your-auth-token"
```

Expected response:
```json
{
  "jwt": "eyJhbGciOiJIUzI1NiIs..."
}
```

---

## Common Errors

**"LoadError: cannot load such file -- vortex"** → Run `bundle install`

**"VORTEX_API_KEY not set"** → Check `.env` file, credentials, or environment variables

**User not added to database** → Must implement database logic in accept handler (see Step 6)

**"NoMethodError: undefined method `admin?'"** → Implement admin check in User model

**CORS errors** → Add CORS middleware:

**Rails:**
```ruby
# Gemfile
gem 'rack-cors'

# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'http://localhost:3000'
    resource '*', headers: :any, methods: [:get, :post, :delete, :options]
  end
end
```

**Sinatra:**
```ruby
require 'sinatra/cross_origin'

class MyApp < Sinatra::Base
  register Sinatra::CrossOrigin

  configure do
    enable :cross_origin
  end

  options '*' do
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, DELETE, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
    200
  end
end
```

---

## After Implementation Report

List files created/modified:
- Dependency: Gemfile
- Client: config/initializers/vortex.rb (or concern)
- Controller: app/controllers/vortex_controller.rb (or Sinatra routes)
- Model: app/models/group_membership.rb
- Migration: db/migrate/XXX_create_group_memberships.rb

Confirm:
- Vortex gem installed
- VortexClient instance created
- JWT endpoint returns valid JWT
- Accept invitations includes database logic
- Routes registered at correct prefix
- Migrations run

## Endpoints Registered

All endpoints at `/api/vortex`:
- `POST /jwt` - Generate JWT for authenticated user
- `GET /invitations` - Get invitations by target
- `GET /invitations/:id` - Get invitation by ID
- `POST /invitations/accept` - Accept invitations (custom DB logic)
- `DELETE /invitations/:id` - Revoke invitation
- `POST /invitations/:id/reinvite` - Resend invitation
