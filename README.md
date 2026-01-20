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

# Sync everything (update main, rebase, cleanup)
hanif git sync

# Update main branch
hanif git up

# Other git commands
hanif git upall    # Update all branches
hanif git clean    # Remove deleted branches
hanif git rb main  # Rebase onto main
```

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
Contributing

Contributions welcome! Add your own commands and share them.

## License

MIT © Hanif Mianjee

---

**Simple, extensible, yours to customize.**