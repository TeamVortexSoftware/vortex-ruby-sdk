# Vortex Ruby SDK

A Ruby SDK for the Vortex invitation system, providing seamless integration with the same functionality and API compatibility as other Vortex SDKs (Node.js, Python, Java, Go).

## Features

- **JWT Generation**: Identical algorithm to other SDKs for complete compatibility
- **Simplified JWT Format**: New streamlined payload with `userEmail` and `adminScopes`
- **Backward Compatible**: Legacy JWT format still supported
- **Complete API Coverage**: All invitation management operations
- **Framework Integration**: Built-in Rails and Sinatra helpers
- **Same Route Structure**: Ensures React provider compatibility
- **Comprehensive Testing**: Full test coverage with RSpec
- **Type Safety**: Clear method signatures and documentation
- **Multiple Delivery Types**: Support for `email`, `phone`, `share`, and `internal` invitation delivery
  - `internal` invitations allow for customer-managed, in-app invitation flows with no external communication

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'vortex-ruby-sdk'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install vortex-ruby-sdk
```

## Basic Usage

```ruby
require 'vortex'

# Initialize the client
client = Vortex::Client.new(ENV['VORTEX_API_KEY'])

# Create a user object
user = {
  id: 'user-123',
  email: 'user@example.com',
  user_name: 'Jane Doe',                                    # Optional: user's display name
  user_avatar_url: 'https://example.com/avatars/jane.jpg',  # Optional: user's avatar URL
  admin_scopes: ['autojoin']                                # Optional: grants autojoin admin privileges
}

# Generate JWT
jwt = client.generate_jwt(user: user)

# Get invitations by target
invitations = client.get_invitations_by_target('email', 'user@example.com')

# Accept an invitation
client.accept_invitation('inv-123', { email: 'user@example.com' })

# Get invitations by group
group_invitations = client.get_invitations_by_group('team', 'team1')
```

## Rails Integration

Create a controller with Vortex routes:

```ruby
# app/controllers/vortex_controller.rb
class VortexController < ApplicationController
  include Vortex::Rails::Controller

  private

  def authenticate_vortex_user
    # Return user data hash or nil
    admin_scopes = []
    admin_scopes << 'autojoin' if current_user.admin?

    {
      id: current_user.id,
      email: current_user.email,
      admin_scopes: admin_scopes
    }
  end

  def authorize_vortex_operation(operation, user)
    # Implement your authorization logic
    case operation
    when 'JWT', 'GET_INVITATIONS'
      true
    when 'REVOKE_INVITATION'
      user[:admin_scopes]&.include?('autojoin')
    else
      false
    end
  end

  def vortex_client
    @vortex_client ||= Vortex::Client.new(Rails.application.credentials.vortex_api_key)
  end
end
```

Add routes to `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  scope '/api/vortex', controller: 'vortex' do
    post 'jwt', action: 'generate_jwt'
    get 'invitations', action: 'get_invitations_by_target'
    get 'invitations/:invitation_id', action: 'get_invitation'
    delete 'invitations/:invitation_id', action: 'revoke_invitation'
    post 'invitations/accept', action: 'accept_invitations'
    get 'invitations/by-group/:group_type/:group_id', action: 'get_invitations_by_group'
    delete 'invitations/by-group/:group_type/:group_id', action: 'delete_invitations_by_group'
    post 'invitations/:invitation_id/reinvite', action: 'reinvite'
  end
end
```

## Sinatra Integration

```ruby
require 'sinatra/base'
require 'vortex/sinatra'

class MyApp < Sinatra::Base
  register Vortex::Sinatra

  configure do
    set :vortex_api_key, ENV['VORTEX_API_KEY']
  end

  def authenticate_vortex_user
    # Implement authentication logic
    user_id = request.env['HTTP_X_USER_ID']
    return nil unless user_id

    {
      id: user_id,
      email: 'user@example.com',
      admin_scopes: []  # Optional
    }
  end

  def authorize_vortex_operation(operation, user)
    # Implement authorization logic
    user != nil
  end
end
```

## API Methods

All methods match the functionality of other Vortex SDKs:

### JWT Generation

- `generate_jwt(user:, extra: nil)` - Generate JWT token
  - `user`: Hash with `:id`, `:email`, and optional `:admin_scopes` array
  - `extra`: Optional hash with additional properties to include in JWT payload

### Invitation Management

- `get_invitations_by_target(target_type, target_value)` - Get invitations by target
- `get_invitation(invitation_id)` - Get specific invitation
- `revoke_invitation(invitation_id)` - Revoke invitation
- `accept_invitation(invitation_id, user)` - Accept an invitation
- `get_invitations_by_group(group_type, group_id)` - Get group invitations
- `delete_invitations_by_group(group_type, group_id)` - Delete group invitations
- `reinvite(invitation_id)` - Reinvite user

## Route Structure

The SDK provides these routes (same as other SDKs for React provider compatibility):

- `POST /api/vortex/jwt`
- `GET /api/vortex/invitations?targetType=email&targetValue=user@example.com`
- `GET /api/vortex/invitations/:id`
- `DELETE /api/vortex/invitations/:id`
- `POST /api/vortex/invitations/accept`
- `GET /api/vortex/invitations/by-group/:type/:id`
- `DELETE /api/vortex/invitations/by-group/:type/:id`
- `POST /api/vortex/invitations/:id/reinvite`

## JWT Payload Structure

The SDK generates JWTs with the following payload structure:

```ruby
{
  userId: 'user-123',
  userEmail: 'user@example.com',
  adminScopes: ['autojoin'],  # Full array included if admin_scopes provided
  expires: 1234567890
}
```

Additional properties from the `extra` parameter are merged into the payload.

## Error Handling

All methods raise `Vortex::VortexError` on failures:

```ruby
begin
  jwt = client.generate_jwt(
    user: {
      id: 'user-123',
      email: 'user@example.com'
    }
  )
rescue Vortex::VortexError => e
  logger.error "Vortex error: #{e.message}"
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/vortexsoftware/vortex-ruby-sdk.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
