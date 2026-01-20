# Contributing

Thanks for your interest! This is a simple, personal CLI tool that's easy to extend.

## Quick Start

```bash
# Fork and clone
git clone https://github.com/yourusername/hanif-cli-tools.git
cd hanif-cli-tools

# Install locally
bash scripts/dev-install.sh

# Make changes, test
hanif version
bash tests/run-tests.sh
```

## Adding Commands

1. Create `lib/commands/yourcommand.sh`
2. Add handler function
3. Register in `bin/hanif`
4. Test it
5. Submit PR

## Code Style

- Use `set -euo pipefail` in scripts
- Quote variables: `"$var"`
- Use utility functions: `info`, `success`, `error`
- Keep it simple

## Testing

```bash
bash tests/run-tests.sh
```

Add tests for new features in `tests/`.

## Pull Requests

- Clear description
- Tests passing
- One feature per PR

That's it! Keep contributions simple and focused.

### Prerequisites

- Git 2.0+
- Bash 4.0+ or Zsh 5.0+
- Node.js 14+ (for npm scripts)
- Basic shell scripting knowledge

### Development Setup

1. **Fork and Clone**

```bash
git clone https://github.com/yourusername/hanif-cli-tools.git
cd hanif-cli-tools
```

2. **Install Dependencies**

```bash
npm install
```

3. **Make Executable**

```bash
chmod +x bin/hanif
chmod +x tests/*.sh
chmod +x scripts/*.sh
```

4. **Test Installation**

```bash
./bin/hanif help
```

5. **Install for Local Development**

```bash
npm run install-dev
```

## Development Workflow

### 1. Create a Feature Branch

Use the tool itself!

```bash
hanif git nf "add-new-feature"
# or
hanif git nf "ISSUE-123: fix bug"
```

### 2. Make Your Changes

Follow these guidelines:

- **Shell Scripts**: Use `bash` or `zsh` compatible syntax
- **Indentation**: 2 spaces (not tabs)
- **Naming**: Use `snake_case` for functions and variables
- **Comments**: Add comments for complex logic
- **Error Handling**: Use `set -euo pipefail` at the top of scripts

### 3. Code Style

#### Shell Script Best Practices

```bash
#!/usr/bin/env bash

# Always start with error handling
set -euo pipefail

# Use meaningful variable names
local branch_name="feature/my-feature"

# Quote variables
echo "Branch: ${branch_name}"

# Check command success
if git checkout "$branch_name"; then
  success "Checked out branch"
else
  error "Failed to checkout branch"
  return 1
fi

# Use functions for reusability
create_branch() {
  local name="$1"
  git checkout -b "$name"
}
```

#### Utility Functions

Always use utility functions from `lib/utils/common.sh`:

```bash
info "Information message"      # Blue ℹ
success "Success message"       # Green ✓
warning "Warning message"       # Yellow ⚠
error "Error message"           # Red ✗
```

### 4. Testing

#### Write Tests

Create test files in `tests/` directory:

```bash
# tests/test-myfeature.sh
#!/usr/bin/env bash

source "$(dirname "$0")/test-framework.sh"

test_my_feature() {
  assert_success "Feature works" hanif mycommand
}

suite "My Feature"
run_test test_my_feature
print_summary
```

#### Run Tests

```bash
# Run all tests
npm test

# Run specific test
bash tests/test-git.sh

# Enable debug mode
DEBUG=1 bash tests/test-git.sh
```

### 5. Linting

```bash
# Run shellcheck
npm run lint

# Auto-format (if shfmt is installed)
npm run format
```

### 6. Documentation

Update documentation for:

- **New Commands**: Add to README.md and help text
- **Command Changes**: Update relevant sections
- **Breaking Changes**: Add to CHANGELOG.md

#### Help Text Format

```bash
show_command_help() {
  cat << 'EOF'
COMMAND NAME
  Short description
  
  Usage:
    hanif command <arg>
  
  Examples:
    hanif command example1
    hanif command example2
  
  Options:
    --flag    Description
EOF
}
```

## Project Structure

```
hanif-cli-tools/
├── bin/
│   └── hanif                 # Main executable entry point
├── lib/
│   ├── commands/             # Command handlers
│   │   ├── git.sh           # Git commands
│   │   └── help.sh          # Help system
│   ├── functions/            # Core functionality
│   │   └── git-functions.sh # Git helper functions
│   └── utils/                # Shared utilities
│       └── common.sh        # Common functions
├── tests/                    # Test files
│   ├── test-framework.sh    # Testing framework
│   ├── test-git.sh          # Git command tests
│   └── run-tests.sh         # Test runner
├── docs/                     # Documentation
│   ├── DEVELOPMENT.md       # Development guide
│   ├── COMMANDS.md          # Command reference
│   └── PUBLISHING.md        # Publishing guide
└── scripts/                  # Build/deploy scripts
```

## Adding New Commands

### 1. Create Command Handler

Create `lib/commands/mycommand.sh`:

```bash
#!/usr/bin/env bash

# My command handler

mycommand_handler() {
  if [[ $# -eq 0 ]]; then
    show_mycommand_usage
    exit 1
  fi

  local subcommand="$1"
  shift

  case "$subcommand" in
    action)
      do_action "$@"
      ;;
    help|--help|-h)
      show_mycommand_help
      ;;
    *)
      error "Unknown subcommand: $subcommand"
      exit 1
      ;;
  esac
}

do_action() {
  info "Performing action..."
  # Implementation here
  success "Action completed!"
}

show_mycommand_usage() {
  cat << 'EOF'
Usage: hanif mycommand <subcommand>

Subcommands:
  action    Perform an action
  help      Show help
EOF
}

show_mycommand_help() {
  cat << 'EOF'
Detailed help for mycommand
EOF
}
```

### 2. Register Command

Add to `bin/hanif`:

```bash
case "$command" in
  # ... existing commands ...
  
  mycommand)
    source "${COMMANDS_DIR}/mycommand.sh"
    mycommand_handler "$@"
    ;;
esac
```

### 3. Add Help Text

Update `lib/commands/help.sh`:

```bash
case "$topic" in
  # ... existing topics ...
  
  mycommand)
    source "${COMMANDS_DIR}/mycommand.sh"
    show_mycommand_help
    ;;
esac
```

### 4. Write Tests

Create `tests/test-mycommand.sh`:

```bash
#!/usr/bin/env bash

source "$(dirname "$0")/test-framework.sh"

test_mycommand_basic() {
  assert_success "Basic command works" hanif mycommand action
}

suite "My Command"
run_test test_mycommand_basic
print_summary
```

### 5. Update Documentation

Add to README.md:

```markdown
### `hanif mycommand`

Description of your command.

Usage:
\`\`\`bash
hanif mycommand action
\`\`\`
```

## Pull Request Process

### 1. Before Submitting

- [ ] All tests pass (`npm test`)
- [ ] Code is linted (`npm run lint`)
- [ ] Documentation is updated
- [ ] CHANGELOG.md is updated (if applicable)
- [ ] Commit messages are clear and descriptive

### 2. Commit Messages

Use conventional commit format:

```
feat: add new command for XYZ
fix: correct branch naming issue
docs: update installation instructions
test: add tests for git sync
refactor: simplify error handling
```

### 3. Submit PR

1. Push your branch to your fork
2. Open a Pull Request against `main`
3. Fill out the PR template
4. Link related issues

### 4. PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Tests pass locally
- [ ] Added new tests
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
```

## Testing Guidelines

### Test Coverage

Aim for tests that cover:

- **Happy path**: Normal usage scenarios
- **Edge cases**: Empty inputs, long strings, special characters
- **Error cases**: Invalid inputs, missing files, git errors
- **Integration**: Commands working together

### Test Example

```bash
test_feature_with_edge_cases() {
  # Setup
  setup_git_repo
  
  # Test normal case
  assert_success "Normal input" hanif git nf "feature"
  
  # Test edge cases
  assert_success "Long name" hanif git nf "very long feature name that exceeds normal length"
  assert_success "Special chars" hanif git nf "feature: with-special_chars"
  
  # Test error cases
  assert_failure "Empty input" hanif git nf ""
  
  # Cleanup
  teardown_git_repo
}
```

## Documentation Standards

### README.md

- Clear installation instructions
- Quick start guide
- Complete command reference
- Examples for common use cases
- Troubleshooting section

### Code Comments

- Explain **why**, not **what**
- Document complex algorithms
- Note any workarounds or gotchas
- Keep comments up-to-date

### Help Text

- Concise but complete
- Include examples
- Show all options
- Link to detailed docs

## Release Process

1. Update version in:
   - `package.json`
   - `bin/hanif` (VERSION variable)
   - `hanif-cli.rb`

2. Update `CHANGELOG.md`

3. Create git tag:
```bash
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

4. Publish to npm:
```bash
npm publish
```

5. Update Homebrew formula

## Getting Help

- **Questions**: Open a [Discussion](https://github.com/yourusername/hanif-cli-tools/discussions)
- **Bugs**: Open an [Issue](https://github.com/yourusername/hanif-cli-tools/issues)
- **Security**: Email security@example.com

## Recognition

Contributors will be:
- Listed in README.md
- Mentioned in release notes
- Credited in git history

Thank you for contributing! 🎉
