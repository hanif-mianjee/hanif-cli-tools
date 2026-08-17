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
  
  # Punctuation separates words rather than being deleted — deleting it glued
  # "a.b" into "ab", which mangled dotted identifiers pasted from ticket titles.
  result=$(sanitize_branch_name "Test!@#$%Feature")
  assert_equals "Sanitize with special chars" "test_feature" "$result"

  result=$(sanitize_branch_name "catalog.my_table")
  assert_equals "Sanitize keeps dotted identifiers separated" "catalog_my_table" "$result"
  
  # Note: leading/trailing spaces become underscores, then get trimmed
  result=$(sanitize_branch_name "Test__Feature")
  assert_equals "Sanitize with extra underscores" "test_feature" "$result"

  result=$(sanitize_branch_name "fix - bug")
  assert_equals "Sanitize with dash surrounded by spaces" "fix_bug" "$result"

  result=$(sanitize_branch_name "add / feature")
  assert_equals "Sanitize with slash surrounded by spaces" "add_feature" "$result"

  result=$(sanitize_branch_name "hello   world")
  assert_equals "Sanitize with multiple spaces" "hello_world" "$result"
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

# Test: Git helper - newfeature with special characters
test_newfeature_special_chars() {
  source "$UTILS_DIR/common.sh"
  source "$FUNCTIONS_DIR/git-functions.sh"

  newfeature "fix - bug" >/dev/null 2>&1

  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD)

  assert_equals "Creates branch without double underscores" "feature/fix_bug" "$current_branch"
}

# Test: Git helper - newfeature with bracket characters (e.g. Jira titles like
# "OM-1460: [Data loader] - Loader Failed").  These chars arrive quoted from
# the shell layer; the sanitizer must strip [] and produce a clean branch name.
test_newfeature_bracket_chars() {
  source "$UTILS_DIR/common.sh"
  source "$FUNCTIONS_DIR/git-functions.sh"

  newfeature "OM-1460: [Data loader] - Loader Failed" >/dev/null 2>&1

  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD)

  assert_equals "Creates branch from bracket-containing description" \
    "feature/OM-1460_data_loader_loader_failed" "$current_branch"
}

# Test: Git helper - newfeature with a dotted identifier in the title.
# Regression: punctuation used to be deleted rather than treated as a word
# separator, so "catalog.my_table" collapsed into "catalogmy_table". Backticks
# and angle brackets are also stripped safely.
test_newfeature_dotted_identifier() {
  source "$UTILS_DIR/common.sh"
  source "$FUNCTIONS_DIR/git-functions.sh"

  newfeature 'OM-900: create `<env>_catalog.my_table` in all envs' >/dev/null 2>&1

  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD)

  assert_equals "Dotted identifiers keep word boundaries" \
    "feature/OM-900_create_env_catalog_my_table_in_all_envs" "$current_branch"
}

# Test: Git helper - newfeature truncates at a word boundary, not mid-word.
test_newfeature_truncates_on_word_boundary() {
  source "$UTILS_DIR/common.sh"
  source "$FUNCTIONS_DIR/git-functions.sh"

  newfeature "OM-901: add a very long descriptive branch name that exceeds the limit" >/dev/null 2>&1

  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD)

  assert_equals "Truncates back to the last whole word" \
    "feature/OM-901_add_a_very_long_descriptive_branch_name_that" "$current_branch"
  assert_success "Truncated name stays within 60 chars" \
    test "${#current_branch}" -le 60
}

# Test: Git helper - newfeature honours --prefix
test_newfeature_custom_prefix() {
  source "$UTILS_DIR/common.sh"
  source "$FUNCTIONS_DIR/git-functions.sh"

  newfeature --prefix hotfix "OM-755: fix login bug" >/dev/null 2>&1

  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD)

  assert_equals "Creates branch under a custom prefix" "hotfix/OM-755_fix_login_bug" "$current_branch"
}

# Test: Git helper - newfeature honours --no-prefix
test_newfeature_no_prefix() {
  source "$UTILS_DIR/common.sh"
  source "$FUNCTIONS_DIR/git-functions.sh"

  newfeature --no-prefix "spike idea" >/dev/null 2>&1

  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD)

  assert_equals "Creates a bare branch with no prefix" "spike_idea" "$current_branch"
}

# Test: Git helper - newfeature honours $HANIF_NF_PREFIX
test_newfeature_env_prefix() {
  source "$UTILS_DIR/common.sh"
  source "$FUNCTIONS_DIR/git-functions.sh"

  HANIF_NF_PREFIX=bugfix newfeature "OM-756: bad join" >/dev/null 2>&1

  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD)

  assert_equals "HANIF_NF_PREFIX sets the default prefix" "bugfix/OM-756_bad_join" "$current_branch"
}

# Test: Git helper - newfeature refuses a description that sanitizes to nothing
# instead of handing git a bare "feature/" ref.
test_newfeature_empty_after_sanitize() {
  source "$UTILS_DIR/common.sh"
  source "$FUNCTIONS_DIR/git-functions.sh"

  local before
  before=$(git rev-parse --abbrev-ref HEAD)

  assert_failure "Refuses a description with no usable characters" \
    newfeature '!!!'

  local after
  after=$(git rev-parse --abbrev-ref HEAD)
  assert_equals "Branch is unchanged after refusal" "$before" "$after"
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
  run_test test_newfeature_special_chars
  run_test test_newfeature_bracket_chars
  run_test test_newfeature_dotted_identifier
  run_test test_newfeature_truncates_on_word_boundary
  run_test test_newfeature_custom_prefix
  run_test test_newfeature_no_prefix
  run_test test_newfeature_env_prefix
  run_test test_newfeature_empty_after_sanitize
  
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
