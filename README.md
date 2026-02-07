# Hanif CLI

> Personal productivity CLI tool for daily workflows

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/hanif-mianjee/hanif-cli-tools)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

A simple, extensible command-line tool for automating your daily tasks. Start with built-in git helpers and easily add your own commands.

## Features

- 🎨 **Simple & Extensible** - Easy to add new commands for any task
- 🔧 **Git Helpers** - Common git workflows automated (includes smart sync)
- 🖼️ **SVG Tools** - Convert SVG to PNG with auto-detected converters
- ⚡️ **Fast** - Single command for complex workflows
- 🎨 **Beautiful Output** - Clear, colored terminal messages

## Installation

### npm (Recommended)

```bash
npm install -g hanif-cli
```

### Homebrew

```bash
brew tap hanif-mianjee/hanif-cli
brew install hanif-cli
```

### Direct Installation

```bash
curl -fsSL https://raw.githubusercontent.com/hanif-mianjee/hanif-cli-tools/main/install.sh | bash
```

### Manual Installation

```bash
git clone https://github.com/hanif-mianjee/hanif-cli-tools.git
cd hanif-cli-tools
./install.sh
```

## Quick Start

```bash
# Get help
hanif help

# Create a new feature branch
hanif git nf "add user authentication"

# Update your main branch
hanif git up

# Update all branches
hanif git upall

# Full sync workflow
hanif git sync

# Clean deleted branches
hanif git clean

# Interactive commit squashing
hanif squash 5

# Convert SVG to PNG (custom sizes)
hanif svg convert logo.svg 64,128,256

# Generate Chrome extension icons
hanif svg chrome icon.svg --output-dir src/assets/icons
```

## Commands

### Git Commands

Common git workflows automated:

```bash
# Create feature branch
hanif git nf "add login feature"
# → Creates: feature/add_login_feature

# Create feature branch with JIRA/ticket number
hanif git nf "JIRA-123: add login feature"
# → Creates: feature/jira-123_add_login_feature

hanif git nf "OM-755: fix authentication bug"
# → Creates: feature/om-755_fix_authentication_bug

# Sync everything (update main, rebase, cleanup)
hanif git sync

# Update main branch
hanif git up

# Other git commands
hanif git upall    # Update all branches
hanif git clean    # Remove deleted branches
hanif git rb main  # Rebase onto main
```

**Smart branch naming:**
- Automatically extracts ticket numbers (JIRA-123, OM-755, ABC-42, etc.)
- Sanitizes branch names (removes special characters)
- Converts to lowercase
- Enforces 60 character limit

**Git commands pass through:**
```bash
hanif git commit -m "message"  # → runs: git commit -m "message"
hanif git status               # → runs: git status
```

### Squash Commands

Interactive commit squashing with smart message formatting:

```bash
# Squash last 5 commits
hanif squash 5
# → Shows commits, select which to squash into
# → Optional: provide custom message
# → Preserves all commits with hashes

# Squash last 10 commits
hanif squash 10

# Get help
hanif squash --help
```

**Features:**
- 🎯 **Interactive selection** - Choose which commit to squash into
- 📝 **Custom messages** - Optional custom message or use selected commit's message
- 🔄 **Preserves history** - All commits listed with hashes in final message
- 🌳 **Root support** - Can squash all commits including first one
- 💬 **Multi-line support** - Preserves formatting when re-squashing

**Example workflow:**
```bash
# You have 5 commits on feature branch
hanif squash 5

# Output:
# 📜 Select a commit to squash everything into:
# 1) a524b8f Fifth commit
# 2) ef3798f Fourth commit
# 3) 1a6c6d8 Third commit
# 4) facfca7 Second commit
# 5) cbfcdf1 First commit
# Enter number [1-5]: 3

# 💬 Enter custom message for squashed commit
#    (Press Enter to use: "Third commit")
# Message: OM-1200 Major refactor

# Result:
# OM-1200 Major refactor
# * 1a6c6d8 Third commit
# * ef3798f Fourth commit
# * a524b8f Fifth commit
```

**Common use cases:**
```bash
# Clean up feature branch before PR
hanif squash 8
# Select meaningful commit, add descriptive message

# Squash WIP commits, keep feature commit message
hanif squash 5
# Select your main commit, press Enter to keep its message

# Re-squash after adding more commits
hanif squash 3
# Works seamlessly with already-squashed commits

# Squash from root (all commits)
hanif squash 10
# Select last commit (option 10) to squash everything
```

### SVG Commands

Convert SVG files to PNG with auto-detected converters (librsvg, Inkscape, or ImageMagick):

```bash
# Convert SVG to PNG at custom sizes
hanif svg convert icon.svg 16,32,64
# → icon16.png, icon32.png, icon64.png

# Custom prefix and output directory
hanif svg convert logo.svg 100,200,400 --prefix logo --output-dir ./out
# → ./out/logo100.png, ./out/logo200.png, ./out/logo400.png

# Generate Chrome extension icons (16, 32, 48, 128)
hanif svg chrome icon.svg
# → icon16.png, icon32.png, icon48.png, icon128.png

hanif svg chrome icon.svg --output-dir src/assets/icons
# → src/assets/icons/icon16.png, etc.
```

**Options:**
- `--prefix, -p <name>` - Output filename prefix (default: `icon`, convert only)
- `--output-dir, -o <dir>` - Output directory (default: current directory)

**Supported converters** (auto-detected in order):
1. **librsvg** (best) - `brew install librsvg`
2. **Inkscape** - `brew install --cask inkscape`
3. **ImageMagick** - `brew install imagemagick ghostscript`

### Help

```bash
hanif help           # General help
hanif help git       # Git command help
hanif help svg       # SVG command help
hanif version        # Show version
```

## Development

### Project Structure

```
hanif-cli-tools/
├── bin/
│   └── hanif              # Main executable
├── lib/
│   ├── commands/          # Command handlers
│   │   ├── git.sh
│   │   ├── svg.sh
│   │   └── help.sh
│   ├── functions/         # Core functionality
│   │   ├── git-functions.sh
│   │   └── svg-functions.sh
│   └── utils/             # Utilities
│       └── common.sh
├── tests/                 # Test files
│   ├── test-framework.sh
│   ├── test-git.sh
│   └── run-tests.sh
├── docs/                  # Documentation
├── scripts/               # Build/publish scripts
├── install.sh             # Installation script
├── package.json           # npm package config
└── hanif-cli.rb          # Homebrew formula
```

### Running Tests

```bash
# Run all tests
npm test

# Run tests manually
bash tests/run-tests.sh

# Run specific test suite
bash tests/test-git.sh
bash tests/test-squash.sh
```

### Local Development

```bash
# Clone repository
git clone https://github.com/hanif-mianjee/hanif-cli-tools.git
cd hanif-cli-tools

# Install locally for development
npm run install-dev

# Make executable
chmod +x bin/hanif

# Test your changes
./bin/hanif help

# Run linter
npm run lint
```

See "Adding Your Own Commands" section below for how to extend the CLI.

## Configuration

Hanif CLI works out of the box with no configuration needed. It respects your git configuration and integrates seamlessly with your existing workflow.

### Environment Variables

- `DEBUG=1` - Enable debug output

## Examples

### Daily Git Workflow

```bash
# Start of day - sync everything
hanif git sync

# Create feature with ticket number
hanif git nf "OM-842: add export feature"
# → Creates: feature/om-842_add_export_feature

# Work on feature...
git add .
git commit -m "Implement export"
git add .
git commit -m "Add tests"
git add .
git commit -m "Fix edge case"

# Squash commits before PR
hanif squash 3
# Select commit #1, add: "feat: add export feature with tests"

# Update and rebase before pushing
hanif git rb main
git push -u origin HEAD
```

### Ticket Number Examples

```bash
hanif git nf "JIRA-456: update API endpoints"
# → feature/jira-456_update_api_endpoints

hanif git nf "ABC-789 refactor database layer"
# → feature/abc-789_refactor_database_layer

hanif git nf "just a simple feature"
# → feature/just_a_simple_feature
```

### Squash Examples

```bash
# Cleaning up feature branch
hanif squash 8
# 📜 Select a commit to squash everything into:
# 1) a524b8f Eighth commit (most recent)
# 2) ef3798f Seventh commit
# ...
# 8) cbfcdf1 First commit
# Enter number [1-8]: 1
# Message: feat: implement user authentication
#
# Result: One clean commit with all changes

# Preparing for PR (keeping existing message)
hanif squash 5
# Enter number [1-5]: 2
# Message: [press Enter]
#
# Result: Uses commit #2's message as main message

# Re-squashing after adding commits
# (You previously squashed, then added more work)
hanif squash 3
# Select the previously squashed commit
# All formatting preserved, new commits appended
```

Adding Your Own Commands

It's simple! Just 3 steps:

1. **Create command file**: `lib/commands/mycommand.sh`
   ```bash
   mycommand_handler() {
     info "Running my command..."
     # your code here
     success "Done!"
   }
   ```

2. **Register in main**: Edit `bin/hanif`, add:
   ```bash
   mycommand)
     source "${COMMANDS_DIR}/mycommand.sh"
     mycommand_handler "$@"
     ;;
   ```

3. **Use it**: `hanif mycommand`

## Building & Publishing

### Local Development

```bash
# Install for development (creates symlink)
bash scripts/dev-install.sh

# Test your changes
hanif version
hanif git nf "test"

# Run tests
bash tests/run-tests.sh
```

### Building

```bash
# Validate project
bash scripts/build.sh

# This checks:
# - All required files exist
# - Scripts are executable
# - Tests pass
```

### Publishing

#### 1. Update Version

Update version in these files:
- `package.json` - "version" field
- `bin/hanif` - VERSION variable
- `hanif-cli.rb` - version field

#### 2. Update Changelog

Add your changes to `CHANGELOG.md`

#### 3. Publish to npm

```bash
# Login (first time only)
npm login

# Publish
npm publish
```

#### 4. Publish to Homebrew

```bash
# Create GitHub release and tag
git tag -a v1.0.1 -m "Release 1.0.1"
git push origin v1.0.1

# Generate SHA256 for Homebrew formula
curl -L https://github.com/user/repo/archive/v1.0.1.tar.gz -o temp.tar.gz
shasum -a 256 temp.tar.gz

# Update hanif-cli.rb with new version and SHA256
# Push to your homebrew tap repository
```

#### 5. Direct Installation

Users can install directly via:
```bash
curl -fsSL https://raw.githubusercontent.com/hanif-mianjee/hanif-cli-tools/main/install.sh | bash
```

### Automated Publishing

The project includes GitHub Actions workflows:
- `.github/workflows/ci.yml` - Runs tests on push
- `.github/workflows/release.yml` - Auto-publishes on tag push

To auto-publish:
1. Set `NPM_TOKEN` secret in GitHub repo settings
2. Push a version tag: `git push origin v1.0.1`
3. GitHub Actions will test and publish automatically

## Contributing

Contributions welcome! Add your own commands and share them.

## License

MIT © Hanif Mianjee

---

**Simple, extensible, yours to customize.**