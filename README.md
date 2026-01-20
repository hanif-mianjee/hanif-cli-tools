# Hanif CLI

> Personal productivity CLI tool with git helpers and daily workflow automation

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/yourusername/hanif-cli-tools)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

A powerful command-line tool that streamlines daily git workflows with smart automation, branch management, and productivity helpers.

## Features

- 🚀 **Smart Branch Creation** - Create feature branches with automatic naming and ticket extraction
- 🔄 **Intelligent Updates** - Update all branches with a single command
- 🧹 **Auto Cleanup** - Remove stale branches that have been deleted from remote
- 🔀 **Safe Rebasing** - Rebase with automatic stashing and base branch updates
- ⚡️ **Fast Workflows** - Combine multiple git operations into single commands
- 🎨 **Beautiful Output** - Clear, colored terminal output with helpful messages

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

#### `hanif git newfeature` (alias: `nf`)

Create a new feature branch with smart naming.

```bash
# Basic usage
hanif git nf "add login feature"
# Creates: feature/add_login_feature

# With ticket number
hanif git nf "OM-755: fix authentication bug"
# Creates: feature/om-755_fix_authentication_bug

# Short alias
hanif git nf "JIRA-123 update API"
# Creates: feature/jira-123_update_api
```

**Features:**
- Automatically extracts ticket numbers (JIRA-123, OM-755, etc.)
- Sanitizes branch names (removes special characters)
- Converts to lowercase
- Enforces 60 character limit

#### `hanif git up` (alias: `update`)

Update main/master branch with latest changes.

```bash
hanif git up
```

**What it does:**
1. Detects whether you use `main` or `master`
2. Checks out the base branch
3. Fetches from all remotes
4. Pulls latest changes

#### `hanif git upall` (alias: `updateall`)

Update all local branches with remote changes.

```bash
hanif git upall
```

**What it does:**
1. Stashes any local changes
2. Fetches all remotes (single fetch operation)
3. Fast-forwards all local branches
4. Returns to original branch
5. Restores stashed changes

**Perfect for:** Syncing all branches after being away

#### `hanif git clean`

Delete local branches that have been removed from remote.

```bash
hanif git clean
```

**What it does:**
1. Fetches with prune (`-p`) to update remote tracking
2. Identifies branches deleted from origin
3. Protects `main`, `master`, and current branch
4. Deletes stale branches

**Safety:** Never deletes protected branches or local-only branches

#### `hanif git rebase` (alias: `rb`)

Rebase current branch onto another branch with safety checks.

```bash
hanif git rebase main
hanif git rb main
```

**What it does:**
1. Updates the base branch first
2. Stashes local changes
3. Rebases current branch
4. Restores stashed changes
5. Provides clear instructions if conflicts occur

#### `hanif git pull`

Fetch from all remotes and pull current branch.

```bash
hanif git pull
```

Equivalent to: `git fetch --all && git pull`

#### `hanif git sync`

Full repository sync workflow - perfect for starting work.

```bash
hanif git sync
```

**What it does:**
1. Updates main/master branch
2. Rebases current branch (if not on main)
3. Cleans deleted branches
4. Single command for complete sync

**Use case:** Run this first thing when starting work

#### `hanif git status` (alias: `st`)

Show git status (passthrough to git).

```bash
hanif git st
```

### Help Commands

```bash
# General help
hanif help

# Git-specific help
hanif help git
hanif git help

# Version
hanif version
```

## Command Chaining

Hanif CLI supports natural command aliases and passthrough to git:

```bash
# These all work
hanif git nf "feature"
hanif git newfeature "feature"

# Unknown git commands pass through
hanif git commit -m "message"
# → runs: git commit -m "message"
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

### Adding New Commands

1. Create command file in `lib/commands/`:

```bash
# lib/commands/mycommand.sh
mycommand_handler() {
  echo "My command works!"
}
```

2. Add to main dispatcher in `bin/hanif`:

```bash
mycommand)
  source "${COMMANDS_DIR}/mycommand.sh"
  mycommand_handler "$@"
  ;;
```

3. Add help text in `lib/commands/help.sh`

4. Add tests in `tests/test-mycommand.sh`

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## Configuration

Hanif CLI works out of the box with no configuration needed. It respects your git configuration and integrates seamlessly with your existing workflow.

### Environment Variables

- `DEBUG=1` - Enable debug output
- `HANIF_VERSION=<version>` - Specify version for installation

## Examples

### Daily Workflow

```bash
# Start of day - sync everything
hanif git sync

# Create new feature
hanif git nf "OM-842: add export feature"

# Work on feature...
git add .
git commit -m "Implement export"

# Update and rebase before pushing
hanif git rb main
git push -u origin HEAD
```

### Managing Multiple Features

```bash
# Update all feature branches at once
hanif git upall

# Clean up merged branches
hanif git clean

# Quick status check
hanif git st
```

### Complex Ticket Scenarios

```bash
# Handles various ticket formats
hanif git nf "JIRA-123: Add feature"
hanif git nf "OM-755 Fix bug"
hanif git nf "PROJ-42: Update docs"
hanif git nf "just a regular feature"
```

## Troubleshooting

### Command not found

If you get `hanif: command not found`:

```bash
# Reload your shell configuration
source ~/.zshrc  # for zsh
source ~/.bashrc # for bash

# Or check if binary is in PATH
which hanif

# Verify installation
ls ~/.local/bin/hanif
```

### Permission denied

```bash
# Make executable
chmod +x ~/.local/bin/hanif
```

### Updates not working

```bash
# Reinstall latest version
curl -fsSL https://raw.githubusercontent.com/yourusername/hanif-cli-tools/main/install.sh | bash

# Or with npm
npm update -g hanif-cli
```

## Uninstallation

### npm

```bash
npm uninstall -g hanif-cli
```

### Homebrew

```bash
brew uninstall hanif-cli
```

### Direct Installation

```bash
bash ~/.hanif-cli/install.sh uninstall
```

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

1. Fork the repository
2. Create a feature branch (`hanif git nf "your feature"`)
3. Make your changes
4. Add tests
5. Submit a pull request

## License

MIT © Hanif Mianjee

See [LICENSE](LICENSE) for details.

## Support

- 📖 [Documentation](https://github.com/yourusername/hanif-cli-tools/wiki)
- 🐛 [Issue Tracker](https://github.com/yourusername/hanif-cli-tools/issues)
- 💬 [Discussions](https://github.com/yourusername/hanif-cli-tools/discussions)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

---

Made with ❤️ for streamlined git workflows
