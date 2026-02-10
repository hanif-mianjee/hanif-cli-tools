# Development Guide

## Quick Setup

```bash
git clone https://github.com/hanif-mianjee/hanif-cli-tools.git
cd hanif-cli-tools
bash scripts/dev-install.sh
hanif version
```

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  bin/hanif                       │
│           (Main CLI Entry Point)                │
└────────────────┬────────────────────────────────┘
                 │
         ┌───────┴────────┐
         │                │
    ┌────▼─────┐    ┌────▼─────┐
    │ Commands │    │  Utils   │
    │          │    │          │
    │ git.sh   │    │common.sh │
    │ squash.sh│    └──────────┘
    │ svg.sh   │
    │ help.sh  │
    └────┬─────┘
         │
    ┌────▼─────────┐
    │  Functions   │
    │              │
    │git-functions │
    │squash-funcs  │
    │svg-functions │
    └──────────────┘
```

### Data Flow

1. User runs `hanif nf "feature"`
2. `bin/hanif` matches `nf` → sources `lib/commands/git.sh`
3. Calls `git_command nf "feature"`
4. Git command handler calls `newfeature "feature"`
5. Function creates branch and reports success

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

Edit `bin/hanif`, add to the case statement:

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
info "Message"        # Blue info
success "Message"     # Green checkmark
warning "Message"     # Yellow warning
error "Message"       # Red error

is_git_repo           # Check if in git repo
get_current_branch    # Get current branch name
confirm "Question?"   # Y/N prompt
debug "Message"       # Only shown with DEBUG=1
```

## Testing

```bash
# Run all tests
bash tests/run-tests.sh

# Run specific test
bash tests/test-git.sh

# Debug mode
DEBUG=1 bash tests/test-git.sh
```

### Writing Tests

```bash
# tests/test-mycommand.sh
source "$(dirname "$0")/test-framework.sh"

test_my_feature() {
  assert_success "Works" hanif mycommand
}

suite "My Tests"
run_test test_my_feature
print_summary
```

### Assertions

```bash
assert_success "Description" command arg1 arg2
assert_failure "Description" command arg1 arg2
assert_equals "Description" "expected" "$actual"
assert_contains "Description" "$haystack" "needle"
assert_file_exists "Description" "/path/to/file"
```

## Debugging

```bash
# Enable debug output
DEBUG=1 hanif sync

# Git-level debugging
GIT_TRACE=1 hanif up
```

## Publishing

```bash
bash scripts/publish.sh
```

## Key Variables (bin/hanif)

```bash
SCRIPT_DIR      # Directory of the executable
LIB_DIR         # Library directory
COMMANDS_DIR    # Command handlers directory
UTILS_DIR       # Utilities directory
FUNCTIONS_DIR   # Functions directory
VERSION         # CLI version
```
