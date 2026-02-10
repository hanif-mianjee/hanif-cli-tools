# Changelog

## [Unreleased]

### Added
- Interactive commit squashing command (`hanif squash [count]`)
- Smart message formatting with commit hash preservation
- Support for custom squash messages
- Root commit squashing capability (auto-detected)
- Re-squashing support (preserves previous formatting)
- Default count of 20 when no count argument is provided
- Comprehensive test suite for squash command (16 tests)

### Fixed
- Squash command no longer squashes all commits when selecting the oldest displayed commit; root rebase only triggers when the selected commit is the actual root commit of the repository

## [0.0.0] - 2026-01-20

### Added
- Initial release
- Extensible CLI framework
- Git helper commands (sync, newfeature, up, upall, clean, rebase)
- JIRA/ticket number extraction in feature branches
- Simple testing framework
- Installation script (direct install via curl)
- Documentation

[0.0.0]: https://github.com/hanif-mianjee/hanif-cli-tools/releases/tag/v0.0.0
