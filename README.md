# Hanif CLI

> Personal productivity CLI for daily workflows

[![Version](https://img.shields.io/badge/version-0.4.0-blue.svg)](https://github.com/hanif-mianjee/hanif-cli-tools)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/hanif-mianjee/hanif-cli-tools/main/install.sh | bash
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
hanif amend                         # Amend last commit (keep message)
hanif amend "new message"           # Amend last commit with new message
hanif gi .env                       # Add .env to .gitignore & untrack
hanif gi node_modules/              # Add node_modules/ to .gitignore & untrack
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
```

**Workflow:** Select a commit to squash into, then optionally provide a custom message. All squashed commits are preserved with their hashes in the final message.

Result with custom message:
```
OM-1200 Major refactor
* 1a6c6d8 Third commit
* ef3798f Fourth commit
* a524b8f Fifth commit
```

Result without custom message (uses selected commit's message):
```
Third commit
* ef3798f Fourth commit
* a524b8f Fifth commit
```

Run `hanif squash --help` for the full guide.

## Gitignore Command

Add paths to `.gitignore` and remove them from git tracking in one step. Files stay on disk — only removed from the git index:

```bash
hanif gi .env                # Add .env to .gitignore & untrack
hanif gi node_modules/       # Add node_modules/ to .gitignore & untrack
hanif gi "*.log"             # Add *.log pattern to .gitignore & untrack
hanif gitignore .DS_Store    # Full command name also works
```

Creates `.gitignore` if it doesn't exist. Skips duplicate entries. Run `hanif gi --help` for the full guide.

## Bumpversion Command

Semantic version bumping with RC (release candidate) workflow:

```bash
hanif bv              # Interactive bump with preview menu
hanif bv init         # Initialize .bumpversion.cfg for your project
hanif bv patch        # 1.0.0 → 1.0.1-rc0
hanif bv minor        # 1.0.0 → 1.1.0-rc0
hanif bv major        # 1.0.0 → 2.0.0-rc0
hanif bv rc           # 1.0.1-rc0 → 1.0.1-rc1
hanif bv release      # 1.0.1-rc1 → 1.0.1
```

**Workflow:** Initialize with `hanif bv init`, then use `patch`/`minor`/`major` to create RC versions, `rc` to iterate, and `release` to promote.

**Features:**

- Auto-detects project type (Node.js, Python, Rust, Java, etc.)
- Updates version strings across all configured files
- Git commit and tag automation with push prompts
- Tag conflict detection with interactive resolution
- Pre-flight verification prevents partial updates
- Custom version input via interactive menu
- Compatible with `.bumpversion.cfg` format

Run `hanif bv --help` for the full guide.

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
bash tests/run-tests.sh
```

### Project Structure

```text
bin/hanif              # Main CLI entry point
lib/
  commands/            # Command handlers (git, squash, bumpversion, svg, help)
  functions/           # Core logic (git-functions, squash-functions, bumpversion-functions, svg-functions)
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
