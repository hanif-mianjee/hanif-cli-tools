# Development Guide

## Quick Setup

```bash
# Clone and install
git clone https://github.com/yourusername/hanif-cli-tools.git
cd hanif-cli-tools
bash scripts/dev-install.sh

# Test
hanif version
```

## Adding Commands

### 1. Create Command File

```bash
# lib/commands/docker.sh
docker_handler() {
  case "$1" in
    clean)
      info "Cleaning docker..."
      docker system prune -af
      success "Done!"
      ;;
    *)
      docker "$@"
      ;;
  esac
}
```

### 2. Register Command

Edit `bin/hanif`, add:

```bash
docker)
  source "${COMMANDS_DIR}/docker.sh"
  docker_handler "$@"
  ;;
```

### 3. Use It

```bash
hanif docker clean
hanif docker ps
```

## Available Utilities

From `lib/utils/common.sh`:

```bash
info "Message"        # Blue ℹ
success "Message"     # Green ✓
warning "Message"     # Yellow ⚠
error "Message"       # Red ✗

is_git_repo           # Check if in git repo
confirm "Question?"   # Y/N prompt
```

## Testing

```bash
# Run all tests
bash tests/run-tests.sh

# Create test file
# tests/test-mycommand.sh
source "$(dirname "$0")/test-framework.sh"

test_my_feature() {
  assert_success "Works" hanif mycommand
}

suite "My Tests"
run_test test_my_feature
print_summary
```

## Project Structure

```
bin/hanif              # Main CLI entry
lib/
  commands/            # Command handlers (add yours here)
  functions/           # Reusable functions
  utils/common.sh      # Helpers (info, success, error, etc.)
tests/                 # Test files
scripts/               # Build/install scripts
```

## Publishing

```bash
# Update version in package.json and bin/hanif
npm publish
```

That's it! Keep it simple.

### Component Overview

```
┌─────────────────────────────────────────────────┐
│                  bin/hanif                      │
│           (Main CLI Entry Point)                │
└────────────────┬────────────────────────────────┘
                 │
         ┌───────┴────────┐
         │                │
    ┌────▼─────┐    ┌────▼─────┐
    │ Commands │    │  Utils   │
    │          │    │          │
    │ git.sh   │    │common.sh │
    │ help.sh  │    └──────────┘
    └────┬─────┘
         │
    ┌────▼─────────┐
    │  Functions   │
    │              │
    │git-functions │
    └──────────────┘
```

### Data Flow

1. User runs `hanif git nf "feature"`
2. `bin/hanif` parses command: `git`
3. Sources `lib/commands/git.sh`
4. Calls `git_command` with args: `["nf", "feature"]`
5. Git command handler calls `newfeature "feature"`
6. Function creates branch and reports success

## Code Organization

### Main Executable (`bin/hanif`)

**Purpose**: Command dispatcher and entry point

**Responsibilities**:
- Parse top-level command
- Source appropriate command handler
- Handle version/help flags
- Set up environment variables

**Key Variables**:
```bash
SCRIPT_DIR      # Directory of the executable
LIB_DIR         # Library directory
COMMANDS_DIR    # Command handlers directory
UTILS_DIR       # Utilities directory
FUNCTIONS_DIR   # Functions directory
VERSION         # CLI version
```

### Command Handlers (`lib/commands/`)

**Purpose**: Handle specific command categories

**Pattern**:
```bash
# Each command file exports a handler function
command_handler() {
  # Parse subcommands
  # Validate inputs
  # Call appropriate functions
  # Handle errors
}
```

**Example**: `git.sh` handles all git subcommands

### Functions (`lib/functions/`)

**Purpose**: Core business logic

**Guidelines**:
- One function = one responsibility
- Return meaningful exit codes
- Use descriptive function names
- Document complex logic

### Utilities (`lib/utils/`)

**Purpose**: Shared helper functions

**Common Utilities**:
- Logging (info, success, warning, error)
- Git helpers (is_git_repo, get_current_branch)
- String utilities (sanitize_branch_name, truncate_string)
- User interaction (confirm, header, separator)

## Development Environment

### Prerequisites

```bash
# macOS
brew install bash git node shellcheck shfmt

# Linux (Ubuntu/Debian)
apt-get install bash git nodejs shellcheck shfmt
```

### Local Setup

```bash
# 1. Clone repository
git clone https://github.com/yourusername/hanif-cli-tools.git
cd hanif-cli-tools

# 2. Make scripts executable
chmod +x bin/hanif
chmod +x lib/commands/*.sh
chmod +x lib/functions/*.sh
chmod +x tests/*.sh
chmod +x scripts/*.sh

# 3. Link for development
ln -sf "$PWD/bin/hanif" ~/.local/bin/hanif

# 4. Verify
hanif version
```

### Development Workflow

#### 1. Feature Development

```bash
# Create feature branch
hanif git nf "add-awesome-feature"

# Edit files
vim lib/commands/mycommand.sh

# Test locally
./bin/hanif mycommand test

# Run tests
npm test

# Lint
npm run lint
```

#### 2. Debugging

Enable debug mode:

```bash
# Set debug flag
export DEBUG=1

# Run command
hanif git nf "test"

# Or inline
DEBUG=1 hanif git nf "test"
```

Add debug statements:

```bash
debug "Branch name: $branch_name"
debug "Current directory: $(pwd)"
```

#### 3. Testing Changes

```bash
# Test specific command
./bin/hanif git help

# Test in clean environment
unset HANIF_* 
./bin/hanif --help

# Test installation
./install.sh

# Test uninstallation
./install.sh uninstall
```

## Writing Tests

### Test Structure

```bash
#!/usr/bin/env bash

set -euo pipefail

# Source framework
source "$(dirname "$0")/test-framework.sh"

# Setup (runs before each test)
setup() {
  TEST_DIR=$(mktemp -d)
  cd "$TEST_DIR"
  git init
}

# Teardown (runs after each test)
teardown() {
  cd /
  rm -rf "$TEST_DIR"
}

# Test function
test_feature() {
  local result
  result=$(hanif mycommand)
  assert_equals "Command output" "expected" "$result"
}

# Run tests
suite "My Feature"
run_test test_feature
print_summary
```

### Assertion Functions

```bash
# Success/failure
assert_success "Description" command arg1 arg2
assert_failure "Description" command arg1 arg2

# Equality
assert_equals "Description" "expected" "$actual"

# String contains
assert_contains "Description" "$haystack" "needle"

# File/directory existence
assert_file_exists "Description" "/path/to/file"
assert_dir_exists "Description" "/path/to/dir"
```

### Test Best Practices

1. **Isolation**: Each test should be independent
2. **Cleanup**: Always clean up in teardown
3. **Descriptive**: Use clear test descriptions
4. **Coverage**: Test happy path and edge cases
5. **Fast**: Keep tests quick to run

## Shell Scripting Guidelines

### Error Handling

Always use strict mode:

```bash
#!/usr/bin/env bash
set -euo pipefail

# -e: Exit on error
# -u: Error on undefined variable
# -o pipefail: Pipe fails if any command fails
```

Handle errors explicitly:

```bash
if ! git checkout "$branch"; then
  error "Failed to checkout branch: $branch"
  return 1
fi

# Or with ||
git checkout "$branch" || {
  error "Checkout failed"
  return 1
}
```

### Variable Handling

```bash
# Always quote variables
echo "$variable"
echo "${variable}"

# Use local in functions
my_function() {
  local var="value"
}

# Default values
name="${1:-default}"

# Check if set
if [[ -n "$variable" ]]; then
  echo "Variable is set"
fi
```

### Function Design

```bash
# Good: Single responsibility
get_branch_name() {
  git rev-parse --abbrev-ref HEAD
}

# Bad: Multiple responsibilities
get_and_checkout_branch() {
  local branch=$(git rev-parse --abbrev-ref HEAD)
  git checkout "$branch"
}

# Return codes
success_function() {
  return 0  # Success
}

error_function() {
  return 1  # Error
}
```

### Command Execution

```bash
# Capture output
output=$(command)

# Check exit code
if command; then
  success "Command succeeded"
fi

# Suppress output
command >/dev/null 2>&1

# Pipe with error handling
set -o pipefail
cat file | grep pattern | sort
```

## Performance Considerations

### Minimize Git Operations

```bash
# Bad: Multiple fetches
git fetch origin
git fetch upstream

# Good: Single fetch
git fetch --all
```

### Avoid Subshells

```bash
# Bad: Creates subshell
result=$(cat file | grep pattern)

# Good: Use built-ins
result=$(grep pattern file)
```

### Cache Results

```bash
# Bad: Multiple calls
git rev-parse --abbrev-ref HEAD
git rev-parse --abbrev-ref HEAD

# Good: Cache in variable
current_branch=$(git rev-parse --abbrev-ref HEAD)
echo "$current_branch"
```

## Compatibility

### Shell Compatibility

Target: bash 4.0+ and zsh 5.0+

**Avoid**:
- Bash 5+ only features
- Zsh-specific syntax
- GNU-only utilities

**Use**:
- POSIX-compatible where possible
- Test on both bash and zsh
- Provide fallbacks for missing features

### Platform Compatibility

Primary: macOS and Linux

**Considerations**:
- Path separators (use `/`)
- Temp directories (use `mktemp`)
- Command availability (check with `command -v`)
- Different versions of tools (grep, sed, etc.)

### Git Compatibility

Minimum: Git 2.0+

**Check version**:
```bash
check_git_version() {
  local version
  version=$(git --version | grep -oE '[0-9]+\.[0-9]+')
  # Compare versions
}
```

## Packaging

### npm Package

**Files included**:
```json
{
  "files": [
    "bin/",
    "lib/",
    "README.md",
    "LICENSE"
  ]
}
```

**Publishing**:
```bash
npm version patch  # or minor, major
npm publish
```

### Homebrew Formula

**Update version**:
```ruby
version "1.0.0"
url "https://github.com/user/repo/archive/v1.0.0.tar.gz"
sha256 "..." # Generate with: shasum -a 256 file.tar.gz
```

**Test formula**:
```bash
brew install --build-from-source ./hanif-cli.rb
brew test hanif-cli
brew audit --strict hanif-cli
```

## Continuous Integration

### GitHub Actions Example

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
    
    steps:
      - uses: actions/checkout@v2
      
      - name: Install dependencies
        run: |
          sudo apt-get install shellcheck || brew install shellcheck
      
      - name: Run tests
        run: npm test
      
      - name: Run linter
        run: npm run lint
```

## Security

### Input Validation

```bash
# Validate required arguments
if [[ $# -eq 0 ]]; then
  error "Missing required argument"
  return 1
fi

# Sanitize user input
safe_name=$(sanitize_branch_name "$user_input")

# Avoid code injection
# Bad: eval "$user_input"
# Good: "$user_input" (quoted, not evaluated)
```

### File Operations

```bash
# Use absolute paths
file="/absolute/path/to/file"

# Validate paths
if [[ ! -f "$file" ]]; then
  error "File does not exist"
  return 1
fi

# Avoid traversal
# Bad: rm -rf "$user_input"
# Good: Validate and sanitize first
```

## Documentation

### Code Comments

```bash
# Good: Explain why
# Use grep -E because BSD grep doesn't support -P
result=$(grep -E "pattern" file)

# Bad: Explain what (obvious from code)
# Assign result to variable
result=$(grep pattern file)
```

### Function Documentation

```bash
# Brief description of function
#
# Arguments:
#   $1 - Branch name
#   $2 - Base branch (optional, default: main)
#
# Returns:
#   0 on success, 1 on error
#
# Example:
#   create_branch "feature/new" "main"
create_branch() {
  local branch="$1"
  local base="${2:-main}"
  # ...
}
```

## Troubleshooting

### Common Issues

**Command not found**
```bash
# Check PATH
echo $PATH

# Check if file exists
ls -la ~/.local/bin/hanif

# Check if executable
chmod +x ~/.local/bin/hanif
```

**Git errors**
```bash
# Enable git debugging
GIT_TRACE=1 hanif git up

# Check git configuration
git config --list
```

**Permission issues**
```bash
# Fix permissions
chmod +x bin/hanif
chmod +x lib/**/*.sh
```

## Resources

- [Bash Guide](https://mywiki.wooledge.org/BashGuide)
- [ShellCheck](https://www.shellcheck.net/)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [Git Documentation](https://git-scm.com/doc)

## Questions?

Open an issue or discussion on GitHub!
