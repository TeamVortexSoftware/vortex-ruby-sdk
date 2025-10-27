# Publishing the Vortex Ruby SDK to RubyGems

This guide walks you through publishing the Vortex Ruby SDK to RubyGems so users can install it with `gem install vortex-ruby-sdk`.

## Overview

RubyGems.org is the primary package repository for Ruby. Publishing is straightforward and requires:
- A RubyGems account
- A properly configured `.gemspec` file
- The `gem` command-line tool

## Prerequisites

### 1. RubyGems Account

1. Create an account at [RubyGems.org](https://rubygems.org/sign_up)
2. Verify your email address

### 2. Configure RubyGems Credentials

```bash
# The first time you push a gem, you'll be prompted for credentials
# Or configure manually:
gem signin
```

This creates `~/.gem/credentials` with your API key.

### 3. Verify Ruby and Bundler

```bash
ruby --version  # Should be >= 3.0.0
bundler --version
gem --version
```

## Publishing Process

### Step 1: Verify Gemspec Configuration

The `.gemspec` file has been configured with:
- ✅ Name, version, authors, email
- ✅ Summary and description
- ✅ Homepage and source URLs
- ✅ License (MIT)
- ✅ Ruby version requirement (>= 3.0.0)
- ✅ Dependencies
- ✅ Metadata for RubyGems.org

Current gemspec: [vortex-ruby-sdk.gemspec](vortex-ruby-sdk.gemspec)

### Step 2: Update Version

Edit [lib/vortex/version.rb](lib/vortex/version.rb:4):

```ruby
module Vortex
  VERSION = '1.0.0'
end
```

### Step 3: Update CHANGELOG

Create or update `CHANGELOG.md` with release notes:

```markdown
## [1.0.0] - 2025-01-15

### Added
- Initial release
- JWT generation
- Invitation management
- Group operations
```

### Step 4: Install Dependencies and Test

```bash
cd packages/vortex-ruby-sdk

# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run RuboCop for code quality
bundle exec rubocop

# Generate documentation
bundle exec yard doc
```

### Step 5: Build the Gem

```bash
# Build the gem
gem build vortex-ruby-sdk.gemspec
```

This creates a `.gem` file:
```
vortex-ruby-sdk-1.0.0.gem
```

### Step 6: Test the Gem Locally

```bash
# Install locally to test
gem install ./vortex-ruby-sdk-1.0.0.gem

# Test in IRB
irb
> require 'vortex'
> client = Vortex::Client.new('test-key')
> # Test basic functionality
```

### Step 7: Publish to RubyGems

```bash
# Push to RubyGems.org
gem push vortex-ruby-sdk-1.0.0.gem
```

You'll be prompted for credentials if not already signed in.

### Step 8: Verify Publication

After publishing:

1. Check [RubyGems.org](https://rubygems.org/gems/vortex-ruby-sdk)
2. Test installation:
   ```bash
   gem install vortex-ruby-sdk
   ```

## Installation for Users

Once published, users can install with:

```bash
gem install vortex-ruby-sdk
```

Or in a Gemfile:

```ruby
gem 'vortex-ruby-sdk', '~> 1.0'
```

Then:

```bash
bundle install
```

## Automated Publishing with GitHub Actions

Create `.github/workflows/publish-ruby.yml`:

```yaml
name: Publish Ruby Gem

on:
  release:
    types: [published]
  workflow_dispatch:

jobs:
  publish:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.0'
          bundler-cache: true

      - name: Install dependencies
        run: |
          cd packages/vortex-ruby-sdk
          bundle install

      - name: Run tests
        run: |
          cd packages/vortex-ruby-sdk
          bundle exec rspec

      - name: Run RuboCop
        run: |
          cd packages/vortex-ruby-sdk
          bundle exec rubocop

      - name: Build gem
        run: |
          cd packages/vortex-ruby-sdk
          gem build vortex-ruby-sdk.gemspec

      - name: Publish to RubyGems
        env:
          GEM_HOST_API_KEY: ${{ secrets.RUBYGEMS_API_KEY }}
        run: |
          cd packages/vortex-ruby-sdk
          gem push *.gem
```

### GitHub Secrets Setup

Add this secret to your repository:
- `RUBYGEMS_API_KEY` - Your RubyGems API key

To get your API key:
1. Go to [RubyGems.org Profile](https://rubygems.org/profile/edit)
2. Click "API Keys"
3. Create a new key with "Push rubygems" scope

## Version Management

Follow [Semantic Versioning](https://semver.org/):

- **MAJOR** (1.0.0 → 2.0.0): Breaking API changes
- **MINOR** (1.0.0 → 1.1.0): New features, backward compatible
- **PATCH** (1.0.0 → 1.0.1): Bug fixes, backward compatible

### Pre-release Versions

For beta or RC releases:

```ruby
VERSION = '1.0.0.beta1'
VERSION = '1.0.0.rc1'
```

Users install with:
```bash
gem install vortex-ruby-sdk --pre
```

## Gemspec Best Practices

### Required Fields

- ✅ `name` - Gem name (must be unique on RubyGems.org)
- ✅ `version` - Current version
- ✅ `authors` - Author names
- ✅ `email` - Contact email
- ✅ `summary` - Short description
- ✅ `description` - Longer description
- ✅ `homepage` - Project homepage
- ✅ `license` - License identifier
- ✅ `files` - Files to include in gem

### Metadata

The gemspec includes metadata for better discoverability:

```ruby
spec.metadata = {
  'homepage_uri' => spec.homepage,
  'source_code_uri' => spec.homepage,
  'changelog_uri' => "#{spec.homepage}/blob/main/CHANGELOG.md",
  'bug_tracker_uri' => "#{spec.homepage}/issues",
  'documentation_uri' => "https://www.rubydoc.info/gems/vortex-ruby-sdk"
}
```

### Dependencies

Runtime dependencies:
```ruby
spec.add_dependency 'faraday', '~> 2.0'
spec.add_dependency 'rack', '>= 2.0'
```

Development dependencies:
```ruby
spec.add_development_dependency 'rspec', '~> 3.0'
spec.add_development_dependency 'rubocop', '~> 1.0'
```

## Managing Gem Ownership

### Add Collaborators

```bash
gem owner vortex-ruby-sdk --add email@example.com
```

### Remove Collaborators

```bash
gem owner vortex-ruby-sdk --remove email@example.com
```

## Yanking a Release

If you need to remove a published version:

```bash
gem yank vortex-ruby-sdk -v 1.0.0
```

**Note**: Yanking doesn't delete the gem, it just prevents new installations. Existing users can still use it.

## Documentation

### YARD Documentation

The SDK uses YARD for documentation:

```bash
# Generate docs
bundle exec yard doc

# Serve locally
bundle exec yard server
```

Published gems automatically get documentation at [RubyDoc.info](https://www.rubydoc.info/).

### README

Ensure [README.md](README.md) includes:
- Installation instructions
- Quick start guide
- API examples
- Configuration options
- License information

## Testing Before Release

### Local Testing Workflow

```bash
# 1. Build gem
gem build vortex-ruby-sdk.gemspec

# 2. Install locally
gem install ./vortex-ruby-sdk-1.0.0.gem --local

# 3. Test in a new directory
mkdir /tmp/test-vortex
cd /tmp/test-vortex

# 4. Create test script
cat > test.rb << 'EOF'
require 'vortex'
client = Vortex::Client.new('test-key')
puts "SDK loaded successfully!"
EOF

# 5. Run test
ruby test.rb

# 6. Uninstall
gem uninstall vortex-ruby-sdk
```

## Troubleshooting

### Common Issues

#### 1. Name Already Taken

If the gem name is taken, you'll need to choose a different name. Check availability:

```bash
gem search ^vortex-ruby-sdk$ --remote
```

#### 2. Authentication Errors

```bash
# Re-authenticate
gem signin

# Or set credentials manually
mkdir -p ~/.gem
echo "---
:rubygems_api_key: YOUR_API_KEY" > ~/.gem/credentials
chmod 0600 ~/.gem/credentials
```

#### 3. Version Conflicts

You cannot push the same version twice. Increment the version and rebuild:

```ruby
# lib/vortex/version.rb
VERSION = '1.0.1'
```

#### 4. Missing Files

If files are missing from the gem:

```bash
# List files in built gem
gem unpack vortex-ruby-sdk-1.0.0.gem
ls -la vortex-ruby-sdk-1.0.0/
```

Adjust the `files` specification in the gemspec.

## Release Checklist

- [ ] Update version in `lib/vortex/version.rb`
- [ ] Update `CHANGELOG.md` with release notes
- [ ] Update `README.md` if needed
- [ ] Run all tests: `bundle exec rspec`
- [ ] Run RuboCop: `bundle exec rubocop`
- [ ] Generate and review docs: `bundle exec yard doc`
- [ ] Build gem: `gem build vortex-ruby-sdk.gemspec`
- [ ] Test locally: `gem install ./vortex-ruby-sdk-X.Y.Z.gem`
- [ ] Commit version bump: `git commit -am "Bump version to X.Y.Z"`
- [ ] Create Git tag: `git tag vX.Y.Z`
- [ ] Push changes: `git push && git push --tags`
- [ ] Publish gem: `gem push vortex-ruby-sdk-X.Y.Z.gem`
- [ ] Verify on RubyGems.org
- [ ] Create GitHub release with changelog
- [ ] Announce release

## Security Best Practices

1. **Protect API keys**: Never commit `~/.gem/credentials` to Git
2. **Use GitHub Secrets**: For automated publishing
3. **Scope API keys**: Use minimal permissions
4. **MFA**: Enable on RubyGems.org account
5. **Code signing**: Consider signing gems with GPG

## Post-Publication

After publishing:

1. **Monitor downloads**: Check stats on RubyGems.org
2. **Watch for issues**: Monitor GitHub issues
3. **Update documentation**: Ensure all docs reference correct version
4. **Announce**: Share release on relevant channels
5. **Monitor dependencies**: Keep dependencies updated

## Resources

- [RubyGems.org Guides](https://guides.rubygems.org/)
- [Publishing Your Gem](https://guides.rubygems.org/publishing/)
- [Patterns and Best Practices](https://guides.rubygems.org/patterns/)
- [Gem Specification Reference](https://guides.rubygems.org/specification-reference/)
- [Semantic Versioning](https://semver.org/)
- [YARD Documentation](https://yardoc.org/)
- [RuboCop](https://rubocop.org/)

## Alternative: Using gem-release

For automated versioning and releasing:

```bash
gem install gem-release

# Bump version and publish in one command
gem bump --version minor --push --release
```

## Support

For publishing issues:
- [RubyGems Help](https://guides.rubygems.org/rubygems-org-api/)
- [RubyGems Support](https://help.rubygems.org/)

For SDK issues:
- Create an issue on GitHub
- Contact support@vortexsoftware.com
