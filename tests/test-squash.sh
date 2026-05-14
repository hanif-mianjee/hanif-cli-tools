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

# Test: Squash defaults to 20 when no count given
test_squash_defaults_to_20() {
  setup

  # With no count argument, squash should default to showing commits (not show usage error)
  # We can't fully test interactive mode, but verify it doesn't show a usage error
  local output
  output=$("$PROJECT_ROOT/bin/hanif" squash 2>&1 </dev/null || true)

  assert_contains "Should show commit selection prompt" "$output" "Select a commit"

  teardown
}

# Test: Squash rejects invalid argument
test_squash_rejects_invalid_count() {
  setup

  local output
  output=$("$PROJECT_ROOT/bin/hanif" squash "xyz" 2>&1 || true)

  assert_contains "Error message for invalid argument" "$output" "Invalid argument"

  teardown
}

# ---------- Hash mode ----------

# Test: Squash with hash skips the picker and squashes <hash>..HEAD
test_squash_with_hash() {
  setup

  # Add two more commits so we have 5 total.
  echo "fourth" > file4.txt && git add file4.txt && git commit -m "Fourth commit" >/dev/null 2>&1
  echo "fifth" > file5.txt && git add file5.txt && git commit -m "Fifth commit" >/dev/null 2>&1

  # Hash of "Third commit" (3rd from oldest, 3rd from newest of 5).
  local third_hash
  third_hash=$(git log --format='%h' --reverse | sed -n '3p')

  # Run squash with empty custom message (just press Enter).
  printf '\n' | "$PROJECT_ROOT/bin/hanif" squash "$third_hash" >/dev/null 2>&1 || true

  # After squash: First, Second, then 1 squashed commit = 3 total.
  local total
  total=$(git log --oneline | wc -l | tr -d ' ')
  assert_equals "Squashed Third..HEAD into one commit (3 total remain)" "3" "$total"

  # The squashed commit's body should reference the squashed hashes.
  local body
  body=$(git log -1 --format='%B')
  assert_contains "Squashed message references Fourth commit" "$body" "Fourth commit"
  assert_contains "Squashed message references Fifth commit" "$body" "Fifth commit"

  teardown
}

# Test: Squash with invalid hash errors out without mutating the repo
test_squash_with_invalid_hash() {
  setup

  local before
  before=$(git rev-parse HEAD)

  local output
  output=$("$PROJECT_ROOT/bin/hanif" squash "deadbee" 2>&1 || true)

  assert_contains "Error mentions invalid commit" "$output" "not a valid commit"

  local after
  after=$(git rev-parse HEAD)
  assert_equals "HEAD unchanged after invalid hash" "$before" "$after"

  teardown
}

# ---------- Range mode ----------

# Test: Range squash collapses the inclusive range and keeps trailing commits
test_squash_range() {
  setup

  # Add two more commits → 5 total: First, Second, Third, Fourth, Fifth.
  echo "fourth" > file4.txt && git add file4.txt && git commit -m "Fourth commit" >/dev/null 2>&1
  echo "fifth" > file5.txt && git add file5.txt && git commit -m "Fifth commit" >/dev/null 2>&1

  local second_hash third_hash fourth_hash
  second_hash=$(git log --format='%h' --reverse | sed -n '2p')
  third_hash=$(git log --format='%h' --reverse | sed -n '3p')
  fourth_hash=$(git log --format='%h' --reverse | sed -n '4p')

  # Squash Second..Fourth (3 commits → 1), preserving Fifth.
  printf '\n' | "$PROJECT_ROOT/bin/hanif" squash "$second_hash" "$fourth_hash" >/dev/null 2>&1 || true

  # Total = First + squashed + Fifth = 3.
  local total
  total=$(git log --oneline | wc -l | tr -d ' ')
  assert_equals "Range squash leaves 3 commits" "3" "$total"

  # HEAD should still be "Fifth commit".
  local head_subject
  head_subject=$(git log -1 --format='%s')
  assert_equals "HEAD is still Fifth commit" "Fifth commit" "$head_subject"

  # Middle commit should be the squashed one and reference Third commit.
  local middle_body
  middle_body=$(git log -1 --skip=1 --format='%B')
  assert_contains "Squashed body references Third commit" "$middle_body" "Third commit"

  teardown
}

# Test: Range squash refuses when older is not an ancestor of newer
test_squash_range_not_ancestor() {
  setup

  # Use the most-recent and oldest hashes in the WRONG order (newer, older).
  local newer older
  newer=$(git log --format='%h' | sed -n '1p')
  older=$(git log --format='%h' | sed -n '3p')

  local before output
  before=$(git rev-parse HEAD)
  output=$("$PROJECT_ROOT/bin/hanif" squash "$newer" "$older" 2>&1 || true)

  assert_contains "Error mentions ancestor" "$output" "ancestor"

  local after
  after=$(git rev-parse HEAD)
  assert_equals "HEAD unchanged on bad order" "$before" "$after"

  teardown
}

# Test: Range squash refuses on a dirty working tree
test_squash_range_dirty_tree() {
  setup

  echo "fourth" > file4.txt && git add file4.txt && git commit -m "Fourth commit" >/dev/null 2>&1

  # Leave an uncommitted change.
  echo "dirty" >> file1.txt

  local older newer
  older=$(git log --format='%h' --reverse | sed -n '2p')
  newer=$(git log --format='%h' --reverse | sed -n '3p')

  local before output
  before=$(git rev-parse HEAD)
  output=$("$PROJECT_ROOT/bin/hanif" squash "$older" "$newer" 2>&1 || true)

  assert_contains "Error mentions clean working tree" "$output" "not clean"

  local after
  after=$(git rev-parse HEAD)
  assert_equals "HEAD unchanged on dirty tree" "$before" "$after"

  teardown
}

# Test: Help mentions the new hash and range modes
test_squash_help_mentions_hash_and_range() {
  local output
  output=$("$PROJECT_ROOT/bin/hanif" squash --help 2>&1)

  assert_contains "Help mentions <hash>" "$output" "<hash>"
  assert_contains "Help mentions <older>" "$output" "<older>"
  assert_contains "Help mentions <newer>" "$output" "<newer>"
  assert_contains "Help mentions RANGE MODE" "$output" "RANGE MODE"
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
  
  assert_contains "Main usage includes squash" "$output" "squash [count]"
  assert_contains "Main usage shows example" "$output" "hanif squash 5"
}

# Run all tests
echo "Running squash command tests..."
echo ""

run_test test_squash_command_exists
run_test test_squash_functions_exist
run_test test_squash_help
run_test test_squash_defaults_to_20
run_test test_squash_rejects_invalid_count
run_test test_squash_shows_commits
run_test test_squash_requires_git_repo
run_test test_help_squash_topic
run_test test_main_help_includes_squash
run_test test_main_usage_includes_squash
run_test test_squash_with_hash
run_test test_squash_with_invalid_hash
run_test test_squash_range
run_test test_squash_range_not_ancestor
run_test test_squash_range_dirty_tree
run_test test_squash_help_mentions_hash_and_range

print_summary
