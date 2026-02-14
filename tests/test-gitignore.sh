#!/usr/bin/env bash

# Tests for gitignore command

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

# ── Core Functionality ──────────────────────────────

# Test: Creates .gitignore if it doesn't exist
test_creates_gitignore() {
  source "$UTILS_DIR/common.sh"
  source "$FUNCTIONS_DIR/git-functions.sh"

  # Ensure .gitignore does not exist
  rm -f .gitignore

  gitignore_add ".env" >/dev/null 2>&1

  assert_file_exists "Creates .gitignore when missing" ".gitignore"
}

# Test: Adds path to .gitignore
test_adds_path_to_gitignore() {
  source "$UTILS_DIR/common.sh"
  source "$FUNCTIONS_DIR/git-functions.sh"

  gitignore_add ".env" >/dev/null 2>&1

  local content
  content=$(cat .gitignore)
  assert_contains "Adds path to .gitignore" "$content" ".env"
}

# Test: Prevents duplicate entries
test_prevents_duplicates() {
  source "$UTILS_DIR/common.sh"
  source "$FUNCTIONS_DIR/git-functions.sh"

  gitignore_add ".env" >/dev/null 2>&1
  gitignore_add ".env" >/dev/null 2>&1

  local count
  count=$(grep -cx ".env" .gitignore)
  assert_equals "Prevents duplicate .gitignore entries" "1" "$count"
}

# Test: Removes tracked file from git index
test_removes_from_index() {
  source "$UTILS_DIR/common.sh"
  source "$FUNCTIONS_DIR/git-functions.sh"

  # Create and track a file
  echo "secret" > .env
  git add .env
  git commit -m "Add .env" >/dev/null 2>&1

  gitignore_add ".env" >/dev/null 2>&1

  # File should no longer be tracked
  local tracked
  tracked=$(git ls-files .env)
  assert_equals "Removes file from git index" "" "$tracked"
}

# Test: Keeps file on disk after removing from index
test_keeps_file_on_disk() {
  source "$UTILS_DIR/common.sh"
  source "$FUNCTIONS_DIR/git-functions.sh"

  # Create and track a file
  echo "secret" > .env
  git add .env
  git commit -m "Add .env" >/dev/null 2>&1

  gitignore_add ".env" >/dev/null 2>&1

  assert_file_exists "File remains on disk" ".env"
}

# Test: Handles untracked files gracefully
test_untracked_file() {
  source "$UTILS_DIR/common.sh"
  source "$FUNCTIONS_DIR/git-functions.sh"

  # Create a file but don't track it
  echo "logs" > debug.log

  local output
  output=$(gitignore_add "debug.log" 2>&1)

  assert_contains "Reports untracked file" "$output" "not currently tracked"
  assert_file_exists ".gitignore created" ".gitignore"

  local content
  content=$(cat .gitignore)
  assert_contains "Path added to .gitignore" "$content" "debug.log"
}

# Test: Handles directories
test_directory_ignore() {
  source "$UTILS_DIR/common.sh"
  source "$FUNCTIONS_DIR/git-functions.sh"

  # Create and track a directory
  mkdir -p node_modules/pkg
  echo "module" > node_modules/pkg/index.js
  git add node_modules/
  git commit -m "Add node_modules" >/dev/null 2>&1

  gitignore_add "node_modules/" >/dev/null 2>&1

  local content
  content=$(cat .gitignore)
  assert_contains "Directory added to .gitignore" "$content" "node_modules/"

  # Directory should no longer be tracked
  local tracked
  tracked=$(git ls-files node_modules/)
  assert_equals "Directory removed from git index" "" "$tracked"

  # Directory should still exist on disk
  assert_dir_exists "Directory remains on disk" "node_modules"
}

# Test: Appends to existing .gitignore
test_appends_to_existing() {
  source "$UTILS_DIR/common.sh"
  source "$FUNCTIONS_DIR/git-functions.sh"

  # Create .gitignore with existing content
  echo "*.log" > .gitignore

  gitignore_add ".env" >/dev/null 2>&1

  local content
  content=$(cat .gitignore)
  assert_contains "Preserves existing entries" "$content" "*.log"
  assert_contains "Appends new entry" "$content" ".env"
}

# ── Error Handling ──────────────────────────────────

# Test: Fails without arguments
test_no_args_fails() {
  source "$UTILS_DIR/common.sh"
  source "$FUNCTIONS_DIR/git-functions.sh"

  assert_failure "Fails without arguments" gitignore_add
}

# Test: Fails outside git repository
test_not_git_repo() {
  source "$UTILS_DIR/common.sh"
  source "$FUNCTIONS_DIR/git-functions.sh"

  local non_git_dir
  non_git_dir=$(mktemp -d)
  cd "$non_git_dir"

  assert_failure "Fails outside git repo" gitignore_add ".env"

  rm -rf "$non_git_dir"
}

# ── CLI Integration ─────────────────────────────────

# Test: CLI shows gitignore help
test_cli_gitignore_help() {
  local output
  output=$("$PROJECT_ROOT/bin/hanif" gi --help 2>&1)

  assert_contains "Shows gitignore help" "$output" "GITIGNORE"
}

# Test: CLI routes gi shortcut
test_cli_gi_shortcut() {
  local output
  output=$("$PROJECT_ROOT/bin/hanif" help gi 2>&1)

  assert_contains "Help routes gi command" "$output" "GITIGNORE"
}

# Test: CLI gitignore full command name
test_cli_gitignore_full_name() {
  local output
  output=$("$PROJECT_ROOT/bin/hanif" help gitignore 2>&1)

  assert_contains "Help routes gitignore command" "$output" "GITIGNORE"
}

# Test: General help mentions gi command
test_general_help_mentions_gi() {
  local output
  output=$("$PROJECT_ROOT/bin/hanif" help 2>&1)

  assert_contains "General help shows gi command" "$output" "gi <path>"
}

# Run all tests
main() {
  suite "Gitignore Core Functions"
  run_test test_creates_gitignore
  run_test test_adds_path_to_gitignore
  run_test test_prevents_duplicates
  run_test test_removes_from_index
  run_test test_keeps_file_on_disk
  run_test test_untracked_file
  run_test test_directory_ignore
  run_test test_appends_to_existing

  suite "Gitignore Error Handling"
  run_test test_no_args_fails
  run_test test_not_git_repo

  suite "Gitignore CLI Integration"
  test_cli_gitignore_help
  test_cli_gi_shortcut
  test_cli_gitignore_full_name
  test_general_help_mentions_gi

  print_summary
}

main "$@"
