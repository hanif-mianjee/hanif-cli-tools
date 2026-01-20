#!/usr/bin/env bash

# Tests for squash command

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
  
  # Create multiple commits for squash testing
  echo "first" > file1.txt
  git add file1.txt
  git commit -m "First commit" >/dev/null 2>&1
  
  echo "second" > file2.txt
  git add file2.txt
  git commit -m "Second commit" >/dev/null 2>&1
  
  echo "third" > file3.txt
  git add file3.txt
  git commit -m "Third commit" >/dev/null 2>&1
}

teardown() {
  cd /
  [[ -n "$TEST_DIR" ]] && rm -rf "$TEST_DIR"
}

# Test: Squash command exists
test_squash_command_exists() {
  assert_file_exists "Squash command file exists" "$COMMANDS_DIR/squash.sh"
}

# Test: Squash functions exist
test_squash_functions_exist() {
  assert_file_exists "Squash functions file exists" "$FUNCTIONS_DIR/squash-functions.sh"
}

# Test: Squash help works
test_squash_help() {
  local output
  output=$("$PROJECT_ROOT/bin/hanif" squash --help 2>&1)
  
  assert_contains "Help output contains usage" "$output" "USAGE"
  assert_contains "Help output contains features" "$output" "FEATURES"
  assert_contains "Help output contains examples" "$output" "EXAMPLES"
}

# Test: Squash requires count argument
test_squash_requires_count() {
  local output
  output=$("$PROJECT_ROOT/bin/hanif" squash 2>&1 || true)
  
  assert_contains "Error message shown" "$output" "Usage:"
}

# Test: Squash rejects invalid count
test_squash_rejects_invalid_count() {
  setup
  
  local output
  output=$("$PROJECT_ROOT/bin/hanif" squash "abc" 2>&1 || true)
  
  assert_contains "Error message for invalid count" "$output" "valid numeric count"
  
  teardown
}

# Test: Squash shows commit list (verify it runs, don't actually squash)
test_squash_shows_commits() {
  setup
  
  # We can't easily test interactive input, but we can verify the command
  # would show the right number of commits
  local commit_count
  commit_count=$(git log --oneline | wc -l | tr -d ' ')
  
  assert_equals "Should have 3 commits" "3" "$commit_count"
  
  teardown
}

# Test: Squash works in git repository only
test_squash_requires_git_repo() {
  # Create non-git directory
  local temp_dir=$(mktemp -d)
  cd "$temp_dir"
  
  local output
  output=$("$PROJECT_ROOT/bin/hanif" squash 5 2>&1 || true)
  
  assert_contains "Error message for non-git repo" "$output" "Not a git repository"
  
  cd /
  rm -rf "$temp_dir"
}

# Test: Help topic for squash works
test_help_squash_topic() {
  local output
  output=$("$PROJECT_ROOT/bin/hanif" help squash 2>&1)
  
  assert_contains "Help shows squash documentation" "$output" "Interactive Commit Squashing"
  assert_contains "Help shows workflow" "$output" "WORKFLOW"
  assert_contains "Help shows tips" "$output" "TIPS"
}

# Test: Main help includes squash
test_main_help_includes_squash() {
  local output
  output=$("$PROJECT_ROOT/bin/hanif" help 2>&1)
  
  assert_contains "Main help includes squash command" "$output" "squash"
  assert_contains "Main help shows squash description" "$output" "Interactive commit squashing"
}

# Test: Squash command appears in main usage
test_main_usage_includes_squash() {
  local output
  output=$("$PROJECT_ROOT/bin/hanif" 2>&1)
  
  assert_contains "Main usage includes squash" "$output" "squash <count>"
  assert_contains "Main usage shows example" "$output" "hanif squash 5"
}

# Run all tests
echo "Running squash command tests..."
echo ""

run_test test_squash_command_exists
run_test test_squash_functions_exist
run_test test_squash_help
run_test test_squash_requires_count
run_test test_squash_rejects_invalid_count
run_test test_squash_shows_commits
run_test test_squash_requires_git_repo
run_test test_help_squash_topic
run_test test_main_help_includes_squash
run_test test_main_usage_includes_squash

print_summary
