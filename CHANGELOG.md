# Changelog

## [Unreleased]

### Fixed
- "Update available!" message no longer appears after `hanif self-update` completes
- Install verification (`hanif version` during install) no longer triggers stale update notices

### Changed
- Publish script now automatically stamps CHANGELOG.md with version number and date instead of opening editor manually
- Publish script no longer runs tests twice (skips duplicate test run in build step)

## [0.3.0] - 2026-02-12

### Added
- Bumpversion command (`hanif bv` / `hanif bumpversion`) — semantic version bumping with RC workflow
- Interactive bump mode with preview menu and custom version input
- Direct bump subcommands: `patch`, `minor`, `major`, `rc`, `release`
- Config initialization (`hanif bv init`) with auto-detection of project type (Node.js, Python, Rust, Java, etc.)
- RC (release candidate) workflow: all bumps produce RCs, explicit `release` to promote
- Pre-flight verification of all files before any changes are applied
- Tag conflict detection with interactive resolution (delete, suggest next, abort)
- Git commit and tag automation with push prompts and failure detection
- Automatic commit revert on tag conflict abort to prevent dirty history
- Guards against invalid operations (`rc` on stable, `release` on non-rc)
- Missing config auto-prompts to run `hanif bv init`
- Config header with workflow docs and repo link
- Comprehensive test suite for bumpversion command (61 tests)

## [0.2.2] - 2026-02-11

### Fixed
- Squash command now strips surrounding quotes from custom commit messages
- `hanif amend "message"` now uses the full message instead of only the first word
- `hanif amend "message"` now works even when there are no staged changes (updates commit message only)
- `hanif nf --help` no longer creates a `feature/help` branch; shows help instead
- All git subcommands (`nf`, `up`, `upall`, `clean`, `rb`, `amend`) now handle `--help`/`-h` flags correctly
- Publish script now stages lib files changed by the build step, preventing dirty working directory after release

### Changed
- Updated README with detailed squash command result examples
- Added `hanif amend` command to README documentation
- Help topics now route git subcommands (e.g., `hanif help amend`) to git help page

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

[0.2.2]: https://github.com/hanif-mianjee/hanif-cli-tools/releases/tag/v0.2.2
[0.0.0]: https://github.com/hanif-mianjee/hanif-cli-tools/releases/tag/v0.0.0
