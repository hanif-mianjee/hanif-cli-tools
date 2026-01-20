# Hanif CLI - Quick Start

## 🚀 Get Started in 60 Seconds

### 1. Test It

```bash
cd /Users/hanifmianjee/code/personal/hanif-cli-tools
./bin/hanif version
./bin/hanif help
```

### 2. Install Locally

```bash
bash scripts/dev-install.sh
```

### 3. Use It

```bash
# Git commands
hanif git sync              # Full git sync
hanif git nf "my feature"   # New feature branch

# Add your own commands easily!
```

## 📋 Basic Commands

| Command | What it does |
|---------|-------------|
| `hanif git sync` | Update main, rebase, cleanup |
| `hanif git nf "desc"` | Create feature branch |
| `hanif git up` | Update main branch |
| `hanif help` | Show help |

## 🛠️ Add Your Commands

1. Create `lib/commands/mycommand.sh`:
   ```bash
   mycommand_handler() {
     info "Running..."
     success "Done!"
   }
   ```

2. Register in `bin/hanif`:
   ```bash
   mycommand)
     source "${COMMANDS_DIR}/mycommand.sh"
     mycommand_handler "$@"
     ;;
   ```

3. Use: `hanif mycommand`

## 📁 Project Files

```
hanif-cli-tools/
├── bin/hanif              # Main CLI
├── lib/commands/          # Add commands here
├── lib/utils/common.sh    # Helpers (info, success, error)
├── tests/                 # Tests
└── scripts/               # Build scripts
```

## 🧪 Testing

```bash
bash tests/run-tests.sh
```

## 📦 Publishing

When ready to share:

```bash
# Update version in package.json, bin/hanif
# Then:
npm publish
```

## 🎯 That's It!

Simple, extensible, yours to customize.

For more details, see [README.md](README.md)

## 📁 Project Structure

```
hanif-cli-tools/
├── bin/
│   └── hanif                    # Main CLI executable
├── lib/
│   ├── commands/                # Command handlers
│   │   ├── git.sh              # Git command dispatcher
│   │   └── help.sh             # Help system
│   ├── functions/               # Core functionality
│   │   └── git-functions.sh    # Your existing git functions
│   └── utils/                   # Shared utilities
│       └── common.sh           # Logging, validation, helpers
├── tests/                       # Test suite
│   ├── test-framework.sh       # Custom test framework
│   ├── test-git.sh            # Git command tests
│   └── run-tests.sh           # Test runner
├── scripts/                     # Automation scripts
│   ├── build.sh               # Build script
│   ├── publish.sh             # Publishing automation
│   ├── dev-install.sh         # Local dev installation
│   └── dev-uninstall.sh       # Local dev uninstallation
├── docs/                        # Documentation
│   ├── DEVELOPMENT.md         # Development guide
│   └── PUBLISHING.md          # Release guide
├── .github/workflows/          # CI/CD
│   ├── ci.yml                 # Automated testing
│   └── release.yml            # Automated releases
├── install.sh                  # Installation script
├── package.json               # npm package config
├── hanif-cli.rb              # Homebrew formula
├── README.md                  # Main documentation
├── CONTRIBUTING.md            # Contribution guide
├── CHANGELOG.md               # Version history
├── LICENSE                    # MIT License
└── .gitignore                # Git ignore rules
```

## 🚀 Quick Start

### 1. Test Locally

```bash
# Test the CLI works
./bin/hanif version
./bin/hanif help
./bin/hanif git help

# Try a command (in a git repo)
cd /path/to/your/git/repo
/path/to/hanif-cli-tools/bin/hanif git up
```

### 2. Install for Development

```bash
# Install locally (creates symlink)
bash scripts/dev-install.sh

# Now you can use 'hanif' from anywhere
hanif version
hanif help
```

### 3. Run Tests

```bash
# Run all tests
bash tests/run-tests.sh

# Or use npm
npm test
```

## 📋 Available Commands

### Git Commands

| Command | Alias | Description |
|---------|-------|-------------|
| `hanif git newfeature "desc"` | `nf` | Create feature branch |
| `hanif git up` | `update` | Update main/master |
| `hanif git upall` | `updateall` | Update all branches |
| `hanif git clean` | - | Clean deleted branches |
| `hanif git rebase main` | `rb` | Rebase onto branch |
| `hanif git pull` | - | Fetch all + pull |
| `hanif git sync` | - | Full sync workflow |
| `hanif git status` | `st` | Git status |

### Examples

```bash
# Create a feature branch
hanif git nf "add user authentication"
# → Creates: feature/add_user_authentication

# With ticket number
hanif git nf "OM-755: fix login bug"
# → Creates: feature/om-755_fix_login_bug

# Update all branches
hanif git upall

# Full sync (update, rebase, clean)
hanif git sync

# Rebase current branch
hanif git rb main
```

## 🛠️ Development Workflow

### Adding a New Command

1. **Create command file**: `lib/commands/mycommand.sh`
2. **Register in main**: Add case in `bin/hanif`
3. **Add help**: Update `lib/commands/help.sh`
4. **Write tests**: Create `tests/test-mycommand.sh`
5. **Update docs**: Add to README.md

Example structure:

```bash
# lib/commands/mycommand.sh
mycommand_handler() {
  case "$1" in
    action)
      info "Running action..."
      success "Done!"
      ;;
    help)
      show_mycommand_help
      ;;
  esac
}
```

### Making Changes

```bash
# 1. Create feature branch (using the tool itself!)
hanif git nf "add-awesome-feature"

# 2. Make your changes
vim lib/commands/git.sh

# 3. Test your changes
./bin/hanif mycommand

# 4. Run tests
npm test

# 5. Commit and push
git add .
git commit -m "feat: add awesome feature"
git push
```

## 📦 Installation Options

### Option 1: npm (Recommended for distribution)

```bash
# Publish to npm
npm publish

# Users install with:
npm install -g hanif-cli
```

### Option 2: Homebrew

```bash
# Create your own tap
# Repository name: homebrew-hanif

# Users install with:
brew tap yourusername/hanif
brew install hanif-cli
```

### Option 3: Direct Installation

```bash
# Users install with:
curl -fsSL https://raw.githubusercontent.com/yourusername/hanif-cli-tools/main/install.sh | bash
```

## 🧪 Testing

```bash
# Run all tests
bash tests/run-tests.sh

# Run specific test
bash tests/test-git.sh

# Enable debug mode
DEBUG=1 bash tests/test-git.sh

# Test with linting
npm run lint
```

## 📝 Before Publishing

### Checklist

- [ ] Update version in `package.json`, `bin/hanif`, `hanif-cli.rb`
- [ ] Update `CHANGELOG.md`
- [ ] Run tests: `npm test`
- [ ] Run linter: `npm run lint` (if shellcheck installed)
- [ ] Update README if needed
- [ ] Update repository URL in all files
- [ ] Test installation locally
- [ ] Create GitHub repository
- [ ] Push code to GitHub

### Update Repository URLs

Replace `yourusername` with your GitHub username in:
- `package.json` (repository.url, bugs.url, homepage)
- `README.md` (links)
- `CONTRIBUTING.md` (links)
- `install.sh` (REPO_URL)
- `lib/commands/help.sh` (documentation links)
- `hanif-cli.rb` (homepage, url)

### Publishing

```bash
# Easy way: Use the publish script
bash scripts/publish.sh

# Manual way:
npm version patch  # or minor, major
git push origin main --tags
npm publish
```

## 🎯 Next Steps

1. **Customize**: Update repository URLs and author info
2. **Test**: Run `npm test` to verify everything works
3. **Install locally**: Run `bash scripts/dev-install.sh`
4. **Try it out**: Use `hanif` commands in your git repos
5. **Add commands**: Extend with your own commands
6. **Publish**: Share with the world!

## 📚 Documentation

- **README.md**: User-facing documentation
- **CONTRIBUTING.md**: For contributors
- **docs/DEVELOPMENT.md**: Technical development guide
- **docs/PUBLISHING.md**: Release and publishing guide

## 🔧 Customization

### Change CLI Name

If you want to rename from "hanif" to something else:

1. Rename `bin/hanif` to `bin/yourname`
2. Update `package.json` "bin" field
3. Update all documentation references
4. Update `hanif-cli.rb` class name and filename

### Add More Command Categories

Currently has: `git`, `help`, `version`

To add more:

```bash
# Create: lib/commands/docker.sh
# Add case in bin/hanif:
  docker)
    source "${COMMANDS_DIR}/docker.sh"
    docker_command "$@"
    ;;
```

## 🐛 Troubleshooting

### Command not found

```bash
# Make sure it's executable
chmod +x bin/hanif

# Make sure it's in PATH (after dev-install.sh)
echo $PATH | grep ".local/bin"
```

### Tests failing

```bash
# Check git is installed
git --version

# Check bash version
bash --version

# Run with debug
DEBUG=1 bash tests/run-tests.sh
```

## 💡 Tips

- Use `DEBUG=1` for debug output
- All scripts use `set -euo pipefail` for safety
- Use utility functions from `lib/utils/common.sh`
- Test in a clean git repo first
- Keep functions small and focused
- Write tests for new features

## 🎉 You're Ready!

Your CLI tool is fully scaffolded and production-ready!

```bash
# Try it out
hanif version
hanif help
hanif git nf "my first feature"
```

Happy coding! 🚀
