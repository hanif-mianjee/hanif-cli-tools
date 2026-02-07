#!/usr/bin/env bash

# Tests for git commands

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source test framework
source "$SCRIPT_DIR/test-framework.sh"

# Source the CLI (for testing)
export SCRIPT_DIR="$PROJECT_ROOT/bin"
export LIB_DIR="$PROJECT_ROOT/lib"
export COMMANDS_DIR="$LIB_DIR/commands"
export UTILS_DIR="$LIB_DIR/utils"
export FUNCTIONS_DIR="$LIB_DIR/functions"

# Create temporary test directory
TEST_DIR=""

setup() {
  TEST_DIR=$(mktemp -d)
  cd "$TEST_DIR"
  
  # Initialize a git repo for testing
  git init >/dev/null 2>&1
  git config user.email "test@example.com"
  git config user.name "Test User"
  
  # Create initial commit
  echo "test" > README.md
  git add README.md
  git commit -m "Initial commit" >/dev/null 2>&1
}

teardown() {
  cd /
  [[ -n "$TEST_DIR" ]] && rm -rf "$TEST_DIR"
}

# Test: Sanitize branch name
test_sanitize_branch_name() {
  source "$UTILS_DIR/common.sh"
  
  local result
  result=$(sanitize_branch_name "Test Feature")
  assert_equals "Sanitize with spaces" "test_feature" "$result"
  
  result=$(sanitize_branch_name "Test!@#$%Feature")
  assert_equals "Sanitize with special chars" "testfeature" "$result"
  
  # Note: leading/trailing spaces become underscores, then get trimmed
  result=$(sanitize_branch_name "Test__Feature")
  assert_equals "Sanitize with extra underscores" "test_feature" "$result"
}

# Test: Git helper - newfeature
test_newfeature_basic() {
  source "$UTILS_DIR/common.sh"
  source "$FUNCTIONS_DIR/git-functions.sh"
  
  # Create feature branch
  newfeature "test feature" >/dev/null 2>&1
  
  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  
  assert_equals "Creates feature branch" "feature/test_feature" "$current_branch"
}

# Test: Git helper - newfeature with ticket
test_newfeature_with_ticket() {
  source "$UTILS_DIR/common.sh"
  source "$FUNCTIONS_DIR/git-functions.sh"
  
  # Create feature branch with ticket
  newfeature "OM-755: fix login bug" >/dev/null 2>&1
  
  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  
  assert_equals "Creates feature branch with ticket" "feature/OM-755_fix_login_bug" "$current_branch"
}

# Test: CLI executable exists
test_cli_executable() {
  assert_file_exists "Main CLI executable exists" "$PROJECT_ROOT/bin/hanif"
}

# Test: CLI shows version
test_cli_version() {
  local output
  output=$("$PROJECT_ROOT/bin/hanif" version 2>&1)
  
  assert_contains "Shows version" "$output" "Hanif CLI v"
}

# Test: CLI shows help
test_cli_help() {
  local output
  output=$("$PROJECT_ROOT/bin/hanif" help 2>&1)
  
  assert_contains "Shows help" "$output" "USAGE"
}

# Test: Git command help (via legacy syntax)
test_git_help() {
  local output
  output=$("$PROJECT_ROOT/bin/hanif" git help 2>&1)

  assert_contains "Shows git help" "$output" "Git Helper Commands"
}

# Test: Shortcut commands route correctly
test_shortcut_help() {
  local output
  output=$("$PROJECT_ROOT/bin/hanif" help 2>&1)

  assert_contains "Help shows shortcut syntax" "$output" "hanif <command>"
}

# Test: Invalid command
test_invalid_command() {
  assert_failure "Rejects invalid command" "$PROJECT_ROOT/bin/hanif" invalidcommand
}

# Run all tests
main() {
  suite "Utility Functions"
  run_test test_sanitize_branch_name
  
  suite "Git Functions"
  run_test test_newfeature_basic
  run_test test_newfeature_with_ticket
  
  suite "CLI Interface"
  test_cli_executable
  test_cli_version
  test_cli_help
  test_git_help
  test_shortcut_help
  test_invalid_command
  
  print_summary
}

main "$@"
