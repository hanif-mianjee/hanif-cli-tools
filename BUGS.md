# Bug Analysis Report

Discovered bugs in Hanif CLI, ordered by severity. All bugs have been fixed.

---

## 1. CRITICAL: `sed -i ''` Linux Incompatibility — FIXED

- **File:** `lib/functions/squash-functions.sh:85`
- **Description:** `sed -i ''` is macOS-only syntax. On Linux, `sed -i` requires no empty string argument, and `sed -i ''` causes an error. This makes the `squash` command completely broken on Linux.
- **Fix:** OS detection in squash-functions.sh generates correct sed syntax. Added portable `sed_inplace` helper in `common.sh`. Also fixed `scripts/publish.sh` which had the same issue.

## 2. HIGH: Double Underscore in Branch Names with Special Characters — FIXED

- **File:** `lib/functions/git-functions.sh:140`
- **Description:** When input like `"fix - bug"` is passed to `newfeature`, the special char is stripped (leaving adjacent spaces), then spaces are converted to underscores, producing `fix__bug` instead of `fix_bug`.
- **Fix:** Added `sed -E 's/[[:space:]_-]+/ /g'` to collapse runs of spaces/underscores/hyphens before converting to underscores. Applied to both `newfeature()` and `sanitize_branch_name()`.

## 3. HIGH: Non-POSIX `sed` Extension Used — FIXED

- **File:** `lib/functions/git-functions.sh:144`
- **Description:** `sed 's/_\+/_/g'` uses `\+` which is a GNU sed extension and not POSIX-compliant.
- **Fix:** Changed to `sed -E 's/_+/_/g'` for portable extended regex.

## 4. MEDIUM: `$?` Check After Rebase is Unreachable Due to `set -e` — FIXED

- **File:** `lib/functions/squash-functions.sh:95`
- **Description:** The file uses `set -euo pipefail`. If the `git rebase` command fails, the script exits immediately due to `set -e`, so `if [ $? -eq 0 ]` is always true when reached.
- **Fix:** Changed to `local rebase_ok=true; ... || rebase_ok=false` pattern to capture the exit status without triggering `set -e`.

## 5. MEDIUM: `check_git_version()` Defined But Never Called — FIXED

- **File:** `lib/utils/common.sh:101`
- **Description:** The function `check_git_version()` is defined and exported but never invoked anywhere in the codebase.
- **Fix:** Now called in `git_command()` dispatcher so it runs on every git-related command.

## 6. LOW: Redundant `|| true || true` in Test Framework — FIXED

- **File:** `tests/test-framework.sh:34`
- **Description:** `((TESTS_RUN++)) || true || true` — the second `|| true` is redundant.
- **Fix:** Simplified all occurrences to `((TESTS_RUN++)) || true`.

## 7. LOW: `gitclean` Could Skip Wrong Branches in Detached HEAD — FIXED

- **File:** `lib/functions/git-functions.sh` (`gitclean`)
- **Description:** When in detached HEAD, `current_branch` is set to `""` and inserted into the protected-branches array, producing `"main", "master", ""`. The substring match `[[ " ${arr[*]} " =~ " ${branch} " ]]` could behave unexpectedly with the empty entry.
- **Fix:** Build the protected-branches array conditionally — only append `current_branch` when it's non-empty.

## 8. LOW: Squash Built `git rebase` Command via Shell-String Expansion — FIXED

- **File:** `lib/functions/squash-functions.sh`
- **Description:** The squash function stored the rebase invocation in `rebase_cmd="git rebase -i ..."` and later expanded it unquoted (`$rebase_cmd`). While `base_hash` was numeric in practice, the pattern is fragile and a defense-in-depth concern.
- **Fix:** Switched to an array (`rebase_cmd=(git rebase -i "${base_hash}^")`) and invoked via `"${rebase_cmd[@]}"`. Added a strict 7-hex regex validation on `base_hash` before any git invocation. Temp files used for the sequence editor and commit message are now `chmod 700`/`chmod 600` after `mktemp`.

## 9. LOW: `bin/hanif` Symlink Resolution Did Not Follow Chains — FIXED

- **File:** `bin/hanif`
- **Description:** Resolved `$0` once via `readlink "$0"`, which doesn't follow chains of symlinks (e.g. `/usr/local/bin/hanif → /opt/hanif/bin/hanif → real`).
- **Fix:** Now follows the full chain using a loop on `BASH_SOURCE[0]` with `-L` checks and resolves relative link targets correctly.

## 10. LOW: `bin/hanif` Could Mask Command Exit Code — FIXED

- **File:** `bin/hanif`
- **Description:** The trailing `[[ … ]] && check_for_updates || true` ran after `main "$@"`. With `set -e` the script exited early on failure (so the line was unreachable), but on success the update-check expression returned 0, which was then the exit code of the script regardless of `main`'s subtleties.
- **Fix:** Capture `_hanif_exit=$?` immediately after `main`, run the update check best-effort, then `exit "$_hanif_exit"`.
