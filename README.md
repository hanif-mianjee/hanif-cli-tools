# Hanif CLI

> Personal productivity CLI for daily workflows

[![Version](https://img.shields.io/badge/version-0.0.0-blue.svg)](https://github.com/hanif-mianjee/hanif-cli-tools)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

## Installation

```bash
# Direct (recommended)
curl -fsSL https://raw.githubusercontent.com/hanif-mianjee/hanif-cli-tools/main/install.sh | bash

# npm (not available)
# npm install -g hanif-cli

# Homebrew (not available)
# brew tap hanif-mianjee/hanif-cli && brew install hanif-cli
```

## Git Commands

```bash
hanif sync                          # Full sync (update main, rebase, clean)
hanif nf "add user auth"            # → feature/add_user_auth
hanif nf "JIRA-123: fix bug"        # → feature/jira-123_fix_bug
hanif up                            # Update main/master branch
hanif upall                         # Update all branches
hanif clean                         # Delete branches removed from remote
hanif rb main                       # Rebase onto branch
hanif pull                          # Fetch all + pull
hanif st                            # Git status
```

Smart branch naming with `nf`:
- Extracts ticket numbers (JIRA-123, OM-755, ABC-42)
- Sanitizes names, converts to lowercase
- Enforces 60 character limit

## Squash Command

Interactive commit squashing with smart message formatting:

```bash
hanif squash          # Shows last 20 commits (default)
hanif squash 5        # Shows last 5 commits
# Select which commit to squash into
# Optionally provide a custom message
# All commits preserved with hashes in final message
```

## SVG Commands

Convert SVG to PNG with auto-detected converters (librsvg, Inkscape, ImageMagick):

```bash
hanif svg convert icon.svg 16,32,64                      # Custom sizes
hanif svg convert logo.svg 100,200 --prefix logo -o out  # Custom prefix/dir
hanif svg chrome icon.svg                                 # Chrome extension icons
```

## Development

```bash
git clone https://github.com/hanif-mianjee/hanif-cli-tools.git
cd hanif-cli-tools
bash scripts/dev-install.sh
npm test
```

### Project Structure

```
bin/hanif              # Main CLI entry point
lib/
  commands/            # Command handlers (git, squash, svg, help)
  functions/           # Core logic (git-functions, squash-functions, svg-functions)
  utils/common.sh      # Shared utilities (logging, git helpers)
tests/                 # Test suites
scripts/               # Build/install/publish scripts
```

### Adding Commands

1. Create `lib/commands/mycommand.sh` with a handler function
2. Register in `bin/hanif` case statement
3. Use: `hanif mycommand`

### Publishing

```bash
# Automated: bumps version everywhere, tags, publishes
bash scripts/publish.sh
```

## Legacy Syntax

`hanif git <command>` still works for backward compatibility (e.g., `hanif git sync`).
This form will be removed in v2.0.0 — use `hanif <command>` directly.

## License

MIT
