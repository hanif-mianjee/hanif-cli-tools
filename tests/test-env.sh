#!/usr/bin/env bash
#
# Tests for `hanif env` — persistent environment variable management.
#
# All tests are isolated:
#   * Fresh mktemp dir as $HOME so we never touch the host profile.
#   * HANIF_SKIP_UPDATE_CHECK to skip the background update check.
#   * HANIF_ENV_SHELL=bash for deterministic profile selection.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HANIF="$PROJECT_ROOT/bin/hanif"

# shellcheck source=test-framework.sh
source "$SCRIPT_DIR/test-framework.sh"

TEST_HOME=""

setup() {
  TEST_HOME=$(mktemp -d)
  export HOME="$TEST_HOME"
  export HANIF_SKIP_UPDATE_CHECK=1
  export HANIF_ENV_SHELL=bash
  unset HANIF_ENV_FILE HANIF_ENV_PROFILE
}

teardown() {
  # Defensive: only delete TEST_HOME when it's a real, non-empty path under
  # a system temp dir (mktemp -d guarantees this; the guard exists in case
  # a future refactor accidentally clears or repoints the variable).
  if [[ -n "$TEST_HOME" && -d "$TEST_HOME" ]] \
     && [[ "$TEST_HOME" == /tmp/* || "$TEST_HOME" == /var/folders/* ]]; then
    rm -rf "$TEST_HOME"
  fi
  unset HANIF_SKIP_UPDATE_CHECK HANIF_ENV_SHELL
}

# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------

test_env_command_registered() {
  local out
  out=$("$HANIF" help 2>&1)
  assert_contains "Help mentions env command" "$out" "env <subcommand>"
}

test_env_help_topic_resolves() {
  local out
  out=$("$HANIF" help env 2>&1)
  assert_contains "help env shows banner" "$out" "Persistent Environment Variables"
  assert_contains "help env shows subcommands" "$out" "SUBCOMMANDS"
  out=$("$HANIF" env help 2>&1)
  assert_contains "env help shows banner" "$out" "Persistent Environment Variables"
}

test_env_e_alias_resolves() {
  local out
  out=$("$HANIF" e list 2>&1)
  assert_contains "e alias works" "$out" "Persistent Environment Variables"
}

# ---------------------------------------------------------------------------
# set / overwrite / write
# ---------------------------------------------------------------------------

test_env_set_writes_file_after_confirm() {
  printf "y\ny\ny\n" | "$HANIF" env set FOO=bar >/dev/null 2>&1
  assert_file_exists "Managed file created" "$TEST_HOME/.hanif/env.sh"
  local content
  content=$(cat "$TEST_HOME/.hanif/env.sh")
  assert_contains "File contains export line" "$content" "export FOO=bar"
}

test_env_set_aborts_on_decline() {
  printf 'n\n' | "$HANIF" env set FOO=bar >/dev/null 2>&1
  if [[ -f "$TEST_HOME/.hanif/env.sh" ]] && grep -q '^export FOO=' "$TEST_HOME/.hanif/env.sh" 2>/dev/null; then
    ((TESTS_RUN++)) || true
    ((TESTS_FAILED++)) || true
    echo -e "\033[0;31m✗\033[0m Declining the prompt does NOT write the variable"
  else
    ((TESTS_RUN++)) || true
    ((TESTS_PASSED++)) || true
    echo -e "\033[0;32m✓\033[0m Declining the prompt does NOT write the variable"
  fi
}

test_env_set_space_separated_form() {
  printf "y\ny\ny\n" | "$HANIF" env set DATABASE_URL "postgres://u:p@h/db" >/dev/null 2>&1
  local content
  content=$(cat "$TEST_HOME/.hanif/env.sh")
  assert_contains "Space form persists key" "$content" "export DATABASE_URL="
  # Value retrieval (which decodes %q) should round-trip.
  local got
  got=$("$HANIF" env get DATABASE_URL 2>&1)
  assert_contains "get returns the URL" "$got" "postgres://u:p@h/db"
}

test_env_set_handles_special_chars() {
  printf "y\ny\ny\n" | "$HANIF" env set HAS_QUOTES "a 'b' c \"d\" \$e" >/dev/null 2>&1
  local got
  got=$("$HANIF" env get HAS_QUOTES 2>&1)
  assert_contains "Round-trips single quotes" "$got" "'b'"
  assert_contains "Round-trips double quotes" "$got" '"d"'
  assert_contains "Round-trips dollar sign"   "$got" '$e'
}

test_env_set_rejects_bad_key() {
  local out rc
  set +e
  out=$("$HANIF" env set "1BAD=x" 2>&1)
  rc=$?
  set -e
  assert_equals "Bad key returns non-zero" "1" "$rc"
  assert_contains "Bad key error message" "$out" "Invalid variable name"
}

test_env_set_rejects_unparseable() {
  local out rc
  set +e
  out=$("$HANIF" env set FOO 2>&1)
  rc=$?
  set -e
  assert_equals "Single bare arg returns non-zero" "1" "$rc"
  assert_contains "Unparseable error message" "$out" "expected KEY=VALUE"
}

test_env_set_overwrite_warns_and_replaces() {
  printf "y\ny\ny\n" | "$HANIF" env set FOO=first  >/dev/null 2>&1
  local out
  out=$(printf "y\ny\ny\n" | "$HANIF" env set FOO=second 2>&1)
  assert_contains "Overwrite warning shown" "$out" "already set"
  local content
  content=$(cat "$TEST_HOME/.hanif/env.sh")
  # Should contain the new value, not the old.
  assert_contains "File now has new value"  "$content" "export FOO=second"
  if grep -q '^export FOO=first$' "$TEST_HOME/.hanif/env.sh" 2>/dev/null; then
    ((TESTS_RUN++)) || true
    ((TESTS_FAILED++)) || true
    echo -e "\033[0;31m✗\033[0m Old value removed from file"
  else
    ((TESTS_RUN++)) || true
    ((TESTS_PASSED++)) || true
    echo -e "\033[0;32m✓\033[0m Old value removed from file"
  fi
}

test_env_set_overwrite_decline_keeps_old_value() {
  printf "y\ny\ny\n" | "$HANIF" env set FOO=keep >/dev/null 2>&1
  printf 'n\n' | "$HANIF" env set FOO=changed >/dev/null 2>&1
  local content
  content=$(cat "$TEST_HOME/.hanif/env.sh")
  assert_contains "Old value kept after decline" "$content" "export FOO=keep"
}

test_env_set_keeps_other_vars() {
  printf "y\ny\ny\n" | "$HANIF" env set A=1 >/dev/null 2>&1
  printf "y\ny\ny\n" | "$HANIF" env set B=2 >/dev/null 2>&1
  printf "y\ny\ny\n" | "$HANIF" env set A=11 >/dev/null 2>&1
  local content
  content=$(cat "$TEST_HOME/.hanif/env.sh")
  assert_contains "B preserved across A overwrite" "$content" "export B=2"
  assert_contains "A updated"                       "$content" "export A=11"
}

# ---------------------------------------------------------------------------
# Profile wiring
# ---------------------------------------------------------------------------

test_env_set_wires_profile_after_confirm() {
  # Two prompts: write var (y), wire profile (y).
  printf "y\ny\ny\n" | "$HANIF" env set WIRED=yes >/dev/null 2>&1
  assert_file_exists "Profile created" "$TEST_HOME/.bashrc"
  local profile
  profile=$(cat "$TEST_HOME/.bashrc")
  assert_contains "Profile has begin marker" "$profile" "# >>> hanif env >>>"
  assert_contains "Profile has end marker"   "$profile" "# <<< hanif env <<<"
  assert_contains "Profile sources env file" "$profile" ".hanif/env.sh"
}

test_env_set_does_not_double_wire_profile() {
  printf "y\ny\ny\n" | "$HANIF" env set A=1 >/dev/null 2>&1
  printf "y\ny\ny\n" | "$HANIF" env set B=2 >/dev/null 2>&1
  local count
  count=$(grep -c '^# >>> hanif env >>>' "$TEST_HOME/.bashrc" || true)
  assert_equals "Profile block appears exactly once" "1" "$count"
}

test_env_set_skips_profile_after_decline() {
  # First prompt: write (y). Second prompt: wire profile (n).
  printf 'y\nn\n' | "$HANIF" env set NOWIRE=yes >/dev/null 2>&1
  if [[ -f "$TEST_HOME/.bashrc" ]] && grep -q '# >>> hanif env >>>' "$TEST_HOME/.bashrc" 2>/dev/null; then
    ((TESTS_RUN++)) || true
    ((TESTS_FAILED++)) || true
    echo -e "\033[0;31m✗\033[0m Declining wire prompt leaves profile alone"
  else
    ((TESTS_RUN++)) || true
    ((TESTS_PASSED++)) || true
    echo -e "\033[0;32m✓\033[0m Declining wire prompt leaves profile alone"
  fi
}

# ---------------------------------------------------------------------------
# unset
# ---------------------------------------------------------------------------

test_env_unset_removes_var() {
  printf "y\ny\ny\n" | "$HANIF" env set GONE=yes >/dev/null 2>&1
  printf 'y\n' | "$HANIF" env unset GONE >/dev/null 2>&1
  if grep -q '^export GONE=' "$TEST_HOME/.hanif/env.sh" 2>/dev/null; then
    ((TESTS_RUN++)) || true
    ((TESTS_FAILED++)) || true
    echo -e "\033[0;31m✗\033[0m unset removes the variable"
  else
    ((TESTS_RUN++)) || true
    ((TESTS_PASSED++)) || true
    echo -e "\033[0;32m✓\033[0m unset removes the variable"
  fi
}

test_env_unset_decline_keeps_var() {
  printf "y\ny\ny\n" | "$HANIF" env set STAY=yes >/dev/null 2>&1
  printf 'n\n' | "$HANIF" env unset STAY >/dev/null 2>&1
  local content
  content=$(cat "$TEST_HOME/.hanif/env.sh")
  assert_contains "Declining unset keeps variable" "$content" "export STAY="
}

test_env_unset_missing_warns() {
  printf "y\ny\ny\n" | "$HANIF" env set OTHER=1 >/dev/null 2>&1
  local out
  out=$("$HANIF" env unset NEVER_EXISTED 2>&1)
  assert_contains "Missing var warning" "$out" "nothing to remove"
}

test_env_unset_aliases_work() {
  printf "y\ny\ny\n" | "$HANIF" env set A=1 >/dev/null 2>&1
  printf 'y\n' | "$HANIF" env rm A >/dev/null 2>&1
  if grep -q '^export A=' "$TEST_HOME/.hanif/env.sh" 2>/dev/null; then
    ((TESTS_RUN++)) || true
    ((TESTS_FAILED++)) || true
    echo -e "\033[0;31m✗\033[0m rm alias removes variable"
  else
    ((TESTS_RUN++)) || true
    ((TESTS_PASSED++)) || true
    echo -e "\033[0;32m✓\033[0m rm alias removes variable"
  fi
}

# ---------------------------------------------------------------------------
# list / get / source / path
# ---------------------------------------------------------------------------

test_env_list_empty() {
  local out
  out=$("$HANIF" env list 2>&1)
  assert_contains "Empty list mentions no vars set" "$out" "No managed env file"
}

test_env_list_renders_table() {
  printf "y\ny\ny\n" | "$HANIF" env set FOO=1 >/dev/null 2>&1
  printf "y\ny\ny\n" | "$HANIF" env set BAR=2 >/dev/null 2>&1
  local out
  out=$("$HANIF" env list 2>&1)
  assert_contains "Table header KEY"   "$out" "KEY"
  assert_contains "Table header VALUE" "$out" "VALUE"
  assert_contains "Table lists FOO"    "$out" "FOO"
  assert_contains "Table lists BAR"    "$out" "BAR"
}

test_env_list_masks_secrets() {
  printf "y\ny\ny\n" | "$HANIF" env set MY_TOKEN=sk-supersecret >/dev/null 2>&1
  local out
  out=$("$HANIF" env list 2>&1)
  assert_contains "Token row marked masked" "$out" "(masked)"
  if echo "$out" | grep -q "supersecret"; then
    ((TESTS_RUN++)) || true
    ((TESTS_FAILED++)) || true
    echo -e "\033[0;31m✗\033[0m Secret value not shown in list"
  else
    ((TESTS_RUN++)) || true
    ((TESTS_PASSED++)) || true
    echo -e "\033[0;32m✓\033[0m Secret value not shown in list"
  fi
}

test_env_get_shows_persisted_value() {
  printf "y\ny\ny\n" | "$HANIF" env set MY_TOKEN=sk-revealme >/dev/null 2>&1
  local out
  out=$("$HANIF" env get MY_TOKEN 2>&1)
  assert_contains "get reveals secret value" "$out" "sk-revealme"
}

test_env_source_prints_command() {
  printf "y\ny\ny\n" | "$HANIF" env set X=1 >/dev/null 2>&1
  local out
  out=$("$HANIF" env source 2>&1)
  assert_contains "source prints source command" "$out" "source $TEST_HOME/.hanif/env.sh"
}

test_env_path_shows_layout() {
  local out
  out=$("$HANIF" env path 2>&1)
  assert_contains "path shows shell" "$out" "Shell"
  assert_contains "path shows env file" "$out" ".hanif/env.sh"
  assert_contains "path shows profile" "$out" ".bashrc"
}

# ---------------------------------------------------------------------------
# render_table helper unit test
# ---------------------------------------------------------------------------

test_render_table_basic() {
  local out
  out=$(
    bash -c '
      set -e
      source "'"$PROJECT_ROOT"'/lib/utils/common.sh"
      {
        printf "FOO\tbar\n"
        printf "BAZQUX\tlonger value\n"
      } | render_table "KEY|VALUE"
    '
  )
  assert_contains "render_table prints headers" "$out" "KEY"
  assert_contains "render_table prints values"  "$out" "BAZQUX"
  assert_contains "render_table draws box top"  "$out" "┌"
  assert_contains "render_table draws box bot"  "$out" "└"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

main() {
  suite "Env command — registration"
  run_test test_env_command_registered
  run_test test_env_help_topic_resolves
  run_test test_env_e_alias_resolves

  suite "Env command — set"
  run_test test_env_set_writes_file_after_confirm
  run_test test_env_set_aborts_on_decline
  run_test test_env_set_space_separated_form
  run_test test_env_set_handles_special_chars
  run_test test_env_set_rejects_bad_key
  run_test test_env_set_rejects_unparseable
  run_test test_env_set_overwrite_warns_and_replaces
  run_test test_env_set_overwrite_decline_keeps_old_value
  run_test test_env_set_keeps_other_vars

  suite "Env command — profile wiring"
  run_test test_env_set_wires_profile_after_confirm
  run_test test_env_set_does_not_double_wire_profile
  run_test test_env_set_skips_profile_after_decline

  suite "Env command — unset"
  run_test test_env_unset_removes_var
  run_test test_env_unset_decline_keeps_var
  run_test test_env_unset_missing_warns
  run_test test_env_unset_aliases_work

  suite "Env command — list / get / source / path"
  run_test test_env_list_empty
  run_test test_env_list_renders_table
  run_test test_env_list_masks_secrets
  run_test test_env_get_shows_persisted_value
  run_test test_env_source_prints_command
  run_test test_env_path_shows_layout

  suite "render_table helper"
  run_test test_render_table_basic

  print_summary
}

main "$@"
