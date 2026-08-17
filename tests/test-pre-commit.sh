#!/usr/bin/env bash
#
# Tests for `hanif pre-commit` — interactive pre-commit hook manager.
#
# Each test runs in a fresh sandbox git repo under mktemp so we never
# touch the host filesystem. Tests skip the background update probe.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HANIF="$PROJECT_ROOT/bin/hanif"

# shellcheck source=test-framework.sh
source "$SCRIPT_DIR/test-framework.sh"

SANDBOX=""
REPO=""

setup() {
  SANDBOX=$(mktemp -d)
  REPO="$SANDBOX/repo"
  mkdir -p "$REPO"
  (
    cd "$REPO"
    git init -q
    git checkout -b feature/test 2>/dev/null || git checkout -b main
    git config user.email "t@example.com"
    git config user.name "Tester"
    echo "seed" > seed.txt
    git add seed.txt
    git commit -q -m init
    git checkout -b feature/test 2>/dev/null || true
  )
  export HANIF_SKIP_UPDATE_CHECK=1
  export HANIF_PRE_COMMIT_YES=1
}

teardown() {
  if [[ -n "$SANDBOX" && -d "$SANDBOX" ]] \
     && [[ "$SANDBOX" == /tmp/* || "$SANDBOX" == /var/folders/* ]]; then
    rm -rf "$SANDBOX"
  fi
  unset HANIF_SKIP_UPDATE_CHECK HANIF_PRE_COMMIT_YES \
        HANIF_PRE_COMMIT_CHECKS HANIF_PRE_COMMIT_CUSTOM \
        HANIF_PRE_COMMIT_PROTECTED_BRANCHES \
        HANIF_PRE_COMMIT_MAX_FILE_MB \
        HANIF_PRE_COMMIT_ENV_ALLOWLIST
}

# Helper: install with a given check list (and optional custom commands).
_install() {
  local checks="$1"
  local custom="${2:-}"
  (
    cd "$REPO"
    HANIF_PRE_COMMIT_CHECKS="$checks" \
    HANIF_PRE_COMMIT_CUSTOM="$custom" \
      "$HANIF" pre-commit >/dev/null 2>&1
  )
}

# Helper: run the hook with the staged set; report exit code through.
_run_hook() {
  (cd "$REPO" && "$HANIF" pre-commit run >/dev/null 2>&1)
}

# Helper: capture hook stdout/stderr.
_run_hook_capture() {
  (cd "$REPO" && "$HANIF" pre-commit run 2>&1)
}

# ---------------------------------------------------------------------------
# Registration / help
# ---------------------------------------------------------------------------

test_pre_commit_command_registered() {
  local out
  out=$("$HANIF" help 2>&1)
  assert_contains "Help mentions pre-commit" "$out" "pre-commit"
}

test_pre_commit_help_topic_resolves() {
  local out
  out=$("$HANIF" help pre-commit 2>&1)
  assert_contains "help pre-commit banner"   "$out" "Pre-Commit Hook Manager"
  assert_contains "help mentions catalog"    "$out" "CATALOG OF CHECKS"

  out=$("$HANIF" pc --help 2>&1)
  assert_contains "pc --help works"          "$out" "Pre-Commit Hook Manager"

  out=$("$HANIF" pre-commit --help 2>&1)
  assert_contains "long-form --help works"   "$out" "Pre-Commit Hook Manager"
}

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

test_pre_commit_rejects_outside_git_repo() {
  local nongit
  nongit=$(mktemp -d)
  local rc=0
  (cd "$nongit" && "$HANIF" pre-commit list >/dev/null 2>&1) || rc=$?
  rm -rf "$nongit"
  assert_equals "list outside git repo exits non-zero" "1" "$rc"
}

test_pre_commit_unknown_subcommand_errors() {
  local rc=0
  (cd "$REPO" && "$HANIF" pre-commit blargh >/dev/null 2>&1) || rc=$?
  assert_equals "unknown subcommand exits non-zero" "1" "$rc"
}

# ---------------------------------------------------------------------------
# Stack detection
# ---------------------------------------------------------------------------

test_pre_commit_detects_node() {
  (cd "$REPO" && echo '{"name":"d","version":"0.0.1"}' > package.json && git add package.json && git commit -q -m node)
  local out
  out=$(cd "$REPO" && HANIF_PRE_COMMIT_CHECKS=no-secrets "$HANIF" pre-commit 2>&1)
  assert_contains "Node.js detected" "$out" "Node.js"
}

test_pre_commit_detects_python_via_requirements() {
  (cd "$REPO" && echo 'requests' > requirements.txt && git add requirements.txt && git commit -q -m py)
  local out
  out=$(cd "$REPO" && HANIF_PRE_COMMIT_CHECKS=no-secrets "$HANIF" pre-commit 2>&1)
  assert_contains "Python detected (requirements.txt)" "$out" "Python"
}

test_pre_commit_detects_multiple_stacks() {
  (cd "$REPO" \
    && echo '{"name":"d"}' > package.json \
    && echo '[package]' > Cargo.toml \
    && git add . && git commit -q -m mix)
  local out
  out=$(cd "$REPO" && HANIF_PRE_COMMIT_CHECKS=no-secrets "$HANIF" pre-commit 2>&1)
  assert_contains "multi-stack: Node" "$out" "Node.js"
  assert_contains "multi-stack: Rust" "$out" "Rust"
}

test_pre_commit_empty_repo_universal_only() {
  local out
  out=$(cd "$REPO" && HANIF_PRE_COMMIT_CHECKS=no-secrets "$HANIF" pre-commit 2>&1)
  assert_contains "empty repo says universal only" "$out" "universal checks only"
}

# ---------------------------------------------------------------------------
# Happy path install
# ---------------------------------------------------------------------------

test_pre_commit_creates_hook_with_selected_checks() {
  _install "protect-branches,no-merge-markers,no-secrets"

  assert_file_exists "hook file created" "$REPO/.git/hooks/pre-commit"

  local hook
  hook=$(cat "$REPO/.git/hooks/pre-commit")
  assert_contains "starts with bash shebang"           "$hook" "#!/usr/bin/env bash"
  assert_contains "begin marker present"               "$hook" "# >>> hanif pre-commit: managed >>>"
  assert_contains "end marker present"                 "$hook" "# <<< hanif pre-commit: managed <<<"
  assert_contains "protect-branches block present"     "$hook" "# --- check:protect-branches ---"
  assert_contains "no-merge-markers block present"     "$hook" "# --- check:no-merge-markers ---"
  assert_contains "no-secrets block present"           "$hook" "# --- check:no-secrets ---"
}

test_pre_commit_hook_is_executable_with_mode_755() {
  _install "no-secrets"
  local perm
  perm=$(stat -c '%a' "$REPO/.git/hooks/pre-commit" 2>/dev/null \
        || stat -f '%Lp' "$REPO/.git/hooks/pre-commit")
  assert_equals "hook is chmod 755" "755" "$perm"
}

# ---------------------------------------------------------------------------
# Idempotency
# ---------------------------------------------------------------------------

test_pre_commit_reinstall_replaces_managed_block_in_place() {
  _install "protect-branches,no-merge-markers"
  _install "no-secrets,no-trailing-whitespace"

  local hook count_begin
  hook="$REPO/.git/hooks/pre-commit"
  count_begin=$(grep -c '^# >>> hanif pre-commit: managed >>>$' "$hook" || true)
  assert_equals "begin marker count stays at 1" "1" "$count_begin"

  local content
  content=$(cat "$hook")
  assert_contains "new check present"     "$content" "# --- check:no-secrets ---"
  if [[ "$content" == *"# --- check:protect-branches ---"* ]]; then
    ((TESTS_RUN++)) || true
    ((TESTS_FAILED++)) || true
    echo -e "\033[0;31m✗\033[0m old check NOT present after reinstall"
  else
    ((TESTS_RUN++)) || true
    ((TESTS_PASSED++)) || true
    echo -e "\033[0;32m✓\033[0m old check NOT present after reinstall"
  fi
}

# ---------------------------------------------------------------------------
# Backup / splice
# ---------------------------------------------------------------------------

test_pre_commit_backs_up_pre_existing_unmanaged_hook() {
  printf '#!/bin/bash\necho legacy\n' > "$REPO/.git/hooks/pre-commit"
  chmod 755 "$REPO/.git/hooks/pre-commit"

  _install "no-secrets"

  # Backup file is sortable & timestamped — look for the prefix.
  local backups
  backups=$(ls "$REPO/.git/hooks/" | grep '^pre-commit\.bak\.' | head -1)
  if [[ -z "$backups" ]]; then
    ((TESTS_RUN++)) || true
    ((TESTS_FAILED++)) || true
    echo -e "\033[0;31m✗\033[0m backup file created on takeover"
  else
    ((TESTS_RUN++)) || true
    ((TESTS_PASSED++)) || true
    echo -e "\033[0;32m✓\033[0m backup file created on takeover"
  fi

  local hook
  hook=$(cat "$REPO/.git/hooks/pre-commit")
  if [[ "$hook" == *"echo legacy"* ]]; then
    ((TESTS_RUN++)) || true
    ((TESTS_FAILED++)) || true
    echo -e "\033[0;31m✗\033[0m legacy content removed from new hook"
  else
    ((TESTS_RUN++)) || true
    ((TESTS_PASSED++)) || true
    echo -e "\033[0;32m✓\033[0m legacy content removed from new hook"
  fi

  if [[ -n "$backups" ]] && grep -q 'echo legacy' "$REPO/.git/hooks/$backups"; then
    ((TESTS_RUN++)) || true
    ((TESTS_PASSED++)) || true
    echo -e "\033[0;32m✓\033[0m backup contains legacy content"
  else
    ((TESTS_RUN++)) || true
    ((TESTS_FAILED++)) || true
    echo -e "\033[0;31m✗\033[0m backup contains legacy content"
  fi
}

test_pre_commit_splice_preserves_user_content_outside_markers() {
  _install "no-secrets"
  printf '\n# user-added-line-XYZ\n' >> "$REPO/.git/hooks/pre-commit"

  _install "no-merge-markers,no-trailing-whitespace"

  local hook
  hook=$(cat "$REPO/.git/hooks/pre-commit")
  assert_contains "user line preserved after splice" "$hook" "user-added-line-XYZ"
  local count_begin
  count_begin=$(grep -c '^# >>> hanif pre-commit: managed >>>$' "$REPO/.git/hooks/pre-commit" || true)
  assert_equals "still only one managed block after splice" "1" "$count_begin"
}

# ---------------------------------------------------------------------------
# Subcommand: list
# ---------------------------------------------------------------------------

test_pre_commit_list_when_not_installed() {
  local out
  out=$(cd "$REPO" && "$HANIF" pre-commit list 2>&1)
  assert_contains "list: not installed" "$out" "not installed"
}

test_pre_commit_list_when_installed() {
  _install "protect-branches,no-merge-markers"
  local out
  out=$(cd "$REPO" && "$HANIF" pre-commit list 2>&1)
  assert_contains "list: shows managed"      "$out" "managed"
  assert_contains "list: shows check IDs"    "$out" "protect-branches"
  assert_contains "list: shows mode"         "$out" "755"
}

# ---------------------------------------------------------------------------
# Subcommand: remove
# ---------------------------------------------------------------------------

test_pre_commit_remove_when_no_hook_errors() {
  local rc=0
  (cd "$REPO" && "$HANIF" pre-commit remove >/dev/null 2>&1) || rc=$?
  assert_equals "remove without a hook exits non-zero" "1" "$rc"
}

test_pre_commit_remove_deletes_purely_managed_hook() {
  _install "no-secrets"
  (cd "$REPO" && "$HANIF" pre-commit remove >/dev/null 2>&1)
  if [[ -f "$REPO/.git/hooks/pre-commit" ]]; then
    ((TESTS_RUN++)) || true
    ((TESTS_FAILED++)) || true
    echo -e "\033[0;31m✗\033[0m managed-only hook removed"
  else
    ((TESTS_RUN++)) || true
    ((TESTS_PASSED++)) || true
    echo -e "\033[0;32m✓\033[0m managed-only hook removed"
  fi
  local backup
  backup=$(ls "$REPO/.git/hooks/" 2>/dev/null | grep '^pre-commit\.bak\.' | head -1)
  if [[ -n "$backup" ]]; then
    ((TESTS_RUN++)) || true
    ((TESTS_PASSED++)) || true
    echo -e "\033[0;32m✓\033[0m remove wrote a backup"
  else
    ((TESTS_RUN++)) || true
    ((TESTS_FAILED++)) || true
    echo -e "\033[0;31m✗\033[0m remove wrote a backup"
  fi
}

test_pre_commit_remove_strips_managed_block_when_user_content_remains() {
  _install "no-secrets"
  printf '\n# keep-me-around\n' >> "$REPO/.git/hooks/pre-commit"

  (cd "$REPO" && "$HANIF" pre-commit remove >/dev/null 2>&1)

  assert_file_exists "hook file still exists" "$REPO/.git/hooks/pre-commit"
  local hook
  hook=$(cat "$REPO/.git/hooks/pre-commit")
  assert_contains "user content preserved on remove" "$hook" "keep-me-around"
  if [[ "$hook" == *"# >>> hanif pre-commit: managed >>>"* ]]; then
    ((TESTS_RUN++)) || true
    ((TESTS_FAILED++)) || true
    echo -e "\033[0;31m✗\033[0m managed block gone after remove"
  else
    ((TESTS_RUN++)) || true
    ((TESTS_PASSED++)) || true
    echo -e "\033[0;32m✓\033[0m managed block gone after remove"
  fi
}

# ---------------------------------------------------------------------------
# Subcommand: run
# ---------------------------------------------------------------------------

test_pre_commit_run_without_hook_errors() {
  local rc=0
  (cd "$REPO" && "$HANIF" pre-commit run >/dev/null 2>&1) || rc=$?
  assert_equals "run without hook exits non-zero" "1" "$rc"
}

test_pre_commit_run_passes_on_clean_repo() {
  _install "protect-branches,no-merge-markers,no-secrets"
  echo "ok" > "$REPO/ok.txt"
  (cd "$REPO" && git add ok.txt)
  assert_success "clean staged set passes the hook" \
    bash -c "(cd '$REPO' && '$HANIF' pre-commit run >/dev/null 2>&1)"
}

test_pre_commit_run_detects_merge_markers() {
  _install "no-merge-markers"
  printf '<<<<<<< HEAD\nfoo\n=======\nbar\n>>>>>>> branch\n' > "$REPO/conflict.txt"
  (cd "$REPO" && git add conflict.txt)
  local out rc=0
  out=$(_run_hook_capture) || rc=$?
  assert_equals "merge markers → exit 1"        "1" "$rc"
  assert_contains "output mentions check id"    "$out" "no-merge-markers"
}

test_pre_commit_run_protects_branches() {
  _install "protect-branches"
  (cd "$REPO" && git checkout -B main 2>/dev/null)
  echo "x" > "$REPO/a.txt"
  (cd "$REPO" && git add a.txt)
  local out rc=0
  out=$(_run_hook_capture) || rc=$?
  assert_equals "commit to main → exit 1"   "1" "$rc"
  assert_contains "output mentions branch"  "$out" "protect-branches"

  # Switch to feature → clean
  (cd "$REPO" && git checkout -B feature/x 2>/dev/null)
  rc=0
  _run_hook || rc=$?
  assert_equals "commit to feature/x → exit 0" "0" "$rc"
}

test_pre_commit_run_detects_aws_secret_in_additions() {
  _install "no-secrets"
  echo "key = AKIAIOSFODNN7EXAMPLE" > "$REPO/conf"
  (cd "$REPO" && git add conf)
  local out rc=0
  out=$(_run_hook_capture) || rc=$?
  assert_equals "AWS key → exit 1"             "1" "$rc"
  assert_contains "output mentions check id"   "$out" "no-secrets"
}

# ---------------------------------------------------------------------------
# Failure accumulation
# ---------------------------------------------------------------------------

test_pre_commit_run_accumulates_multiple_failures() {
  _install "no-merge-markers,no-trailing-whitespace"
  # A single file that triggers BOTH checks: merge marker AND trailing space.
  printf '<<<<<<< HEAD\nfoo    \n=======\nbar\n>>>>>>> branch\n' > "$REPO/both.txt"
  (cd "$REPO" && git add both.txt)
  local out rc=0
  out=$(_run_hook_capture) || rc=$?
  assert_equals "hook exits non-zero"           "1" "$rc"
  assert_contains "first failure listed"        "$out" "no-merge-markers"
  assert_contains "second failure listed"       "$out" "no-trailing-whitespace"
}

# ---------------------------------------------------------------------------
# Custom commands
# ---------------------------------------------------------------------------

test_pre_commit_custom_command_embeds_in_hook() {
  _install "no-secrets" "echo hello-from-custom"
  local hook
  hook=$(cat "$REPO/.git/hooks/pre-commit")
  assert_contains "custom block markers"  "$hook" "# --- check:custom-1 ---"
  assert_contains "custom command embedded" "$hook" "echo hello-from-custom"
}

test_pre_commit_custom_command_with_single_quotes_roundtrips() {
  _install "no-secrets" "echo 'it'\''s ok'"
  local hook
  hook=$(cat "$REPO/.git/hooks/pre-commit")
  assert_contains "custom command preserved with quote" "$hook" "it"

  # And it must actually run cleanly (custom commands return 0 unless they fail).
  echo ok > "$REPO/ok.txt"
  (cd "$REPO" && git add ok.txt)
  assert_success "hook with single-quoted custom runs" \
    bash -c "(cd '$REPO' && '$HANIF' pre-commit run >/dev/null 2>&1)"
}

# ---------------------------------------------------------------------------
# Runtime skip via HANIF_PRECOMMIT_SKIP
# ---------------------------------------------------------------------------

test_pre_commit_runtime_skip_env_var_works() {
  _install "no-secrets"
  echo "AKIAIOSFODNN7EXAMPLE" > "$REPO/leak"
  (cd "$REPO" && git add leak)
  # First, sanity: without skip, fails.
  local rc=0
  _run_hook || rc=$?
  assert_equals "without skip env, fails"   "1" "$rc"
  # With skip, passes.
  rc=0
  (cd "$REPO" && HANIF_PRECOMMIT_SKIP=no-secrets "$HANIF" pre-commit run >/dev/null 2>&1) || rc=$?
  assert_equals "with skip env, passes"     "0" "$rc"
}

# ---------------------------------------------------------------------------
# Stack-specific check: file-filter short-circuit
# ---------------------------------------------------------------------------

test_pre_commit_py_ruff_skips_when_no_py_staged() {
  # py-ruff is only in the catalog when a Python stack is detected, so
  # mark the repo as a Python project first.
  (cd "$REPO" && touch pyproject.toml && git add pyproject.toml && git commit -q -m py)
  _install "py-ruff"
  echo "README" > "$REPO/README.md"
  (cd "$REPO" && git add README.md)
  local out rc=0
  out=$(_run_hook_capture) || rc=$?
  assert_equals "no .py staged → exit 0 (skip)" "0" "$rc"
  assert_contains "skip line mentions py-ruff"  "$out" "py-ruff"
}

# ---------------------------------------------------------------------------
# core.hooksPath warning
# ---------------------------------------------------------------------------

test_pre_commit_warns_on_custom_hooks_path() {
  (cd "$REPO" && git config core.hooksPath ../.config/custom-hooks)
  local out
  out=$(cd "$REPO" && HANIF_PRE_COMMIT_CHECKS=no-secrets "$HANIF" pre-commit 2>&1)
  assert_contains "warns about core.hooksPath" "$out" "core.hooksPath"
  # Hook is still written at the standard location.
  assert_file_exists "hook still written to .git/hooks" "$REPO/.git/hooks/pre-commit"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

main() {
  suite "pre-commit — registration / help"
  run_test test_pre_commit_command_registered
  run_test test_pre_commit_help_topic_resolves

  suite "pre-commit — validation"
  run_test test_pre_commit_rejects_outside_git_repo
  run_test test_pre_commit_unknown_subcommand_errors

  suite "pre-commit — stack detection"
  run_test test_pre_commit_detects_node
  run_test test_pre_commit_detects_python_via_requirements
  run_test test_pre_commit_detects_multiple_stacks
  run_test test_pre_commit_empty_repo_universal_only

  suite "pre-commit — happy path install"
  run_test test_pre_commit_creates_hook_with_selected_checks
  run_test test_pre_commit_hook_is_executable_with_mode_755

  suite "pre-commit — idempotency"
  run_test test_pre_commit_reinstall_replaces_managed_block_in_place

  suite "pre-commit — backup / splice"
  run_test test_pre_commit_backs_up_pre_existing_unmanaged_hook
  run_test test_pre_commit_splice_preserves_user_content_outside_markers

  suite "pre-commit — list"
  run_test test_pre_commit_list_when_not_installed
  run_test test_pre_commit_list_when_installed

  suite "pre-commit — remove"
  run_test test_pre_commit_remove_when_no_hook_errors
  run_test test_pre_commit_remove_deletes_purely_managed_hook
  run_test test_pre_commit_remove_strips_managed_block_when_user_content_remains

  suite "pre-commit — run"
  run_test test_pre_commit_run_without_hook_errors
  run_test test_pre_commit_run_passes_on_clean_repo
  run_test test_pre_commit_run_detects_merge_markers
  run_test test_pre_commit_run_protects_branches
  run_test test_pre_commit_run_detects_aws_secret_in_additions

  suite "pre-commit — failure accumulation"
  run_test test_pre_commit_run_accumulates_multiple_failures

  suite "pre-commit — custom commands"
  run_test test_pre_commit_custom_command_embeds_in_hook
  run_test test_pre_commit_custom_command_with_single_quotes_roundtrips

  suite "pre-commit — runtime skip"
  run_test test_pre_commit_runtime_skip_env_var_works

  suite "pre-commit — file-filter short-circuit"
  run_test test_pre_commit_py_ruff_skips_when_no_py_staged

  suite "pre-commit — core.hooksPath"
  run_test test_pre_commit_warns_on_custom_hooks_path

  print_summary
}

main "$@"
