# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Planned features go here

### Changed
- Planned improvements go here

### Fixed
- Planned bug fixes go here

## [1.0.0] - 2026-01-20

### Added
- Initial release of Hanif CLI
- Git helper commands:
  - `newfeature` (nf) - Create feature branches with smart naming
  - `up` - Update main/master branch
  - `upall` - Update all local branches
  - `clean` - Delete branches removed from remote
  - `rebase` (rb) - Rebase with automatic stashing
  - `pull` - Fetch all and pull
  - `sync` - Full repository sync workflow
  - `status` (st) - Git status passthrough
- Smart branch naming with ticket extraction (JIRA-123, OM-755, etc.)
- Automatic stashing and restoration in git operations
- Protected branch safety (never deletes main/master/current)
- Beautiful colored terminal output
- Comprehensive help system
- Installation via npm, Homebrew, or direct script
- Complete test suite with custom testing framework
- Extensive documentation (README, CONTRIBUTING, development guides)
- Build and publishing automation scripts

### Features
- Passthrough to git for unknown commands
- Short command aliases (nf, rb, st, etc.)
- Debug mode with DEBUG=1 environment variable
- Retry logic for flaky operations
- Version checking and validation
- CI/CD friendly (detects CI environment)

[Unreleased]: https://github.com/yourusername/hanif-cli-tools/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/yourusername/hanif-cli-tools/releases/tag/v1.0.0
