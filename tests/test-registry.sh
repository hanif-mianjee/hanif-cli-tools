#!/usr/bin/env bash
#
# Tests for the command registry (lib/registry.sh) and the auto-discovery
# wiring in bin/hanif.
#
# All tests run in an isolated environment:
#   * a fresh temp directory as $HOME (so update-check cache cannot pollute
#     the host)
#   * HANIF_SKIP_UPDATE_CHECK set to skip the background update check
#   * Each test that needs a git repo creates one in mktemp -d

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HANIF="$PROJECT_ROOT/bin/hanif"

# shellcheck source=test-framework.sh
source "$SCRIPT_DIR/test-framework.sh"

# Isolation: fake HOME so update-check cannot touch the real one.
TEST_HOME=""
setup() {
  TEST_HOME=$(mktemp -d)
  export HOME="$TEST_HOME"
  export HANIF_SKIP_UPDATE_CHECK=1
}
teardown() {
  [[ -n "$TEST_HOME" && -d "$TEST_HOME" ]] && rm -rf "$TEST_HOME"
  unset HANIF_SKIP_UPDATE_CHECK
}

# ---------------------------------------------------------------------------
# Registry unit tests — load registry.sh in a subshell and exercise its API.
# ---------------------------------------------------------------------------

# Run a snippet against a fresh registry. The snippet is fed via stdin
# (heredoc) rather than interpolated into ``bash -c "$1"``, so test inputs
# cannot accidentally form an injection vector.
_with_registry() {
  bash <<EOF
set -euo pipefail
source "$PROJECT_ROOT/lib/registry.sh"
$1
EOF
}

test_register_and_lookup() {
  local out
  out=$(_with_registry '
    register_command --name "foo" --handler "h_foo" --description "do foo"
    register_command --name "bar" --aliases "b z" --handler "h_bar" --description "do bar"
    h_foo() { echo "foo:$*"; }
    h_bar() { echo "bar:$*"; }

    registry_has foo && echo "has-foo"
    registry_has b   && echo "has-alias-b"
    registry_has z   && echo "has-alias-z"
    registry_has missing || echo "no-missing"

    dispatch_command foo one two
    dispatch_command b   alias-arg
  ')
  assert_contains "registry_has finds primary name"  "$out" "has-foo"
  assert_contains "registry_has finds first alias"   "$out" "has-alias-b"
  assert_contains "registry_has finds second alias"  "$out" "has-alias-z"
  assert_contains "registry_has rejects unknown"     "$out" "no-missing"
  assert_contains "dispatch passes args by name"     "$out" "foo:one two"
  assert_contains "dispatch passes args by alias"    "$out" "bar:alias-arg"
}

test_register_requires_name_and_handler() {
  # --name without --handler should fail with non-zero.
  if _with_registry 'register_command --name foo' >/dev/null 2>&1; then
    ((TESTS_RUN++)) || true
    ((TESTS_FAILED++)) || true
    echo -e "\033[0;31m✗\033[0m register_command rejects missing --handler"
  else
    ((TESTS_RUN++)) || true
    ((TESTS_PASSED++)) || true
    echo -e "\033[0;32m✓\033[0m register_command rejects missing --handler"
  fi

  if _with_registry 'register_command --handler h' >/dev/null 2>&1; then
    ((TESTS_RUN++)) || true
    ((TESTS_FAILED++)) || true
    echo -e "\033[0;31m✗\033[0m register_command rejects missing --name"
  else
    ((TESTS_RUN++)) || true
    ((TESTS_PASSED++)) || true
    echo -e "\033[0;32m✓\033[0m register_command rejects missing --name"
  fi
}

test_dispatch_propagates_exit_code() {
  local out
  out=$(_with_registry '
    register_command --name failing --handler h_fail
    h_fail() { return 42; }
    set +e
    dispatch_command failing
    echo "rc=$?"
  ')
  assert_contains "Dispatcher returns the handler exit code" "$out" "rc=42"
}

test_dispatch_unknown_returns_127() {
  local out
  out=$(_with_registry '
    set +e
    dispatch_command no_such_cmd
    echo "rc=$?"
  ')
  assert_contains "Dispatcher returns 127 for unknown command" "$out" "rc=127"
}

test_groups_and_print() {
  local out
  out=$(_with_registry '
    register_command --name a --handler ha --group "Git"   --description "ga"
    register_command --name b --handler hb --group "Other" --description "gb"
    register_command --name c --handler hc --group "Git"   --description "gc"
    registry_groups
    echo "---"
    registry_print_group "Git"
  ')
  assert_contains "registry_groups lists Git"          "$out" "Git"
  assert_contains "registry_groups lists Other"        "$out" "Other"
  assert_contains "registry_print_group lists 'a'"     "$out" "a "
  assert_contains "registry_print_group lists 'c'"     "$out" "c "
  assert_contains "registry_print_group shows desc"    "$out" "gc"
}

test_registry_count_grows() {
  local out
  out=$(_with_registry '
    n0=$(registry_count)
    register_command --name x --handler hx
    register_command --name y --handler hy
    n1=$(registry_count)
    echo "before=$n0 after=$n1"
  ')
  assert_contains "registry_count before/after" "$out" "before=0 after=2"
}

# ---------------------------------------------------------------------------
# Integration tests — verify the live CLI uses the registry correctly.
# ---------------------------------------------------------------------------

test_cli_registers_expected_commands() {
  # Source registry.sh + every command file the same way bin/hanif does, then
  # check that all the expected names/aliases resolve.
  local out
  out=$(
    LIB_DIR="$PROJECT_ROOT/lib" \
    UTILS_DIR="$PROJECT_ROOT/lib/utils" \
    COMMANDS_DIR="$PROJECT_ROOT/lib/commands" \
    FUNCTIONS_DIR="$PROJECT_ROOT/lib/functions" \
    bash -c '
      set -euo pipefail
      source "$UTILS_DIR/common.sh"
      source "$LIB_DIR/registry.sh"
      shopt -s nullglob
      for f in "$COMMANDS_DIR"/*.sh; do source "$f"; done
      for n in sync nf newfeature up update upall updateall clean rb rebase \
               pull st status amend gi gitignore git \
               squash bv bumpversion svg self-update; do
        if registry_has "$n"; then echo "OK:$n"; else echo "MISS:$n"; fi
      done
    '
  )
  for name in sync nf newfeature up update upall updateall clean rb rebase \
              pull st status amend gi gitignore git \
              squash bv bumpversion svg self-update; do
    assert_contains "Registry has $name" "$out" "OK:$name"
  done
}

test_cli_unknown_command_returns_1() {
  set +e
  "$HANIF" totally-bogus-command >/dev/null 2>&1
  local rc=$?
  set -e
  assert_equals "Unknown command exit code is 1" "1" "$rc"
}

test_cli_alias_routes_to_handler() {
  local tmp
  tmp=$(mktemp -d)
  (
    cd "$tmp"
    git init -q
    git config user.email "t@t"
    git config user.name "t"
    echo a > f && git add f && git commit -qm init
    "$HANIF" newfeature "alias test" >/dev/null 2>&1
    git rev-parse --abbrev-ref HEAD
  ) > "$tmp/branch.txt"
  local branch
  branch=$(cat "$tmp/branch.txt")
  rm -rf "$tmp"
  assert_equals "newfeature alias creates branch" "feature/alias_test" "$branch"
}

test_cli_legacy_git_passthrough_still_works() {
  local tmp output outfile
  tmp=$(mktemp -d)
  outfile=$(mktemp)
  (
    cd "$tmp"
    git init -q
    git config user.email "t@t"
    git config user.name "t"
    echo a > f && git add f && git commit -qm init
    "$HANIF" git status 2>&1
  ) > "$outfile"
  output=$(cat "$outfile")
  rm -rf "$tmp" "$outfile"
  assert_contains "Legacy 'hanif git status' passthrough works" "$output" "working tree clean"
}

test_cli_help_built_in() {
  # 'help' is a built-in pseudo-command (NOT in registry) and must work.
  local out
  out=$("$HANIF" help 2>&1)
  assert_contains "Built-in help shows USAGE" "$out" "USAGE"
}

test_cli_help_topics_resolve() {
  # The help router calls show_*_help functions defined in each command file.
  # These are made available by bin/hanif sourcing every lib/commands/*.sh at
  # startup. This test guards that wiring against future regression.
  local out
  out=$("$HANIF" help git 2>&1)
  assert_contains   "help git resolves"   "$out" "Git Helper Commands"
  out=$("$HANIF" help squash 2>&1)
  assert_contains   "help squash resolves" "$out" "Interactive Commit Squashing"
  out=$("$HANIF" help bv 2>&1)
  assert_contains   "help bv resolves"     "$out" "Version Bumping Tool"
  out=$("$HANIF" help svg 2>&1)
  assert_contains   "help svg resolves"    "$out" "SVG Conversion Commands"
  # Git subcommand topics route to git help.
  out=$("$HANIF" help nf 2>&1)
  assert_contains   "help nf routes to git" "$out" "Git Helper Commands"
}

test_cli_skip_update_check_does_not_touch_home() {
  local fresh
  fresh=$(mktemp -d)
  (
    HOME="$fresh"
    HANIF_SKIP_UPDATE_CHECK=1
    "$HANIF" version >/dev/null 2>&1
  )
  # Nothing should have been written to the fake HOME.
  if [[ -d "$fresh/.hanif-cli" ]]; then
    ((TESTS_RUN++)) || true
    ((TESTS_FAILED++)) || true
    echo -e "\033[0;31m✗\033[0m HOME stays clean when HANIF_SKIP_UPDATE_CHECK is set"
  else
    ((TESTS_RUN++)) || true
    ((TESTS_PASSED++)) || true
    echo -e "\033[0;32m✓\033[0m HOME stays clean when HANIF_SKIP_UPDATE_CHECK is set"
  fi
  rm -rf "$fresh"
}

# ---------------------------------------------------------------------------
# Run all
# ---------------------------------------------------------------------------
main() {
  suite "Registry unit"
  run_test test_register_and_lookup
  run_test test_register_requires_name_and_handler
  run_test test_dispatch_propagates_exit_code
  run_test test_dispatch_unknown_returns_127
  run_test test_groups_and_print
  run_test test_registry_count_grows

  suite "CLI integration"
  run_test test_cli_registers_expected_commands
  run_test test_cli_unknown_command_returns_1
  run_test test_cli_alias_routes_to_handler
  run_test test_cli_legacy_git_passthrough_still_works
  run_test test_cli_help_built_in
  run_test test_cli_help_topics_resolve
  run_test test_cli_skip_update_check_does_not_touch_home

  print_summary
}

main "$@"
