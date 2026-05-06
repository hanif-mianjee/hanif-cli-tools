#!/usr/bin/env bash
#
# Tests for `hanif wip` / `hanif unwip` / `hanif undo` / `hanif stash`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HANIF="$PROJECT_ROOT/bin/hanif"

# shellcheck source=test-framework.sh
source "$SCRIPT_DIR/test-framework.sh"

TEST_HOME=""
TEST_REPO=""

setup() {
  TEST_HOME=$(mktemp -d)
  TEST_REPO=$(mktemp -d)
  export HOME="$TEST_HOME"
  export HANIF_SKIP_UPDATE_CHECK=1
  (
    cd "$TEST_REPO"
    git init -q
    git config user.email "t@t"
    git config user.name "t"
    echo a > f && git add f && git commit -qm init
  )
}

teardown() {
  for d in "$TEST_HOME" "$TEST_REPO"; do
    if [[ -n "$d" && -d "$d" ]] && [[ "$d" == /tmp/* || "$d" == /var/folders/* ]]; then
      rm -rf "$d"
    fi
  done
  unset HANIF_SKIP_UPDATE_CHECK
}

# ---------------------------------------------------------------------------
# wip / unwip
# ---------------------------------------------------------------------------

test_wip_clean_tree_is_noop() {
  local out
  out=$(cd "$TEST_REPO" && "$HANIF" wip 2>&1)
  assert_contains "wip clean tree noop" "$out" "Nothing to WIP"
}

test_wip_creates_commit_with_message() {
  (cd "$TEST_REPO" && echo b > f)
  local out
  out=$(cd "$TEST_REPO" && "$HANIF" wip my note 2>&1)
  assert_contains "wip success line" "$out" "Parked as WIP"
  local subj
  subj=$(cd "$TEST_REPO" && git log -1 --pretty=%s)
  assert_contains "wip commit subject" "$subj" "WIP: my note"
}

test_wip_default_message_uses_timestamp() {
  (cd "$TEST_REPO" && echo b > f)
  (cd "$TEST_REPO" && "$HANIF" wip >/dev/null 2>&1)
  local subj
  subj=$(cd "$TEST_REPO" && git log -1 --pretty=%s)
  assert_contains "default WIP subject prefix" "$subj" "WIP:"
}

test_wip_includes_untracked_files() {
  (cd "$TEST_REPO" && echo new > newfile)
  (cd "$TEST_REPO" && "$HANIF" wip "with untracked" >/dev/null 2>&1)
  local listed
  listed=$(cd "$TEST_REPO" && git show --name-only --pretty='' HEAD)
  assert_contains "WIP commit includes untracked file" "$listed" "newfile"
}

test_unwip_undoes_wip_commit() {
  (cd "$TEST_REPO" && echo b > f)
  (cd "$TEST_REPO" && "$HANIF" wip "to undo" >/dev/null 2>&1)
  local out
  out=$(cd "$TEST_REPO" && "$HANIF" unwip 2>&1)
  assert_contains "unwip success" "$out" "WIP commit undone"
  local subj
  subj=$(cd "$TEST_REPO" && git log -1 --pretty=%s)
  assert_equals "HEAD restored to init" "init" "$subj"
}

test_unwip_refuses_non_wip_commit() {
  local out rc
  set +e
  out=$(cd "$TEST_REPO" && "$HANIF" unwip 2>&1)
  rc=$?
  set -e
  assert_equals "unwip on non-WIP fails" "1" "$rc"
  assert_contains "unwip error" "$out" "not a WIP commit"
}

# ---------------------------------------------------------------------------
# undo
# ---------------------------------------------------------------------------

test_undo_clean_repo_is_noop() {
  local out
  out=$(cd "$TEST_REPO" && "$HANIF" undo 2>&1 < /dev/null)
  assert_contains "undo clean noop" "$out" "Nothing to undo"
}

test_undo_menu_shows_options_with_changes() {
  (cd "$TEST_REPO" && echo b > f)
  local out
  # Provide 'q' to cancel after seeing the menu.
  out=$(cd "$TEST_REPO" && printf 'q\n' | "$HANIF" undo 2>&1)
  assert_contains "undo menu banner" "$out" "Undo Menu"
  assert_contains "undo offers discard option" "$out" "DISCARD all unstaged"
}

test_undo_soft_reset_keeps_changes() {
  (cd "$TEST_REPO" && echo b > f && git add f && git commit -qm "second")
  local out
  # Menu: option that says "Undo the last commit, KEEP changes" — find its number.
  # Provide '1' (will be the first numbered item that applies). Repo state:
  # no in-progress op, has HEAD~1, no staged, no unstaged → menu shows
  # soft-reset, hard-reset only. Pick 1 (soft) and confirm with 'y'.
  out=$(cd "$TEST_REPO" && printf '1\ny\n' | "$HANIF" undo 2>&1)
  assert_contains "undo soft-reset success" "$out" "changes staged"
  local subj
  subj=$(cd "$TEST_REPO" && git log -1 --pretty=%s)
  assert_equals "HEAD now at init" "init" "$subj"
  # Changes should be staged.
  local staged
  staged=$(cd "$TEST_REPO" && git diff --cached --name-only)
  assert_contains "f is staged" "$staged" "f"
}

# ---------------------------------------------------------------------------
# stash
# ---------------------------------------------------------------------------

test_stash_save_and_list() {
  (cd "$TEST_REPO" && echo b > f)
  (cd "$TEST_REPO" && "$HANIF" stash save "my work" >/dev/null 2>&1)
  local out
  out=$(cd "$TEST_REPO" && "$HANIF" stash list 2>&1)
  assert_contains "stash list shows numbered entry" "$out" "0"
  assert_contains "stash list shows message"        "$out" "my work"
}

test_stash_list_empty() {
  local out
  out=$(cd "$TEST_REPO" && "$HANIF" stash list 2>&1)
  assert_contains "stash list empty message" "$out" "No stashes"
}

test_stash_pop_restores_changes() {
  (cd "$TEST_REPO" && echo b > f)
  (cd "$TEST_REPO" && "$HANIF" stash save "popme" >/dev/null 2>&1)
  # Tree should be clean now.
  local clean
  clean=$(cd "$TEST_REPO" && git status -s)
  assert_equals "Tree clean after stash" "" "$clean"
  (cd "$TEST_REPO" && "$HANIF" stash pop 0 >/dev/null 2>&1)
  local content
  content=$(cd "$TEST_REPO" && cat f)
  assert_equals "File restored from stash" "b" "$content"
}

test_stash_invalid_index() {
  # Create one stash so the count check passes and the validator runs.
  (cd "$TEST_REPO" && echo b > f)
  (cd "$TEST_REPO" && "$HANIF" stash save "anchor" >/dev/null 2>&1)
  local out rc
  set +e
  out=$(cd "$TEST_REPO" && "$HANIF" stash pop 99 2>&1)
  rc=$?
  set -e
  assert_equals "Invalid index returns non-zero" "1" "$rc"
  assert_contains "Invalid index error" "$out" "No such stash"
}

test_stash_drop_with_confirmation() {
  (cd "$TEST_REPO" && echo b > f)
  (cd "$TEST_REPO" && "$HANIF" stash save "drop-me" >/dev/null 2>&1)
  (cd "$TEST_REPO" && printf 'y\n' | "$HANIF" stash drop 0 >/dev/null 2>&1)
  local out
  out=$(cd "$TEST_REPO" && "$HANIF" stash list 2>&1)
  assert_contains "Stash dropped" "$out" "No stashes"
}

# ---------------------------------------------------------------------------

main() {
  suite "wip / unwip"
  run_test test_wip_clean_tree_is_noop
  run_test test_wip_creates_commit_with_message
  run_test test_wip_default_message_uses_timestamp
  run_test test_wip_includes_untracked_files
  run_test test_unwip_undoes_wip_commit
  run_test test_unwip_refuses_non_wip_commit

  suite "undo"
  run_test test_undo_clean_repo_is_noop
  run_test test_undo_menu_shows_options_with_changes
  run_test test_undo_soft_reset_keeps_changes

  suite "stash"
  run_test test_stash_save_and_list
  run_test test_stash_list_empty
  run_test test_stash_pop_restores_changes
  run_test test_stash_invalid_index
  run_test test_stash_drop_with_confirmation

  print_summary
}

main "$@"
