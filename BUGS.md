# Bug Analysis Report

Discovered bugs in Hanif CLI, ordered by severity.

---

## 1. CRITICAL: `sed -i ''` Linux Incompatibility

- **File:** `lib/functions/squash-functions.sh:85`
- **Description:** `sed -i ''` is macOS-only syntax. On Linux, `sed -i` requires no empty string argument, and `sed -i ''` causes an error. This makes the `squash` command completely broken on Linux.
- **Fix:** Create a portable `sed_inplace` helper that detects OS and uses the correct `sed -i` syntax.

## 2. HIGH: Double Underscore in Branch Names with Special Characters

- **File:** `lib/functions/git-functions.sh:140`
- **Description:** When input like `"fix - bug"` is passed to `newfeature`, the special char is stripped (leaving adjacent spaces), then spaces are converted to underscores, producing `fix__bug` instead of `fix_bug`. The `sed 's/_\+/_/g'` on line 144 should fix this but uses a GNU extension (see bug #3).
- **Fix:** Collapse multiple spaces before converting to underscores, and strip standalone hyphens surrounded by spaces.

## 3. HIGH: Non-POSIX `sed` Extension Used

- **File:** `lib/functions/git-functions.sh:144`
- **Description:** `sed 's/_\+/_/g'` uses `\+` which is a GNU sed extension and not POSIX-compliant. On strict POSIX systems or BSD sed (macOS), this may not match as intended. Should use `-E` flag with `+` or POSIX BRE `\{1,\}`.
- **Fix:** Change to `sed -E 's/_+/_/g'` for portable extended regex, or use `sed 's/__*/_/g'`.

## 4. MEDIUM: `$?` Check After Rebase is Unreachable Due to `set -e`

- **File:** `lib/functions/squash-functions.sh:95`
- **Description:** The file uses `set -euo pipefail` (line 6). If the `git rebase` command on line 90 fails, the script exits immediately due to `set -e`, so `if [ $? -eq 0 ]` on line 95 is always true when reached. The failure path of this conditional is dead code.
- **Fix:** Capture the exit code by using `if GIT_SEQUENCE_EDITOR="$seq_script" $rebase_cmd; then` pattern instead.

## 5. MEDIUM: `check_git_version()` Defined But Never Called

- **File:** `lib/utils/common.sh:101`
- **Description:** The function `check_git_version()` is defined and exported but never invoked anywhere in the codebase. It validates minimum git version 2.0.0 which would be useful as a startup check.
- **Fix:** Consider calling it during CLI initialization, or remove the dead code.

## 6. LOW: Redundant `|| true || true` in Test Framework

- **File:** `tests/test-framework.sh:34`
- **Description:** `((TESTS_RUN++)) || true || true` — a single `|| true` is sufficient to prevent `set -e` from triggering when the arithmetic result is 0. The second `|| true` is redundant.
- **Fix:** Simplify to `((TESTS_RUN++)) || true`.

## 7. LOW: Homebrew Formula Has Placeholder SHA256

- **File:** `hanif-cli.rb:5`
- **Description:** The SHA256 checksum is set to `"SHA256_CHECKSUM_HERE"` — a placeholder value. Homebrew will fail to verify the download integrity if someone tries to install via this formula.
- **Fix:** Generate the real SHA256 from the v0.1.0 release tarball and update the formula.
