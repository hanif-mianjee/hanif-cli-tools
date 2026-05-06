#!/usr/bin/env bash
#
# Tests for `hanif ports` and `hanif serve`.
#
# Listening-port tests don't actually open sockets — they exercise the
# argument parser, validation, and help paths. The render path is covered
# indirectly via the registry test's help-topic check.

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
}

teardown() {
  if [[ -n "$TEST_HOME" && -d "$TEST_HOME" ]] \
     && [[ "$TEST_HOME" == /tmp/* || "$TEST_HOME" == /var/folders/* ]]; then
    rm -rf "$TEST_HOME"
  fi
  unset HANIF_SKIP_UPDATE_CHECK
}

# ---------------------------------------------------------------------------
# ports
# ---------------------------------------------------------------------------

test_ports_help_topic() {
  local out
  out=$("$HANIF" help ports 2>&1)
  assert_contains "ports help banner" "$out" "Listening Ports"
}

test_ports_invalid_port_rejected() {
  local out rc
  set +e
  out=$("$HANIF" ports abc 2>&1)
  rc=$?
  set -e
  assert_equals "abc rejected" "1" "$rc"
  assert_contains "abc error" "$out" "Invalid port"
}

test_ports_out_of_range_rejected() {
  local out rc
  set +e
  out=$("$HANIF" ports 99999 2>&1)
  rc=$?
  set -e
  assert_equals "99999 rejected" "1" "$rc"
  assert_contains "99999 error" "$out" "Invalid port"
}

test_ports_kill_requires_port() {
  local out rc
  set +e
  out=$("$HANIF" ports kill 2>&1)
  rc=$?
  set -e
  assert_equals "kill without port fails" "1" "$rc"
  assert_contains "kill usage error" "$out" "Usage: hanif ports kill"
}

test_ports_kill_invalid_port() {
  local out rc
  set +e
  out=$("$HANIF" ports kill abc 2>&1)
  rc=$?
  set -e
  assert_equals "kill abc fails" "1" "$rc"
  assert_contains "kill abc error" "$out" "Invalid port"
}

test_ports_kill_nothing_listening() {
  # Use a high random port that is almost certainly free.
  local port=54321 out rc
  set +e
  out=$("$HANIF" ports kill "$port" 2>&1)
  rc=$?
  set -e
  # Either "Nothing listening" (lsof/ss available) or backend-missing error.
  if [[ $rc -ne 0 ]]; then
    if ! [[ "$out" == *"Nothing listening"* || "$out" == *"No listening-port lookup"* ]]; then
      ((TESTS_RUN++)) || true
      ((TESTS_FAILED++)) || true
      echo -e "\033[0;31m✗\033[0m Expected 'Nothing listening' or 'No listening-port' error, got: $out"
      return 1
    fi
  fi
  ((TESTS_RUN++)) || true
  ((TESTS_PASSED++)) || true
  echo -e "\033[0;32m✓\033[0m kill on free port handled cleanly"
}

# ---------------------------------------------------------------------------
# serve
# ---------------------------------------------------------------------------

test_serve_help_topic() {
  local out
  out=$("$HANIF" help serve 2>&1)
  assert_contains "serve help banner" "$out" "Static HTTP Server"
}

test_serve_invalid_port_rejected() {
  local out rc
  set +e
  out=$("$HANIF" serve abc 2>&1)
  rc=$?
  set -e
  assert_equals "abc rejected" "1" "$rc"
  assert_contains "abc error" "$out" "Invalid port"
}

test_serve_missing_dir_rejected() {
  local out rc
  set +e
  out=$("$HANIF" serve 8081 /no/such/dir/here 2>&1)
  rc=$?
  set -e
  assert_equals "missing dir rejected" "1" "$rc"
  assert_contains "missing dir error" "$out" "Not a directory"
}

# ---------------------------------------------------------------------------

main() {
  suite "ports command"
  run_test test_ports_help_topic
  run_test test_ports_invalid_port_rejected
  run_test test_ports_out_of_range_rejected
  run_test test_ports_kill_requires_port
  run_test test_ports_kill_invalid_port
  run_test test_ports_kill_nothing_listening

  suite "serve command"
  run_test test_serve_help_topic
  run_test test_serve_invalid_port_rejected
  run_test test_serve_missing_dir_rejected

  print_summary
}

main "$@"
