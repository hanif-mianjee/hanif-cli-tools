# Hanif CLI

> Personal productivity CLI tool for daily workflows

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/yourusername/hanif-cli-tools)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

A simple, extensible command-line tool for automating your daily tasks. Start with built-in git helpers and easily add your own commands.

## Features

- 🎨 **Simple & Extensible** - Easy to add new commands for any task
- 🔧 **Git Helpers** - Common git workflows automated (includes smart sync)
- ⚡️ **Fast** - Single command for complex workflows
- 🎨 **Beautiful Output** - Clear, colored terminal messages

## Installation

### npm (Recommended)

```bash
npm install -g hanif-cli
```

### Homebrew

```bash
brew tap yourusername/hanif-cli
brew install hanif-cli
```

### Direct Installation

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/hanif-cli-tools/main/install.sh | bash
```

### Manual Installation

```bash
git clone https://github.com/yourusername/hanif-cli-tools.git
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

### Help

```bash
hanif help           # General help
hanif help git       # Git command help
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
│   │   └── help.sh
│   ├── functions/         # Core functionality
│   │   └── git-functions.sh
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

# Run specific test
bash tests/test-git.sh
```

### Local Development

```bash
# Clone repository
git clone https://github.com/yourusername/hanif-cli-tools.git
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
curl -fsSL https://raw.githubusercontent.com/yourusername/hanif-cli-tools/main/install.sh | bash
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