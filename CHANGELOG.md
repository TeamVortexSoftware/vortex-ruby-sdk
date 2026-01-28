# Changelog

All notable changes to the Vortex Ruby SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-01-23

### Added
- **Internal Invitations**: New `'internal'` delivery type for customer-managed invitations
  - Support for `deliveryTypes: ['internal']`
  - No email/SMS communication triggered by Vortex
  - Target value can be any customer-defined identifier
  - Useful for in-app invitation flows managed by customer's application

### Changed
- Updated `deliveryTypes` field documentation to include `'internal'` as a valid value

## [1.1.3] - 2025-01-29

### Added
- **ACCEPT_USER Type**: New preferred format for accepting invitations with `email`, `phone`, and `name` fields
- Enhanced `accept_invitations` method to support both new User hash format and legacy target format

### Changed
- **DEPRECATED**: Legacy target hash format for `accept_invitations` - use User hash instead
- Internal API calls now always use User format for consistency
- Added warning messages when legacy target format is used

### Fixed
- Maintained 100% backward compatibility - existing code using legacy target format continues to work
