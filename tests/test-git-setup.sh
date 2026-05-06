#!/usr/bin/env bash
#
# Tests for `hanif gsetup` — set up a new git profile (config + SSH key).
#
# Fully isolated:
#   * Fresh mktemp dir as $HOME so we never touch the host filesystem.
#   * HANIF_GSETUP_HOME points the command at a sandboxed home.
#   * HANIF_GSETUP_SKIP_KEYGEN=1 stubs ssh-keygen so the suite doesn't
#     need OpenSSH and runs in a fraction of a second.
#   * HANIF_SKIP_UPDATE_CHECK=1 skips the background update probe.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HANIF="$PROJECT_ROOT/bin/hanif"

# shellcheck source=test-framework.sh
source "$SCRIPT_DIR/test-framework.sh"

TEST_HOME=""
SANDBOX=""

setup() {
  SANDBOX=$(mktemp -d)
  TEST_HOME="$SANDBOX/home"
  mkdir -p "$TEST_HOME"
  export HOME="$TEST_HOME"
  export HANIF_GSETUP_HOME="$TEST_HOME"
  export HANIF_GSETUP_SKIP_KEYGEN=1
  export HANIF_SKIP_UPDATE_CHECK=1
}

teardown() {
  # Defensive: only delete the sandbox when it's a real path under a
  # system temp dir (mktemp -d guarantees this).
  if [[ -n "$SANDBOX" && -d "$SANDBOX" ]] \
     && [[ "$SANDBOX" == /tmp/* || "$SANDBOX" == /var/folders/* ]]; then
    rm -rf "$SANDBOX"
  fi
  unset HANIF_GSETUP_HOME HANIF_GSETUP_SKIP_KEYGEN HANIF_SKIP_UPDATE_CHECK
}

# Helper: pipe canned answers (repos dir, name, email, confirm) through
# the command and discard its noisy output.
_run_setup() {
  local profile="$1" repos="$2" name="$3" email="$4"
  shift 4
  # Default answers for: repos dir, name, email, confirm-create.
  # Extra prompts (e.g. reuse-key, overwrite-config) come from "$@".
  local extra=""
  if [[ $# -gt 0 ]]; then
    extra=$(printf '%s\n' "$@")
  fi
  printf '%s\n%s\n%s\ny\n%s' "$repos" "$name" "$email" "$extra" \
    | "$HANIF" gsetup "$profile" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Registration / help
# ---------------------------------------------------------------------------

test_gsetup_command_registered() {
  local out
  out=$("$HANIF" help 2>&1)
  assert_contains "Help mentions gsetup command" "$out" "gsetup"
}

test_gsetup_help_topic_resolves() {
  local out
  out=$("$HANIF" help gsetup 2>&1)
  assert_contains "help gsetup shows banner" "$out" "Set Up a New Git Profile"
  assert_contains "help gsetup mentions includeIf" "$out" "includeIf"

  out=$("$HANIF" help git-setup 2>&1)
  assert_contains "help git-setup shows banner" "$out" "Set Up a New Git Profile"

  out=$("$HANIF" gsetup --help 2>&1)
  assert_contains "gsetup --help shows banner" "$out" "Set Up a New Git Profile"
}

test_gsetup_alias_resolves() {
  local out
  out=$("$HANIF" git-setup --help 2>&1)
  assert_contains "git-setup alias works" "$out" "Set Up a New Git Profile"
}

test_gsetup_legacy_passthrough_resolves() {
  # `hanif git gsetup` should reach the same handler via the legacy
  # `hanif git <subcommand>` dispatcher.
  local out
  out=$("$HANIF" git gsetup --help 2>&1)
  assert_contains "Legacy 'hanif git gsetup --help' resolves" "$out" "Set Up a New Git Profile"
}

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

test_gsetup_rejects_bad_profile_name_argument() {
  local out rc
  set +e
  out=$("$HANIF" gsetup "bad name with spaces" 2>&1)
  rc=$?
  set -e
  assert_equals "Bad profile name returns non-zero" "1" "$rc"
  assert_contains "Bad profile name error message" "$out" "Invalid profile name"
}

# ---------------------------------------------------------------------------
# Happy path
# ---------------------------------------------------------------------------

test_gsetup_creates_all_artifacts() {
  _run_setup "work" "$TEST_HOME/code/work" "Hanif Mianjee" "hanif@example.com"

  assert_dir_exists  "Repos directory created"      "$TEST_HOME/code/work"
  assert_file_exists "Private SSH key created"      "$TEST_HOME/.ssh/id_ed25519_work"
  assert_file_exists "Public SSH key created"       "$TEST_HOME/.ssh/id_ed25519_work.pub"
  assert_file_exists "Per-profile gitconfig created" "$TEST_HOME/.gitconfig-work"
  assert_file_exists "Root gitconfig created"       "$TEST_HOME/.gitconfig"

  local profile_cfg root_cfg
  profile_cfg=$(cat "$TEST_HOME/.gitconfig-work")
  root_cfg=$(cat "$TEST_HOME/.gitconfig")

  assert_contains "Profile config has user.name"  "$profile_cfg" "name = Hanif Mianjee"
  assert_contains "Profile config has user.email" "$profile_cfg" "email = hanif@example.com"
  assert_contains "Profile config has sshCommand" "$profile_cfg" "ssh -i $TEST_HOME/.ssh/id_ed25519_work"
  assert_contains "Profile config pins identity"  "$profile_cfg" "IdentitiesOnly=yes"

  assert_contains "Root config has begin marker"  "$root_cfg" "# >>> hanif gsetup: work >>>"
  assert_contains "Root config has end marker"    "$root_cfg" "# <<< hanif gsetup: work <<<"
  assert_contains "Root config has includeIf"     "$root_cfg" "includeIf \"gitdir:$TEST_HOME/code/work/\""
  assert_contains "Root config points to profile config" "$root_cfg" "path = $TEST_HOME/.gitconfig-work"
}

test_gsetup_prints_public_key_and_instructions() {
  local out
  out=$(printf '%s\n%s\n%s\ny\n' "$TEST_HOME/code/work" "Hanif Mianjee" "hanif@example.com" \
    | "$HANIF" gsetup work 2>&1)
  assert_contains "Output prints public key"       "$out" "ssh-ed25519"
  assert_contains "Output mentions GitHub"         "$out" "github.com/settings/keys"
  assert_contains "Output mentions Azure DevOps"   "$out" "Azure DevOps"
  assert_contains "Output explains auto-apply"     "$out" "How it auto-applies"
}

test_gsetup_default_repos_dir_suggested() {
  # Accept the default repos dir (empty answer for the first prompt).
  printf '\n%s\n%s\ny\n' "Hanif Mianjee" "hanif@example.com" \
    | "$HANIF" gsetup work >/dev/null 2>&1
  assert_dir_exists "Default ~/code/<profile> dir created" "$TEST_HOME/code/work"
}

# ---------------------------------------------------------------------------
# Confirmation gating
# ---------------------------------------------------------------------------

test_gsetup_aborts_on_decline() {
  printf '%s\n%s\n%s\nn\n' "$TEST_HOME/code/work" "Hanif Mianjee" "hanif@example.com" \
    | "$HANIF" gsetup work >/dev/null 2>&1
  if [[ -f "$TEST_HOME/.gitconfig" ]] || [[ -f "$TEST_HOME/.ssh/id_ed25519_work" ]]; then
    ((TESTS_RUN++)) || true
    ((TESTS_FAILED++)) || true
    echo -e "\033[0;31m✗\033[0m Declining the prompt does NOT write any files"
  else
    ((TESTS_RUN++)) || true
    ((TESTS_PASSED++)) || true
    echo -e "\033[0;32m✓\033[0m Declining the prompt does NOT write any files"
  fi
}

# ---------------------------------------------------------------------------
# Idempotency / re-runs
# ---------------------------------------------------------------------------

test_gsetup_rerun_same_profile_replaces_block_in_place() {
  _run_setup "work" "$TEST_HOME/code/work" "Hanif Mianjee" "hanif@example.com"

  # Re-run with a different repos dir; reuse existing key (y) and
  # overwrite existing per-profile gitconfig (y).
  _run_setup "work" "$TEST_HOME/code/work2" "Hanif Mianjee" "hanif@example.com" "y" "y"

  local count_begin
  count_begin=$(grep -c '^# >>> hanif gsetup: work >>>$' "$TEST_HOME/.gitconfig" || true)
  assert_equals "Begin marker for same profile appears exactly once" "1" "$count_begin"

  local root_cfg
  root_cfg=$(cat "$TEST_HOME/.gitconfig")
  assert_contains "Root config now points at the new repos dir" "$root_cfg" "gitdir:$TEST_HOME/code/work2/"
  if grep -qF "gitdir:$TEST_HOME/code/work/" "$TEST_HOME/.gitconfig"; then
    ((TESTS_RUN++)) || true
    ((TESTS_FAILED++)) || true
    echo -e "\033[0;31m✗\033[0m Old gitdir entry was replaced"
  else
    ((TESTS_RUN++)) || true
    ((TESTS_PASSED++)) || true
    echo -e "\033[0;32m✓\033[0m Old gitdir entry was replaced"
  fi
}

test_gsetup_multiple_profiles_get_separate_blocks() {
  _run_setup "work"     "$TEST_HOME/code/work"     "Work Me"     "me@work.com"
  _run_setup "personal" "$TEST_HOME/code/personal" "Personal Me" "me@personal.com"

  local root_cfg
  root_cfg=$(cat "$TEST_HOME/.gitconfig")
  assert_contains "Work block present"     "$root_cfg" "# >>> hanif gsetup: work >>>"
  assert_contains "Personal block present" "$root_cfg" "# >>> hanif gsetup: personal >>>"
  assert_file_exists "Work profile gitconfig"     "$TEST_HOME/.gitconfig-work"
  assert_file_exists "Personal profile gitconfig" "$TEST_HOME/.gitconfig-personal"
  assert_file_exists "Work SSH key"     "$TEST_HOME/.ssh/id_ed25519_work"
  assert_file_exists "Personal SSH key" "$TEST_HOME/.ssh/id_ed25519_personal"
}

# ---------------------------------------------------------------------------
# File permissions
# ---------------------------------------------------------------------------

test_gsetup_sets_safe_permissions() {
  _run_setup "work" "$TEST_HOME/code/work" "Hanif Mianjee" "hanif@example.com"

  local key_perm cfg_perm ssh_dir_perm
  key_perm=$(stat -c '%a' "$TEST_HOME/.ssh/id_ed25519_work" 2>/dev/null \
              || stat -f '%Lp' "$TEST_HOME/.ssh/id_ed25519_work")
  cfg_perm=$(stat -c '%a' "$TEST_HOME/.gitconfig-work" 2>/dev/null \
              || stat -f '%Lp' "$TEST_HOME/.gitconfig-work")
  ssh_dir_perm=$(stat -c '%a' "$TEST_HOME/.ssh" 2>/dev/null \
              || stat -f '%Lp' "$TEST_HOME/.ssh")
  assert_equals "Private key is chmod 600"          "600" "$key_perm"
  assert_equals "Per-profile gitconfig is chmod 600" "600" "$cfg_perm"
  assert_equals "~/.ssh is chmod 700"               "700" "$ssh_dir_perm"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

main() {
  suite "gsetup — registration / help"
  run_test test_gsetup_command_registered
  run_test test_gsetup_help_topic_resolves
  run_test test_gsetup_alias_resolves
  run_test test_gsetup_legacy_passthrough_resolves

  suite "gsetup — validation"
  run_test test_gsetup_rejects_bad_profile_name_argument

  suite "gsetup — happy path"
  run_test test_gsetup_creates_all_artifacts
  run_test test_gsetup_prints_public_key_and_instructions
  run_test test_gsetup_default_repos_dir_suggested

  suite "gsetup — confirmation gating"
  run_test test_gsetup_aborts_on_decline

  suite "gsetup — idempotency"
  run_test test_gsetup_rerun_same_profile_replaces_block_in_place
  run_test test_gsetup_multiple_profiles_get_separate_blocks

  suite "gsetup — file permissions"
  run_test test_gsetup_sets_safe_permissions

  print_summary
}

main "$@"
