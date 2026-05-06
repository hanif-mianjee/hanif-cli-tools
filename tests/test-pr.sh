#!/usr/bin/env bash
#
# Tests for `hanif pr` — open the current branch's pull request page.
#
# We test URL generation for each supported host without ever opening a
# browser (HANIF_NO_BROWSER prints the URL instead of launching one).

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
  export HANIF_NO_BROWSER=1
  (
    cd "$TEST_REPO"
    git init -q
    git config user.email "t@t"
    git config user.name "t"
    echo a > f && git add f && git commit -qm init
    git checkout -q -b feature/login_form
  )
}

teardown() {
  if [[ -n "$TEST_HOME" && -d "$TEST_HOME" ]] \
     && [[ "$TEST_HOME" == /tmp/* || "$TEST_HOME" == /var/folders/* ]]; then
    rm -rf "$TEST_HOME"
  fi
  if [[ -n "$TEST_REPO" && -d "$TEST_REPO" ]] \
     && [[ "$TEST_REPO" == /tmp/* || "$TEST_REPO" == /var/folders/* ]]; then
    rm -rf "$TEST_REPO"
  fi
  unset HANIF_SKIP_UPDATE_CHECK HANIF_NO_BROWSER
}

_set_remote() {
  (cd "$TEST_REPO" && git remote remove origin >/dev/null 2>&1 || true; git remote add origin "$1")
}

# ---------------------------------------------------------------------------

test_pr_github_ssh() {
  _set_remote "git@github.com:foo/bar.git"
  local out
  out=$(cd "$TEST_REPO" && "$HANIF" pr url 2>&1)
  assert_contains "GitHub SSH parses" "$out" "https://github.com/foo/bar/compare/master...feature/login_form?expand=1"
}

test_pr_github_https() {
  _set_remote "https://github.com/foo/bar.git"
  local out
  out=$(cd "$TEST_REPO" && "$HANIF" pr url 2>&1)
  assert_contains "GitHub HTTPS parses" "$out" "https://github.com/foo/bar/compare/master...feature/login_form?expand=1"
}

test_pr_gitlab_subgroup() {
  _set_remote "https://gitlab.com/group/sub/proj.git"
  local out
  out=$(cd "$TEST_REPO" && "$HANIF" pr url 2>&1)
  assert_contains "GitLab subgroup parses" "$out" "https://gitlab.com/group/sub/proj/-/compare/master...feature/login_form"
}

test_pr_azure_devops() {
  _set_remote "https://dev.azure.com/myorg/myproj/_git/myrepo"
  local out
  out=$(cd "$TEST_REPO" && "$HANIF" pr url 2>&1)
  assert_contains "Azure DevOps parses" "$out" "https://dev.azure.com/myorg/myproj/_git/myrepo/pullrequestcreate?sourceRef=feature/login_form&targetRef=master"
}

test_pr_visualstudio_legacy() {
  _set_remote "https://myorg.visualstudio.com/myproj/_git/myrepo"
  local out
  out=$(cd "$TEST_REPO" && "$HANIF" pr url 2>&1)
  assert_contains "visualstudio.com mapped to dev.azure.com" "$out" "https://dev.azure.com/myorg/myproj/_git/myrepo/pullrequestcreate"
}

test_pr_bitbucket() {
  _set_remote "git@bitbucket.org:owner/repo.git"
  local out
  out=$(cd "$TEST_REPO" && "$HANIF" pr url 2>&1)
  assert_contains "Bitbucket parses" "$out" "https://bitbucket.org/owner/repo/pull-requests/new?source=feature/login_form&dest=master"
}

test_pr_custom_base() {
  _set_remote "git@github.com:foo/bar.git"
  local out
  out=$(cd "$TEST_REPO" && "$HANIF" pr url --base develop 2>&1)
  assert_contains "Custom --base used in URL" "$out" "compare/develop...feature/login_form"
}

test_pr_open_action_prints_url_with_no_browser() {
  _set_remote "git@github.com:foo/bar.git"
  local out
  out=$(cd "$TEST_REPO" && "$HANIF" pr 2>&1)
  assert_contains "open action prints opening line" "$out" "Opening:"
  assert_contains "open action prints url"          "$out" "compare/master...feature/login_form"
}

test_pr_no_remote_errors() {
  (cd "$TEST_REPO" && git remote remove origin >/dev/null 2>&1 || true)
  local out rc
  set +e
  out=$(cd "$TEST_REPO" && "$HANIF" pr url 2>&1)
  rc=$?
  set -e
  assert_equals "Missing remote returns non-zero" "1" "$rc"
  assert_contains "Missing remote error" "$out" "Remote not found"
}

test_pr_unsupported_host() {
  _set_remote "git@example.com:foo/bar.git"
  local out rc
  set +e
  out=$(cd "$TEST_REPO" && "$HANIF" pr url 2>&1)
  rc=$?
  set -e
  assert_equals "Unsupported host returns non-zero" "1" "$rc"
  assert_contains "Unsupported host error" "$out" "Unsupported remote host"
}

test_pr_branch_equals_base_warns() {
  _set_remote "git@github.com:foo/bar.git"
  (cd "$TEST_REPO" && git checkout -q master)
  local out rc
  set +e
  out=$(cd "$TEST_REPO" && "$HANIF" pr url 2>&1)
  rc=$?
  set -e
  assert_equals "Branch == base returns non-zero" "1" "$rc"
  assert_contains "Same-branch warning" "$out" "no PR to open"
}

test_pr_outside_git_repo_errors() {
  local tmp out rc
  tmp=$(mktemp -d)
  set +e
  out=$(cd "$tmp" && "$HANIF" pr url 2>&1)
  rc=$?
  set -e
  rm -rf "$tmp"
  assert_equals "Outside repo returns non-zero" "1" "$rc"
  assert_contains "Not-a-repo error" "$out" "Not inside a git repository"
}

test_pr_invalid_remote_name_rejected() {
  _set_remote "git@github.com:foo/bar.git"
  local out rc
  set +e
  out=$(cd "$TEST_REPO" && "$HANIF" pr url --remote 'bad name' 2>&1)
  rc=$?
  set -e
  assert_equals "Invalid remote name rejected" "1" "$rc"
  assert_contains "Invalid remote error" "$out" "Invalid remote"
}

# ---------------------------------------------------------------------------

main() {
  suite "PR command — URL generation"
  run_test test_pr_github_ssh
  run_test test_pr_github_https
  run_test test_pr_gitlab_subgroup
  run_test test_pr_azure_devops
  run_test test_pr_visualstudio_legacy
  run_test test_pr_bitbucket
  run_test test_pr_custom_base
  run_test test_pr_open_action_prints_url_with_no_browser

  suite "PR command — error paths"
  run_test test_pr_no_remote_errors
  run_test test_pr_unsupported_host
  run_test test_pr_branch_equals_base_warns
  run_test test_pr_outside_git_repo_errors
  run_test test_pr_invalid_remote_name_rejected

  print_summary
}

main "$@"
