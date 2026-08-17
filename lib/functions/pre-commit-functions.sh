#!/usr/bin/env bash
#
# pre-commit-functions.sh
#
# Implementation of `hanif pre-commit` — interactive installer for a
# pure-shell `.git/hooks/pre-commit` script tailored to the project's
# detected stack(s). See `lib/commands/pre-commit.sh` for the dispatcher
# and full help.
#
# Design notes
# ------------
# • The generated hook is fully self-contained — it does not source any
#   hanif file at commit time. Helpers like `_pc_ok` / `_pc_fail` are
#   defined inline in the rendered hook.
# • A managed block, delimited by marker comments, sits at the bottom of
#   the hook file. Re-running `hanif pre-commit` rewrites JUST that block;
#   anything the user added above the shebang or after the end-marker is
#   preserved.
# • Each check is wrapped in a small function. They share a `PC_FAILED`
#   array and accumulate failures rather than failing fast — we want the
#   user to see every problem on a single run.
# • Stack-specific blocks guard `command -v <tool>` and emit a faint
#   "skipped" line when the tool isn't installed (so a fresh clone on a
#   machine without `cargo` doesn't block commits).
# • Test mode: HANIF_PRE_COMMIT_ROOT picks the repo root, HANIF_PRE_COMMIT_YES
#   auto-confirms, HANIF_PRE_COMMIT_CHECKS skips the picker, and
#   HANIF_PRE_COMMIT_CUSTOM injects custom commands without prompting.

# Guard against multiple sourcing of this same file. We intentionally
# allow `register_command`-side re-sourcing of the *command* file, but
# the function definitions only need to load once per process.
if [[ -n "${HANIF_PRE_COMMIT_FUNCTIONS_LOADED:-}" ]]; then
  return 0
fi
readonly HANIF_PRE_COMMIT_FUNCTIONS_LOADED=1

# Marker strings — these appear literally in the generated hook AND in
# the install logic that detects "ours vs theirs". Define once.
HPC_MARK_BEGIN='# >>> hanif pre-commit: managed >>>'
HPC_MARK_END='# <<< hanif pre-commit: managed <<<'

# ---------------------------------------------------------------------------
# Path & git context helpers
# ---------------------------------------------------------------------------

# Resolve the repo root. Honours HANIF_PRE_COMMIT_ROOT so tests can point
# at a sandboxed git repo without needing to cd into it.
_hpc_repo_root() {
  if [[ -n "${HANIF_PRE_COMMIT_ROOT:-}" ]]; then
    echo "$HANIF_PRE_COMMIT_ROOT"
    return 0
  fi
  git rev-parse --show-toplevel 2>/dev/null
}

# Hooks dir — always the git-native location under the repo's git dir.
# We deliberately do NOT honour `core.hooksPath` here: if the user has
# configured an alternate hooks path, we still write to `.git/hooks/`
# and surface a warning at install time so the choice stays theirs.
# `git rev-parse --git-dir` correctly handles worktrees.
_hpc_hooks_dir() {
  local root gitdir
  root=$(_hpc_repo_root)
  if [[ -z "$root" ]]; then
    return 1
  fi
  gitdir=$(cd "$root" && git rev-parse --git-dir 2>/dev/null || true)
  if [[ -z "$gitdir" ]]; then
    return 1
  fi
  if [[ "$gitdir" = /* ]]; then
    echo "$gitdir/hooks"
  else
    echo "$root/$gitdir/hooks"
  fi
}

# Full path to the hook file we manage.
_hpc_hook_path() {
  local d
  d=$(_hpc_hooks_dir) || return 1
  echo "$d/pre-commit"
}

# Refuse if we're not inside a real (non-bare) git repo.
_hpc_require_git_repo() {
  if [[ -n "${HANIF_PRE_COMMIT_ROOT:-}" ]]; then
    if [[ ! -d "$HANIF_PRE_COMMIT_ROOT/.git" ]] \
       && ! (cd "$HANIF_PRE_COMMIT_ROOT" 2>/dev/null && git rev-parse --git-dir >/dev/null 2>&1); then
      error "Not a git repository: $HANIF_PRE_COMMIT_ROOT"
      return 1
    fi
  else
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
      error "Not a git repository (run inside one)."
      return 1
    fi
  fi
  local bare
  bare=$(cd "$(_hpc_repo_root)" 2>/dev/null && git rev-parse --is-bare-repository 2>/dev/null || true)
  if [[ "$bare" == "true" ]]; then
    error "Bare repositories are not supported."
    return 1
  fi
  return 0
}

# Warn (but don't fail) when git is configured to load hooks from a
# non-default path — our hook will be written to .git/hooks/pre-commit,
# which git won't pick up automatically until the user unsets the override.
_hpc_warn_if_custom_hooks_path() {
  local root configured
  root=$(_hpc_repo_root)
  configured=$(cd "$root" 2>/dev/null && git config --get core.hooksPath 2>/dev/null || true)
  if [[ -n "$configured" ]]; then
    # Resolve to absolute so the comparison is meaningful.
    local resolved="$configured"
    if [[ "$resolved" != /* ]]; then
      resolved="$root/$configured"
    fi
    # Treat anything inside <root>/.git/hooks as the default location.
    if [[ "$resolved" != "$root/.git/hooks"* ]]; then
      warning "git core.hooksPath is set to: $configured"
      hint "  Your new hook will be written to .git/hooks/pre-commit, but"
      hint "  git will not run hooks from there while core.hooksPath points"
      hint "  elsewhere. Either unset it (\`git config --unset core.hooksPath\`)"
      hint "  or move the generated hook into the configured path."
    fi
  fi
}

# ---------------------------------------------------------------------------
# Stack detection
# ---------------------------------------------------------------------------

# Echoes a space-separated list of stack IDs detected at the repo root.
# Stable order (matches the catalog grouping below).
_hpc_detect_stacks() {
  local root
  root=$(_hpc_repo_root)
  [[ -z "$root" ]] && return 0

  local stacks=()
  [[ -f "$root/package.json" ]] && stacks+=("node")
  if [[ -f "$root/pyproject.toml" || -f "$root/setup.py" \
        || -f "$root/setup.cfg" || -f "$root/requirements.txt" ]]; then
    stacks+=("python")
  fi
  [[ -f "$root/Cargo.toml" ]] && stacks+=("rust")
  [[ -f "$root/go.mod" ]] && stacks+=("go")
  if [[ -f "$root/pom.xml" || -f "$root/build.gradle" \
        || -f "$root/build.gradle.kts" ]]; then
    stacks+=("java")
  fi
  [[ -f "$root/Gemfile" ]] && stacks+=("ruby")
  [[ -f "$root/composer.json" ]] && stacks+=("php")

  # Bash 3.2 treats ${arr[*]} on a declared-but-empty array as unset
  # under `set -u`. The :- default keeps an empty stack list quiet.
  echo "${stacks[*]:-}"
}

# Human-readable label for a stack ID. Used in the picker.
_hpc_stack_label() {
  case "$1" in
    node)   echo "Node.js" ;;
    python) echo "Python" ;;
    rust)   echo "Rust" ;;
    go)     echo "Go" ;;
    java)   echo "Java" ;;
    ruby)   echo "Ruby" ;;
    php)    echo "PHP" ;;
    *)      echo "$1" ;;
  esac
}

# ---------------------------------------------------------------------------
# Catalog
# ---------------------------------------------------------------------------
# Catalog functions emit one line per entry. Two line types:
#   GROUP:<label>            — a section header in the picker.
#   ITEM:<id>|<label>|<desc> — a numbered, selectable check.
#
# _hpc_catalog_full takes the detected stack list and assembles the menu
# data. The picker (`_hpc_select_checks`) consumes it.

_hpc_catalog_universal() {
  printf 'GROUP:Universal\n'
  printf 'ITEM:%s\n' \
    'protect-branches|protect-branches|Block commits to protected branches' \
    'no-merge-markers|no-merge-markers|Reject staged content with <<<<<<<, =======, >>>>>>>' \
    'no-large-files|no-large-files|Reject staged files larger than N MB' \
    'no-secrets|no-secrets|Scan staged additions for AWS keys / private keys' \
    'no-env-files|no-env-files|Reject staging .env (with allowlist)' \
    'no-trailing-whitespace|no-trailing-whitespace|Reject staged lines ending in whitespace' \
    'no-debug|no-debug|Reject debugger / console.log / breakpoint() / dd() / dbg!()'
}

_hpc_catalog_for_stack() {
  local stack="$1"
  printf 'GROUP:%s\n' "$(_hpc_stack_label "$stack")"
  case "$stack" in
    node)
      printf 'ITEM:%s\n' \
        'node-lint|node-lint|Run lint via the detected package manager' \
        'node-format|node-format|Prettier --check on staged JS/TS' \
        'node-test|node-test|Run the project test script' \
        'node-typecheck|node-typecheck|tsc --noEmit'
      ;;
    python)
      printf 'ITEM:%s\n' \
        'py-ruff|py-ruff|ruff check on staged .py' \
        'py-format|py-format|ruff format --check (falls back to black --check)' \
        'py-mypy|py-mypy|mypy on staged .py' \
        'py-pytest|py-pytest|Run pytest'
      ;;
    rust)
      printf 'ITEM:%s\n' \
        'rust-fmt|rust-fmt|cargo fmt --all -- --check' \
        'rust-clippy|rust-clippy|cargo clippy -- -D warnings' \
        'rust-test|rust-test|cargo test'
      ;;
    go)
      printf 'ITEM:%s\n' \
        'go-fmt|go-fmt|gofmt -l (any output = fail)' \
        'go-vet|go-vet|go vet ./...' \
        'go-test|go-test|go test ./...'
      ;;
    java)
      printf 'ITEM:%s\n' \
        'java-maven|java-maven|mvn -q verify' \
        'java-gradle|java-gradle|./gradlew check'
      ;;
    ruby)
      printf 'ITEM:%s\n' \
        'ruby-rspec|ruby-rspec|bundle exec rspec'
      ;;
    php)
      printf 'ITEM:%s\n' \
        'php-composer-test|php-composer-test|composer test'
      ;;
  esac
}

# Assembled menu data (universal + each detected stack).
# $* = space-separated stack list (may be empty).
_hpc_catalog_full() {
  _hpc_catalog_universal
  local s
  for s in $*; do
    _hpc_catalog_for_stack "$s"
  done
}

# The "recommended" preset — universal safety nets plus the lint/format
# check(s) of each detected stack. Returned as a space-separated ID list.
_hpc_recommended_ids() {
  local stacks="$*"
  local ids="protect-branches no-merge-markers no-secrets no-env-files"
  local s
  for s in $stacks; do
    case "$s" in
      node)   ids="$ids node-lint node-format" ;;
      python) ids="$ids py-ruff py-format" ;;
      rust)   ids="$ids rust-fmt" ;;
      go)     ids="$ids go-fmt go-vet" ;;
      java)   ids="$ids java-gradle" ;;
      ruby)   ids="$ids ruby-rspec" ;;
      php)    ids="$ids php-composer-test" ;;
    esac
  done
  echo "$ids"
}

# ---------------------------------------------------------------------------
# Interactive prompts
# ---------------------------------------------------------------------------

# Bypassable confirm. HANIF_PRE_COMMIT_YES=1 → auto-accept.
_hpc_confirm() {
  if [[ -n "${HANIF_PRE_COMMIT_YES:-}" ]]; then
    return 0
  fi
  confirm "$@"
}

# Read a line with optional default + validator. Result in _HPC_PROMPT_VALUE.
# In YES mode, accepts the default (or empty) without prompting.
_hpc_prompt() {
  local label="$1"
  local default="${2:-}"
  local validator="${3:-}"
  local err_msg="${4:-Invalid value, please try again.}"

  if [[ -n "${HANIF_PRE_COMMIT_YES:-}" ]]; then
    _HPC_PROMPT_VALUE="$default"
    return 0
  fi

  local response prompt_str
  while true; do
    if [[ -n "$default" ]]; then
      prompt_str=$(_hanif_render 1 "${YELLOW}?${NC}  ${label} ${DIM}[${default}]${NC}: ")
    else
      prompt_str=$(_hanif_render 1 "${YELLOW}?${NC}  ${label}: ")
    fi
    read -r -p "$prompt_str" response
    [[ -z "$response" && -n "$default" ]] && response="$default"
    if [[ -z "$response" && -z "$default" ]]; then
      error "Value is required."
      continue
    fi
    if [[ -n "$validator" ]] && ! "$validator" "$response"; then
      error "$err_msg"
      continue
    fi
    _HPC_PROMPT_VALUE="$response"
    return 0
  done
}

# Validator: list of branch tokens separated by whitespace, each matching
# a permissive but safe branch-name shape.
_hpc_valid_branches() {
  local input="$1" tok
  [[ -z "$input" ]] && return 1
  for tok in $input; do
    [[ "$tok" =~ ^[A-Za-z0-9._/-]+$ ]] || return 1
  done
  return 0
}

# Validator: positive integer, capped at 1024 (1 GB feels like a sane ceiling).
_hpc_valid_mb() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]] && [ "$1" -le 1024 ]
}

# Validator: env allowlist tokens — same shape as filenames sans newlines.
_hpc_valid_env_allowlist() {
  local input="$1" tok
  [[ -z "$input" ]] && return 1
  for tok in $input; do
    [[ "$tok" =~ ^[A-Za-z0-9._/-]+$ ]] || return 1
  done
  return 0
}

# Validator: free-form shell command. Reject newlines & null. Cap length.
_hpc_valid_custom_cmd() {
  local cmd="$1"
  [[ -n "$cmd" ]] || return 1
  [[ "$cmd" != *$'\n'* ]] || return 1
  [[ ${#cmd} -le 500 ]] || return 1
  return 0
}

# ---------------------------------------------------------------------------
# Picker — multi-select with keyword shortcuts
# ---------------------------------------------------------------------------
# Reads catalog data from $1 (a file path).
# Resolves the user's selection to space-separated IDs on stdout.
# In YES mode, uses HANIF_PRE_COMMIT_CHECKS if set, else "recommended".
_hpc_select_checks() {
  local catalog_file="$1"
  local stacks="$2"

  # Build a numbered item list (parallel arrays: ids + labels + descs).
  local -a item_ids=() item_labels=() item_descs=()
  local -a all_ids=()
  local line
  while IFS= read -r line; do
    case "$line" in
      ITEM:*)
        local payload="${line#ITEM:}"
        local id="${payload%%|*}"
        local rest="${payload#*|}"
        local label="${rest%%|*}"
        local desc="${rest#*|}"
        item_ids+=("$id")
        item_labels+=("$label")
        item_descs+=("$desc")
        all_ids+=("$id")
        ;;
    esac
  done < "$catalog_file"

  # Non-interactive shortcut — HANIF_PRE_COMMIT_CHECKS overrides everything.
  # The resolver normalizes whitespace internally, so we can pass any
  # mix of commas / spaces / tabs straight through.
  if [[ -n "${HANIF_PRE_COMMIT_CHECKS:-}" ]]; then
    _hpc_resolve_keyword "$HANIF_PRE_COMMIT_CHECKS" "$stacks" "${all_ids[@]}"
    return $?
  fi

  if [[ -n "${HANIF_PRE_COMMIT_YES:-}" ]]; then
    _hpc_recommended_ids $stacks
    return 0
  fi

  # Render the menu.
  echo "" >&2
  local n=0
  local item_idx=0
  while IFS= read -r line; do
    case "$line" in
      GROUP:*)
        local g="${line#GROUP:}"
        echo "" >&2
        _hanif_render 2 "  ${BOLD}${MAGENTA}${g}${NC}" >&2; printf '\n' >&2
        ;;
      ITEM:*)
        n=$((n + 1))
        _hanif_render 2 "   ${CYAN}$(printf '%2d' "$n")${NC}) $(printf '%-26s' "${item_labels[$item_idx]}")  ${DIM}${item_descs[$item_idx]}${NC}" >&2
        printf '\n' >&2
        item_idx=$((item_idx + 1))
        ;;
    esac
  done < "$catalog_file"
  echo "" >&2

  local total=${#item_ids[@]}
  if [[ $total -eq 0 ]]; then
    return 0
  fi

  # Read & resolve.
  local raw resolved
  while true; do
    local prompt_str
    prompt_str=$(_hanif_render 2 "${YELLOW}?${NC}  Select  ${DIM}[numbers, \`all\`, \`none\`, \`universal\`, \`recommended\`; Enter=recommended]${NC}: ")
    printf '%s' "$prompt_str" >&2
    read -r raw
    raw="${raw// /,}"
    raw="${raw//[$'\t\r']/,}"
    raw="${raw#,}"
    raw="${raw%,}"

    if [[ -z "$raw" ]]; then
      resolved=$(_hpc_recommended_ids $stacks)
      break
    fi

    if resolved=$(_hpc_resolve_selection "$raw" "$stacks" "${item_ids[@]}"); then
      break
    fi
    # _hpc_resolve_selection already printed the error.
  done

  # De-duplicate while preserving order.
  local seen=" " final=""
  local id
  for id in $resolved; do
    if [[ "$seen" != *" $id "* ]]; then
      final="$final $id"
      seen="$seen$id "
    fi
  done
  final="${final# }"
  echo "$final"
}

# Resolve a raw selection string (comma-separated numbers & keywords)
# against the full id list. On unknown tokens, prints an `error` to
# stderr and returns non-zero. On success, prints space-separated IDs.
_hpc_resolve_selection() {
  local raw="$1"
  local stacks="$2"
  shift 2
  local -a all_ids=("$@")
  local total=${#all_ids[@]}

  # Normalize separators: any whitespace becomes a comma so we can split
  # uniformly. Callers may pass commas, spaces, tabs, or any combo.
  raw="${raw//	/,}"   # literal tab
  raw="${raw// /,}"
  raw="${raw#,}"
  raw="${raw%,}"

  local token result=""
  local IFS=,
  for token in $raw; do
    token="${token// /}"
    [[ -z "$token" ]] && continue
    case "$token" in
      all)
        result="${all_ids[*]:-}"
        ;;
      none)
        result=""
        ;;
      universal)
        result="$result protect-branches no-merge-markers no-large-files no-secrets no-env-files no-trailing-whitespace no-debug"
        ;;
      recommended)
        result="$result $(_hpc_recommended_ids $stacks)"
        ;;
      *)
        if [[ "$token" =~ ^[0-9]+$ ]]; then
          if (( token < 1 || token > total )); then
            error "Number out of range: $token (have 1..$total)"
            return 1
          fi
          result="$result ${all_ids[$((token - 1))]}"
        else
          # Treat as a direct ID if it matches one in the catalog.
          local found=0 candidate
          for candidate in "${all_ids[@]}"; do
            if [[ "$candidate" == "$token" ]]; then
              result="$result $token"
              found=1
              break
            fi
          done
          if [[ $found -eq 0 ]]; then
            error "Unknown selection: $token"
            return 1
          fi
        fi
        ;;
    esac
  done

  echo "$result"
  return 0
}

# Variant used by the non-interactive HANIF_PRE_COMMIT_CHECKS path.
# Same as _hpc_resolve_selection but errors are fatal (no re-prompt).
_hpc_resolve_keyword() {
  local raw="$1"
  local stacks="$2"
  shift 2
  local -a all_ids=("$@")

  local resolved
  if ! resolved=$(_hpc_resolve_selection "$raw" "$stacks" "${all_ids[@]}"); then
    return 1
  fi

  # De-duplicate preserving order.
  local seen=" " final="" id
  for id in $resolved; do
    if [[ "$seen" != *" $id "* ]]; then
      final="$final $id"
      seen="$seen$id "
    fi
  done
  echo "${final# }"
}

# ---------------------------------------------------------------------------
# Custom-command collection
# ---------------------------------------------------------------------------
# Reads from HANIF_PRE_COMMIT_CUSTOM if set; otherwise interactive prompt.
# Echoes one command per line on stdout.
_hpc_collect_custom_commands() {
  if [[ -n "${HANIF_PRE_COMMIT_CUSTOM:-}" ]]; then
    # Split on newlines; preserve quoting within a single line.
    printf '%s\n' "$HANIF_PRE_COMMIT_CUSTOM" | while IFS= read -r ln; do
      [[ -n "$ln" ]] && printf '%s\n' "$ln"
    done
    return 0
  fi

  if [[ -n "${HANIF_PRE_COMMIT_YES:-}" ]]; then
    return 0
  fi

  # Interactive loop.
  if ! _hpc_confirm "Add a custom shell command to run as part of the hook?"; then
    return 0
  fi

  local cmd
  while true; do
    _hpc_prompt "Shell command (single line, max 500 chars)" "" \
      _hpc_valid_custom_cmd \
      "Must be non-empty, no newlines, at most 500 characters."
    cmd="$_HPC_PROMPT_VALUE"
    printf '%s\n' "$cmd"
    if ! _hpc_confirm "Add another?"; then
      break
    fi
  done
}

# ---------------------------------------------------------------------------
# Hook body — boilerplate that appears once at the top of every managed
# block. Defines PC_FAILED, _pc_ok, _pc_fail, _pc_skip, _pc_skip_if_env,
# and computes PC_STAGED_FILES.
# ---------------------------------------------------------------------------
_hpc_emit_preamble() {
  local stacks="$1" check_ids_csv="$2"
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)

  printf '%s\n' "$HPC_MARK_BEGIN"
  cat <<'PRE1'
# DO NOT EDIT between these markers. Re-run `hanif pre-commit` to update.
PRE1
  printf '# Generated: %s by hanif v%s\n' "$ts" "${VERSION:-?}"
  printf '# Detected stacks: %s\n' "${stacks:-(none — universal only)}"
  printf '# Selected checks: %s\n' "$check_ids_csv"
  cat <<'PRE2'
# Skip a check at commit time:  HANIF_PRECOMMIT_SKIP=<id1,id2,...> git commit ...
# Bypass all hooks (use sparingly):  git commit --no-verify

set -u

PC_FAILED=()
PC_STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  PC_R=$'\033[0;31m'; PC_G=$'\033[0;32m'; PC_Y=$'\033[1;33m'
  PC_D=$'\033[2m';    PC_N=$'\033[0m'
else
  PC_R=""; PC_G=""; PC_Y=""; PC_D=""; PC_N=""
fi

_pc_ok()   { printf '  %s✓%s  %s\n' "$PC_G" "$PC_N" "$1"; }
_pc_fail() { printf '  %s✗%s  %s — %s\n' "$PC_R" "$PC_N" "$1" "$2" >&2; PC_FAILED+=("$1"); }
_pc_skip() { printf '  %s–  %s (%s)%s\n' "$PC_D" "$1" "$2" "$PC_N"; }

_pc_skip_if_env() {
  case ",${HANIF_PRECOMMIT_SKIP:-}," in
    *,$1,*) _pc_skip "$1" "skipped via HANIF_PRECOMMIT_SKIP"; return 0 ;;
  esac
  return 1
}

_pc_filtered() {
  local pattern="$1"
  [ -z "$PC_STAGED_FILES" ] && return 0
  printf '%s\n' "$PC_STAGED_FILES" | grep -E "$pattern" || true
}

PRE2
}

# Trailer — failure summary + exit code.
_hpc_emit_trailer() {
  cat <<'POST'
if [ ${#PC_FAILED[@]} -gt 0 ]; then
  printf '\n%s%d check(s) failed:%s\n' "$PC_R" "${#PC_FAILED[@]}" "$PC_N" >&2
  for _pc_id in "${PC_FAILED[@]}"; do
    printf '  - %s\n' "$_pc_id" >&2
  done
  printf '\n%sTo skip a specific check just this once:%s\n' "$PC_Y" "$PC_N" >&2
  printf '  HANIF_PRECOMMIT_SKIP=<id> git commit ...\n' >&2
  exit 1
fi
exit 0
POST
  printf '%s\n' "$HPC_MARK_END"
}

# ---------------------------------------------------------------------------
# Universal check emitters
# ---------------------------------------------------------------------------

_hpc_emit_protect_branches() {
  local branches="$1"
  printf '# --- check:protect-branches ---\n'
  printf '_pc_check_protect_branches() {\n'
  printf '  _pc_skip_if_env protect-branches && return 0\n'
  printf '  local current b\n'
  printf '  current=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)\n'
  printf '  for b in %s; do\n' "$branches"
  cat <<'BODY'
    if [ "$current" = "$b" ]; then
      _pc_fail protect-branches "direct commit to '$current' is not allowed"
      return 0
    fi
  done
  _pc_ok protect-branches
}
_pc_check_protect_branches
BODY
  printf '# --- /check:protect-branches ---\n\n'
}

_hpc_emit_no_merge_markers() {
  cat <<'BLOCK'
# --- check:no-merge-markers ---
_pc_check_no_merge_markers() {
  _pc_skip_if_env no-merge-markers && return 0
  if [ -z "$PC_STAGED_FILES" ]; then _pc_ok no-merge-markers; return 0; fi
  local diff
  diff=$(git diff --cached -U0 2>/dev/null || true)
  if printf '%s\n' "$diff" | grep -Eq '^\+(<{7}|={7}|>{7})( |$)'; then
    _pc_fail no-merge-markers "merge conflict markers found in staged additions"
    return 0
  fi
  _pc_ok no-merge-markers
}
_pc_check_no_merge_markers
# --- /check:no-merge-markers ---

BLOCK
}

_hpc_emit_no_large_files() {
  local max_mb="$1"
  printf '# --- check:no-large-files ---\n'
  printf '_pc_check_no_large_files() {\n'
  printf '  _pc_skip_if_env no-large-files && return 0\n'
  printf '  local max_mb=%s\n' "$max_mb"
  cat <<'BODY'
  local max_bytes=$((max_mb * 1024 * 1024))
  if [ -z "$PC_STAGED_FILES" ]; then _pc_ok no-large-files; return 0; fi
  local file size found=0
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    size=$(git cat-file -s ":$file" 2>/dev/null || echo 0)
    if [ -n "$size" ] && [ "$size" -gt "$max_bytes" ]; then
      _pc_fail no-large-files "$file is $((size / 1024 / 1024))MB (limit ${max_mb}MB)"
      found=1
    fi
  done <<EOF_LF
$PC_STAGED_FILES
EOF_LF
  [ "$found" -eq 0 ] && _pc_ok no-large-files
}
_pc_check_no_large_files
BODY
  printf '# --- /check:no-large-files ---\n\n'
}

_hpc_emit_no_secrets() {
  cat <<'BLOCK'
# --- check:no-secrets ---
_pc_check_no_secrets() {
  _pc_skip_if_env no-secrets && return 0
  if [ -z "$PC_STAGED_FILES" ]; then _pc_ok no-secrets; return 0; fi
  local diff hits=""
  diff=$(git diff --cached -U0 2>/dev/null || true)
  # AWS access keys
  if printf '%s\n' "$diff" | grep -Eq '^\+.*AKIA[0-9A-Z]{16}'; then
    hits="$hits aws-access-key"
  fi
  # PEM private key headers (any kind)
  if printf '%s\n' "$diff" | grep -Eq '^\+.*-----BEGIN [A-Z ]*PRIVATE KEY-----'; then
    hits="$hits pem-private-key"
  fi
  # Common token / key env-var assignments with non-empty values
  if printf '%s\n' "$diff" | grep -Eq '^\+[[:space:]]*(AWS_SECRET_ACCESS_KEY|GITHUB_TOKEN|GITLAB_TOKEN|OPENAI_API_KEY|ANTHROPIC_API_KEY|SLACK_TOKEN|STRIPE_SECRET_KEY|NPM_TOKEN)[[:space:]]*=[[:space:]]*[^[:space:]\"'\'']'; then
    hits="$hits known-secret-env"
  fi
  if [ -n "$hits" ]; then
    _pc_fail no-secrets "potential secrets:$hits"
    return 0
  fi
  _pc_ok no-secrets
}
_pc_check_no_secrets
# --- /check:no-secrets ---

BLOCK
}

_hpc_emit_no_env_files() {
  local allowlist="$1"
  printf '# --- check:no-env-files ---\n'
  printf '_pc_check_no_env_files() {\n'
  printf '  _pc_skip_if_env no-env-files && return 0\n'
  printf '  local allow="%s"\n' "$allowlist"
  cat <<'BODY'
  if [ -z "$PC_STAGED_FILES" ]; then _pc_ok no-env-files; return 0; fi
  local file base found=0
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    base=$(basename "$file")
    case "$base" in
      .env|.env.*)
        local ok=0 a
        for a in $allow; do
          if [ "$base" = "$a" ] || [ "$file" = "$a" ]; then
            ok=1; break
          fi
        done
        if [ "$ok" -eq 0 ]; then
          _pc_fail no-env-files "$file is being staged (allowlist: $allow)"
          found=1
        fi
        ;;
    esac
  done <<EOF_ENV
$PC_STAGED_FILES
EOF_ENV
  [ "$found" -eq 0 ] && _pc_ok no-env-files
}
_pc_check_no_env_files
BODY
  printf '# --- /check:no-env-files ---\n\n'
}

_hpc_emit_no_trailing_whitespace() {
  cat <<'BLOCK'
# --- check:no-trailing-whitespace ---
_pc_check_no_trailing_whitespace() {
  _pc_skip_if_env no-trailing-whitespace && return 0
  if [ -z "$PC_STAGED_FILES" ]; then _pc_ok no-trailing-whitespace; return 0; fi
  local diff
  diff=$(git diff --cached -U0 2>/dev/null || true)
  if printf '%s\n' "$diff" | grep -Eq '^\+.*[[:space:]]+$'; then
    _pc_fail no-trailing-whitespace "trailing whitespace in staged additions"
    return 0
  fi
  _pc_ok no-trailing-whitespace
}
_pc_check_no_trailing_whitespace
# --- /check:no-trailing-whitespace ---

BLOCK
}

_hpc_emit_no_debug() {
  local stacks="$1"
  # Build a per-stack regex of debug patterns to look for in additions.
  local patterns=""
  local s
  for s in $stacks; do
    case "$s" in
      node)   patterns="$patterns|console\\.log|debugger;|console\\.debug" ;;
      python) patterns="$patterns|pdb\\.set_trace|breakpoint\\(|ipdb" ;;
      rust)   patterns="$patterns|dbg!|todo!\\(" ;;
      ruby)   patterns="$patterns|binding\\.pry|byebug" ;;
      php)    patterns="$patterns|var_dump\\(|dd\\(" ;;
    esac
  done
  if [[ -z "$patterns" ]]; then
    # Generic fallback when no specific stack — catch the universal suspects.
    patterns="console\\.log|debugger;|breakpoint\\(|pdb\\.set_trace|dbg!|dd\\(|var_dump\\(|binding\\.pry"
  else
    patterns="${patterns#|}"
  fi

  printf '# --- check:no-debug ---\n'
  printf '_pc_check_no_debug() {\n'
  printf '  _pc_skip_if_env no-debug && return 0\n'
  printf '  if [ -z "$PC_STAGED_FILES" ]; then _pc_ok no-debug; return 0; fi\n'
  printf '  local diff\n'
  printf '  diff=$(git diff --cached -U0 2>/dev/null || true)\n'
  printf '  if printf '\''%%s\\n'\'' "$diff" | grep -Eq '\''^\\+.*(%s)'\''; then\n' "$patterns"
  cat <<'BODY'
    _pc_fail no-debug "debug artefacts in staged additions"
    return 0
  fi
  _pc_ok no-debug
}
_pc_check_no_debug
BODY
  printf '# --- /check:no-debug ---\n\n'
}

# ---------------------------------------------------------------------------
# Stack-specific check emitters
# ---------------------------------------------------------------------------

_hpc_emit_node_lint() {
  cat <<'BLOCK'
# --- check:node-lint ---
_pc_check_node_lint() {
  _pc_skip_if_env node-lint && return 0
  if [ ! -f package.json ]; then _pc_skip node-lint "no package.json"; return 0; fi
  local pm
  if   [ -f bun.lockb ];          then pm=bun
  elif [ -f pnpm-lock.yaml ];     then pm=pnpm
  elif [ -f yarn.lock ];          then pm=yarn
  else                                  pm=npm
  fi
  if ! command -v "$pm" >/dev/null 2>&1; then
    _pc_skip node-lint "$pm not installed"; return 0
  fi
  # Only run if the project defines a lint script.
  if ! grep -Eq '"lint"[[:space:]]*:' package.json; then
    _pc_skip node-lint "no \"lint\" script in package.json"
    return 0
  fi
  case "$pm" in
    npm)  "$pm" run --silent lint  >/dev/null 2>&1 ;;
    bun)  "$pm" run lint           >/dev/null 2>&1 ;;
    *)    "$pm" run lint           >/dev/null 2>&1 ;;
  esac
  if [ $? -ne 0 ]; then
    _pc_fail node-lint "$pm run lint failed"
  else
    _pc_ok node-lint
  fi
}
_pc_check_node_lint
# --- /check:node-lint ---

BLOCK
}

_hpc_emit_node_format() {
  cat <<'BLOCK'
# --- check:node-format ---
_pc_check_node_format() {
  _pc_skip_if_env node-format && return 0
  local staged
  staged=$(_pc_filtered '\.(js|jsx|ts|tsx|mjs|cjs|json|css|scss|md)$')
  if [ -z "$staged" ]; then _pc_skip node-format "no JS/TS/CSS/MD staged"; return 0; fi
  if ! command -v npx >/dev/null 2>&1; then
    _pc_skip node-format "npx not installed"; return 0
  fi
  if ! npx --no-install prettier --version >/dev/null 2>&1; then
    _pc_skip node-format "prettier not installed (run \`npm i -D prettier\`)"
    return 0
  fi
  if ! printf '%s\n' "$staged" | xargs npx --no-install prettier --check >/dev/null 2>&1; then
    _pc_fail node-format "prettier --check failed (run \`npx prettier --write\` to fix)"
  else
    _pc_ok node-format
  fi
}
_pc_check_node_format
# --- /check:node-format ---

BLOCK
}

_hpc_emit_node_test() {
  cat <<'BLOCK'
# --- check:node-test ---
_pc_check_node_test() {
  _pc_skip_if_env node-test && return 0
  if [ ! -f package.json ]; then _pc_skip node-test "no package.json"; return 0; fi
  if ! grep -Eq '"test"[[:space:]]*:' package.json; then
    _pc_skip node-test "no \"test\" script in package.json"
    return 0
  fi
  local pm
  if   [ -f bun.lockb ];          then pm=bun
  elif [ -f pnpm-lock.yaml ];     then pm=pnpm
  elif [ -f yarn.lock ];          then pm=yarn
  else                                  pm=npm
  fi
  if ! command -v "$pm" >/dev/null 2>&1; then
    _pc_skip node-test "$pm not installed"; return 0
  fi
  if ! "$pm" test --silent >/dev/null 2>&1; then
    _pc_fail node-test "$pm test failed"
  else
    _pc_ok node-test
  fi
}
_pc_check_node_test
# --- /check:node-test ---

BLOCK
}

_hpc_emit_node_typecheck() {
  cat <<'BLOCK'
# --- check:node-typecheck ---
_pc_check_node_typecheck() {
  _pc_skip_if_env node-typecheck && return 0
  if [ ! -f tsconfig.json ]; then _pc_skip node-typecheck "no tsconfig.json"; return 0; fi
  if ! command -v npx >/dev/null 2>&1; then
    _pc_skip node-typecheck "npx not installed"; return 0
  fi
  if ! npx --no-install tsc --noEmit >/dev/null 2>&1; then
    _pc_fail node-typecheck "tsc --noEmit failed"
  else
    _pc_ok node-typecheck
  fi
}
_pc_check_node_typecheck
# --- /check:node-typecheck ---

BLOCK
}

_hpc_emit_py_ruff() {
  cat <<'BLOCK'
# --- check:py-ruff ---
_pc_check_py_ruff() {
  _pc_skip_if_env py-ruff && return 0
  local staged
  staged=$(_pc_filtered '\.py$')
  if [ -z "$staged" ]; then _pc_skip py-ruff "no .py staged"; return 0; fi
  if ! command -v ruff >/dev/null 2>&1; then
    _pc_skip py-ruff "ruff not installed (\`pip install ruff\`)"
    return 0
  fi
  if ! printf '%s\n' "$staged" | xargs ruff check >/dev/null 2>&1; then
    _pc_fail py-ruff "ruff check failed"
  else
    _pc_ok py-ruff
  fi
}
_pc_check_py_ruff
# --- /check:py-ruff ---

BLOCK
}

_hpc_emit_py_format() {
  cat <<'BLOCK'
# --- check:py-format ---
_pc_check_py_format() {
  _pc_skip_if_env py-format && return 0
  local staged
  staged=$(_pc_filtered '\.py$')
  if [ -z "$staged" ]; then _pc_skip py-format "no .py staged"; return 0; fi
  if command -v ruff >/dev/null 2>&1; then
    if ! printf '%s\n' "$staged" | xargs ruff format --check >/dev/null 2>&1; then
      _pc_fail py-format "ruff format --check failed"
    else
      _pc_ok py-format
    fi
  elif command -v black >/dev/null 2>&1; then
    if ! printf '%s\n' "$staged" | xargs black --check --quiet >/dev/null 2>&1; then
      _pc_fail py-format "black --check failed"
    else
      _pc_ok py-format
    fi
  else
    _pc_skip py-format "neither ruff nor black installed"
  fi
}
_pc_check_py_format
# --- /check:py-format ---

BLOCK
}

_hpc_emit_py_mypy() {
  cat <<'BLOCK'
# --- check:py-mypy ---
_pc_check_py_mypy() {
  _pc_skip_if_env py-mypy && return 0
  local staged
  staged=$(_pc_filtered '\.py$')
  if [ -z "$staged" ]; then _pc_skip py-mypy "no .py staged"; return 0; fi
  if ! command -v mypy >/dev/null 2>&1; then
    _pc_skip py-mypy "mypy not installed"; return 0
  fi
  if ! printf '%s\n' "$staged" | xargs mypy >/dev/null 2>&1; then
    _pc_fail py-mypy "mypy failed"
  else
    _pc_ok py-mypy
  fi
}
_pc_check_py_mypy
# --- /check:py-mypy ---

BLOCK
}

_hpc_emit_py_pytest() {
  cat <<'BLOCK'
# --- check:py-pytest ---
_pc_check_py_pytest() {
  _pc_skip_if_env py-pytest && return 0
  if ! command -v pytest >/dev/null 2>&1; then
    _pc_skip py-pytest "pytest not installed"; return 0
  fi
  if ! pytest -q >/dev/null 2>&1; then
    _pc_fail py-pytest "pytest failed"
  else
    _pc_ok py-pytest
  fi
}
_pc_check_py_pytest
# --- /check:py-pytest ---

BLOCK
}

_hpc_emit_rust_fmt() {
  cat <<'BLOCK'
# --- check:rust-fmt ---
_pc_check_rust_fmt() {
  _pc_skip_if_env rust-fmt && return 0
  if ! command -v cargo >/dev/null 2>&1; then
    _pc_skip rust-fmt "cargo not installed"; return 0
  fi
  if ! cargo fmt --all -- --check >/dev/null 2>&1; then
    _pc_fail rust-fmt "cargo fmt --check failed (run \`cargo fmt\` to fix)"
  else
    _pc_ok rust-fmt
  fi
}
_pc_check_rust_fmt
# --- /check:rust-fmt ---

BLOCK
}

_hpc_emit_rust_clippy() {
  cat <<'BLOCK'
# --- check:rust-clippy ---
_pc_check_rust_clippy() {
  _pc_skip_if_env rust-clippy && return 0
  if ! command -v cargo >/dev/null 2>&1; then
    _pc_skip rust-clippy "cargo not installed"; return 0
  fi
  if ! cargo clippy --quiet -- -D warnings >/dev/null 2>&1; then
    _pc_fail rust-clippy "cargo clippy failed"
  else
    _pc_ok rust-clippy
  fi
}
_pc_check_rust_clippy
# --- /check:rust-clippy ---

BLOCK
}

_hpc_emit_rust_test() {
  cat <<'BLOCK'
# --- check:rust-test ---
_pc_check_rust_test() {
  _pc_skip_if_env rust-test && return 0
  if ! command -v cargo >/dev/null 2>&1; then
    _pc_skip rust-test "cargo not installed"; return 0
  fi
  if ! cargo test --quiet >/dev/null 2>&1; then
    _pc_fail rust-test "cargo test failed"
  else
    _pc_ok rust-test
  fi
}
_pc_check_rust_test
# --- /check:rust-test ---

BLOCK
}

_hpc_emit_go_fmt() {
  cat <<'BLOCK'
# --- check:go-fmt ---
_pc_check_go_fmt() {
  _pc_skip_if_env go-fmt && return 0
  if ! command -v gofmt >/dev/null 2>&1; then
    _pc_skip go-fmt "gofmt not installed"; return 0
  fi
  local staged
  staged=$(_pc_filtered '\.go$')
  if [ -z "$staged" ]; then _pc_skip go-fmt "no .go staged"; return 0; fi
  local out
  out=$(printf '%s\n' "$staged" | xargs gofmt -l 2>/dev/null || true)
  if [ -n "$out" ]; then
    _pc_fail go-fmt "needs formatting: $(printf '%s' "$out" | tr '\n' ' ')"
  else
    _pc_ok go-fmt
  fi
}
_pc_check_go_fmt
# --- /check:go-fmt ---

BLOCK
}

_hpc_emit_go_vet() {
  cat <<'BLOCK'
# --- check:go-vet ---
_pc_check_go_vet() {
  _pc_skip_if_env go-vet && return 0
  if ! command -v go >/dev/null 2>&1; then
    _pc_skip go-vet "go not installed"; return 0
  fi
  if ! go vet ./... >/dev/null 2>&1; then
    _pc_fail go-vet "go vet failed"
  else
    _pc_ok go-vet
  fi
}
_pc_check_go_vet
# --- /check:go-vet ---

BLOCK
}

_hpc_emit_go_test() {
  cat <<'BLOCK'
# --- check:go-test ---
_pc_check_go_test() {
  _pc_skip_if_env go-test && return 0
  if ! command -v go >/dev/null 2>&1; then
    _pc_skip go-test "go not installed"; return 0
  fi
  if ! go test ./... >/dev/null 2>&1; then
    _pc_fail go-test "go test failed"
  else
    _pc_ok go-test
  fi
}
_pc_check_go_test
# --- /check:go-test ---

BLOCK
}

_hpc_emit_java_maven() {
  cat <<'BLOCK'
# --- check:java-maven ---
_pc_check_java_maven() {
  _pc_skip_if_env java-maven && return 0
  if ! command -v mvn >/dev/null 2>&1; then
    _pc_skip java-maven "mvn not installed"; return 0
  fi
  if ! mvn -q verify >/dev/null 2>&1; then
    _pc_fail java-maven "mvn verify failed"
  else
    _pc_ok java-maven
  fi
}
_pc_check_java_maven
# --- /check:java-maven ---

BLOCK
}

_hpc_emit_java_gradle() {
  cat <<'BLOCK'
# --- check:java-gradle ---
_pc_check_java_gradle() {
  _pc_skip_if_env java-gradle && return 0
  local gradle
  if   [ -x ./gradlew ];                 then gradle=./gradlew
  elif command -v gradle >/dev/null 2>&1; then gradle=gradle
  else _pc_skip java-gradle "gradle not installed"; return 0
  fi
  if ! "$gradle" -q check >/dev/null 2>&1; then
    _pc_fail java-gradle "gradle check failed"
  else
    _pc_ok java-gradle
  fi
}
_pc_check_java_gradle
# --- /check:java-gradle ---

BLOCK
}

_hpc_emit_ruby_rspec() {
  cat <<'BLOCK'
# --- check:ruby-rspec ---
_pc_check_ruby_rspec() {
  _pc_skip_if_env ruby-rspec && return 0
  if ! command -v bundle >/dev/null 2>&1; then
    _pc_skip ruby-rspec "bundler not installed"; return 0
  fi
  if ! bundle exec rspec --format progress >/dev/null 2>&1; then
    _pc_fail ruby-rspec "bundle exec rspec failed"
  else
    _pc_ok ruby-rspec
  fi
}
_pc_check_ruby_rspec
# --- /check:ruby-rspec ---

BLOCK
}

_hpc_emit_php_composer_test() {
  cat <<'BLOCK'
# --- check:php-composer-test ---
_pc_check_php_composer_test() {
  _pc_skip_if_env php-composer-test && return 0
  if ! command -v composer >/dev/null 2>&1; then
    _pc_skip php-composer-test "composer not installed"; return 0
  fi
  if ! composer test >/dev/null 2>&1; then
    _pc_fail php-composer-test "composer test failed"
  else
    _pc_ok php-composer-test
  fi
}
_pc_check_php_composer_test
# --- /check:php-composer-test ---

BLOCK
}

# ---------------------------------------------------------------------------
# Custom-command emitter — wraps a user-entered command in a labelled block.
# Single-quote-escapes the command body so embedded single quotes survive.
# ---------------------------------------------------------------------------
_hpc_emit_custom_block() {
  local idx="$1" cmd="$2"
  local id="custom-$idx"

  # Single-quote-escape `cmd` so we can embed it inside `bash -c '<here>'`.
  # Each apostrophe in cmd is replaced by the four-character sequence  ' \ ' '
  # which closes the outer string, emits a literal apostrophe, and reopens.
  local q sq escaped
  q=\'
  sq="${q}\\${q}${q}"
  escaped="${cmd//${q}/${sq}}"

  # Build a short, quote-stripped tag for the failure message.
  local tag="${cmd//\"/}"
  tag="${tag:0:60}"

  printf '# --- check:%s ---\n' "$id"
  printf '_pc_check_%s() {\n' "custom_$idx"
  printf '  _pc_skip_if_env %s && return 0\n' "$id"
  printf '  if bash -c %s%s%s >/dev/null 2>&1; then\n' "$q" "$escaped" "$q"
  printf '    _pc_ok %s\n' "$id"
  printf '  else\n'
  printf '    _pc_fail %s "custom command failed: %s"\n' "$id" "$tag"
  printf '  fi\n'
  printf '}\n'
  printf '_pc_check_%s\n' "custom_$idx"
  printf '# --- /check:%s ---\n\n' "$id"
}

# ---------------------------------------------------------------------------
# Dispatcher: emit a check by ID.
# ---------------------------------------------------------------------------
# Arguments after the ID are check-specific config:
#   protect-branches: branches string
#   no-large-files:   max MB
#   no-env-files:     allowlist string
#   no-debug:         stacks string
# All other IDs ignore extra args.
_hpc_emit_check_by_id() {
  local id="$1"
  shift
  case "$id" in
    protect-branches)       _hpc_emit_protect_branches "$1" ;;
    no-merge-markers)       _hpc_emit_no_merge_markers ;;
    no-large-files)         _hpc_emit_no_large_files "$1" ;;
    no-secrets)             _hpc_emit_no_secrets ;;
    no-env-files)           _hpc_emit_no_env_files "$1" ;;
    no-trailing-whitespace) _hpc_emit_no_trailing_whitespace ;;
    no-debug)               _hpc_emit_no_debug "$1" ;;

    node-lint)              _hpc_emit_node_lint ;;
    node-format)            _hpc_emit_node_format ;;
    node-test)              _hpc_emit_node_test ;;
    node-typecheck)         _hpc_emit_node_typecheck ;;

    py-ruff)                _hpc_emit_py_ruff ;;
    py-format)              _hpc_emit_py_format ;;
    py-mypy)                _hpc_emit_py_mypy ;;
    py-pytest)              _hpc_emit_py_pytest ;;

    rust-fmt)               _hpc_emit_rust_fmt ;;
    rust-clippy)            _hpc_emit_rust_clippy ;;
    rust-test)              _hpc_emit_rust_test ;;

    go-fmt)                 _hpc_emit_go_fmt ;;
    go-vet)                 _hpc_emit_go_vet ;;
    go-test)                _hpc_emit_go_test ;;

    java-maven)             _hpc_emit_java_maven ;;
    java-gradle)            _hpc_emit_java_gradle ;;

    ruby-rspec)             _hpc_emit_ruby_rspec ;;
    php-composer-test)      _hpc_emit_php_composer_test ;;

    *) ;;  # unknown ID — silently ignore (already validated upstream)
  esac
}

# ---------------------------------------------------------------------------
# Render & install
# ---------------------------------------------------------------------------

# Print the full managed block (markers + body) on stdout.
# Args:
#   $1 = space-separated stack list
#   $2 = space-separated selected check IDs
#   $3 = protected branches string
#   $4 = max file size MB
#   $5 = env allowlist string
#   $6 = path to a file containing custom commands (one per line)
_hpc_render_managed_block() {
  local stacks="$1"
  local check_ids="$2"
  local branches="$3"
  local max_mb="$4"
  local env_allow="$5"
  local custom_file="$6"

  # Build comma-separated form for the header comment.
  local csv="${check_ids// /,}"
  csv="${csv#,}"
  csv="${csv%,}"

  # Count custom commands so they show up in the header.
  # `grep -c` exits non-zero when there are 0 matches; the || branch
  # would then ALSO print a "0" line, so we use `|| true` to suppress
  # the duplicate and keep a single clean number.
  local custom_count=0
  if [[ -s "$custom_file" ]]; then
    custom_count=$(grep -c . "$custom_file" 2>/dev/null || true)
    custom_count="${custom_count:-0}"
  fi
  if [[ -n "$csv" && "$custom_count" -gt 0 ]]; then
    csv="${csv},$(seq 1 "$custom_count" | sed 's/^/custom-/' | tr '\n' ',' | sed 's/,$//')"
  elif [[ "$custom_count" -gt 0 ]]; then
    csv="$(seq 1 "$custom_count" | sed 's/^/custom-/' | tr '\n' ',' | sed 's/,$//')"
  fi

  _hpc_emit_preamble "$stacks" "$csv"

  local id
  for id in $check_ids; do
    case "$id" in
      protect-branches) _hpc_emit_check_by_id "$id" "$branches" ;;
      no-large-files)   _hpc_emit_check_by_id "$id" "$max_mb" ;;
      no-env-files)     _hpc_emit_check_by_id "$id" "$env_allow" ;;
      no-debug)         _hpc_emit_check_by_id "$id" "$stacks" ;;
      *)                _hpc_emit_check_by_id "$id" ;;
    esac
  done

  # Append custom command blocks.
  if [[ -f "$custom_file" ]] && [[ -s "$custom_file" ]]; then
    local idx=0 cmd
    while IFS= read -r cmd; do
      [[ -z "$cmd" ]] && continue
      idx=$((idx + 1))
      _hpc_emit_custom_block "$idx" "$cmd"
    done < "$custom_file"
  fi

  _hpc_emit_trailer
}

# Install a freshly rendered managed block at the hook path. Handles four
# cases:
#   (a) no existing hook — write a brand-new file with shebang + block.
#   (b) existing managed hook — splice: strip old block, append new.
#   (c) existing unmanaged hook — back up, replace with shebang + block.
#   (d) existing hook is the bare default git sample — treat as (c).
# All branches produce a `chmod 755` final file.
_hpc_install_hook() {
  local block_file="$1"   # path to the freshly rendered managed block
  local hook
  hook=$(_hpc_hook_path) || return 1
  mkdir -p "$(dirname "$hook")"

  if [[ ! -f "$hook" ]]; then
    # Case (a) — brand new.
    {
      printf '#!/usr/bin/env bash\n'
      cat "$block_file"
    } > "$hook"
    chmod 755 "$hook"
    success "Wrote $hook"
    return 0
  fi

  if grep -Fq "$HPC_MARK_BEGIN" "$hook"; then
    # Case (b) — splice in place.
    local tmp
    tmp=$(mktemp)
    awk -v b="$HPC_MARK_BEGIN" -v e="$HPC_MARK_END" '
      $0 == b { skip=1; next }
      $0 == e { skip=0; next }
      !skip   { print }
    ' "$hook" > "$tmp"
    # Ensure trailing newline before appending so we don't glue lines.
    if [[ -s "$tmp" ]] && [[ -n "$(tail -c1 "$tmp")" ]]; then
      printf '\n' >> "$tmp"
    fi
    cat "$block_file" >> "$tmp"
    mv "$tmp" "$hook"
    chmod 755 "$hook"
    success "Updated managed block in $hook"
    return 0
  fi

  # Case (c) — back up & replace.
  local stamp backup
  stamp=$(date -u +%Y%m%dT%H%M%SZ)
  backup="${hook}.bak.${stamp}"
  cp "$hook" "$backup"
  {
    printf '#!/usr/bin/env bash\n'
    cat "$block_file"
  } > "$hook"
  chmod 755 "$hook"
  success "Wrote $hook"
  info "Original hook backed up to: $backup"
  return 0
}

# ---------------------------------------------------------------------------
# Subcommand entry points
# ---------------------------------------------------------------------------

hanif_pre_commit_setup() {
  _hpc_require_git_repo || return 1

  print_banner "Pre-Commit Hook Setup"
  echo ""

  local root
  root=$(_hpc_repo_root)
  kv "Repo" "$root"

  local stacks
  stacks=$(_hpc_detect_stacks)
  if [[ -n "$stacks" ]]; then
    local labels="" s
    for s in $stacks; do
      labels="$labels$(_hpc_stack_label "$s"), "
    done
    labels="${labels%, }"
    kv "Detected" "$labels"
  else
    kv "Detected" "(no stack markers found — universal checks only)"
  fi

  _hpc_warn_if_custom_hooks_path

  # Build the catalog into a temp file (so the picker can iterate it twice).
  local catalog
  catalog=$(mktemp)
  _hpc_catalog_full "$stacks" > "$catalog"

  local selected
  selected=$(_hpc_select_checks "$catalog" "$stacks")
  rm -f "$catalog"

  # Conditional config prompts.
  local branches="${HANIF_PRE_COMMIT_PROTECTED_BRANCHES:-main master}"
  local max_mb="${HANIF_PRE_COMMIT_MAX_FILE_MB:-5}"
  local env_allow="${HANIF_PRE_COMMIT_ENV_ALLOWLIST:-.env.example .env.sample}"

  if echo " $selected " | grep -q ' protect-branches '; then
    _hpc_prompt "Branches to protect (space-separated)" \
      "$branches" \
      _hpc_valid_branches \
      "Tokens must match ^[A-Za-z0-9._/-]+\$"
    branches="$_HPC_PROMPT_VALUE"
  fi
  if echo " $selected " | grep -q ' no-large-files '; then
    _hpc_prompt "Max file size (MB)" \
      "$max_mb" \
      _hpc_valid_mb \
      "Must be a positive integer (1..1024)."
    max_mb="$_HPC_PROMPT_VALUE"
  fi
  if echo " $selected " | grep -q ' no-env-files '; then
    _hpc_prompt "Allowed .env-style filenames (space-separated)" \
      "$env_allow" \
      _hpc_valid_env_allowlist \
      "Tokens must match ^[A-Za-z0-9._/-]+\$"
    env_allow="$_HPC_PROMPT_VALUE"
  fi

  # Custom commands.
  local custom_file
  custom_file=$(mktemp)
  _hpc_collect_custom_commands > "$custom_file"

  # Review.
  echo ""
  print_banner "Review"
  echo ""
  kv "Checks"  "${selected:-(none)}"
  if echo " $selected " | grep -q ' protect-branches '; then
    kv "Protected" "$branches"
  fi
  if echo " $selected " | grep -q ' no-large-files '; then
    kv "Max size" "${max_mb} MB"
  fi
  if echo " $selected " | grep -q ' no-env-files '; then
    kv "Env allow" "$env_allow"
  fi
  local custom_count=0
  if [[ -s "$custom_file" ]]; then
    custom_count=$(grep -c . "$custom_file" 2>/dev/null || true)
    custom_count="${custom_count:-0}"
  fi
  if [[ "$custom_count" -gt 0 ]]; then
    kv "Custom" "$custom_count command(s)"
  fi
  echo ""

  if [[ -z "$selected" && "$custom_count" -eq 0 ]]; then
    warning "No checks selected and no custom commands provided — nothing to install."
    rm -f "$custom_file"
    return 0
  fi

  if ! _hpc_confirm "Install pre-commit hook?"; then
    info "Aborted — no changes written."
    rm -f "$custom_file"
    return 0
  fi

  # Render & install.
  local block_file
  block_file=$(mktemp)
  _hpc_render_managed_block "$stacks" "$selected" "$branches" "$max_mb" "$env_allow" "$custom_file" > "$block_file"
  _hpc_install_hook "$block_file"
  local rc=$?
  rm -f "$block_file" "$custom_file"

  if [[ $rc -eq 0 ]]; then
    echo ""
    hint "Try it now:   hanif pre-commit run"
    hint "Skip later:   HANIF_PRECOMMIT_SKIP=<id> git commit ..."
  fi
  return $rc
}

hanif_pre_commit_list() {
  _hpc_require_git_repo || return 1

  local hook
  hook=$(_hpc_hook_path) || return 1

  print_banner "Pre-Commit Hook Status"
  echo ""
  kv "Path" "$hook"

  if [[ ! -f "$hook" ]]; then
    kv "Status" "not installed"
    return 0
  fi

  if ! grep -Fq "$HPC_MARK_BEGIN" "$hook"; then
    kv "Status" "exists, NOT managed by hanif"
    hint "  Re-run \`hanif pre-commit\` to take over — the existing file"
    hint "  will be backed up to <hook>.bak.<timestamp>."
    return 0
  fi

  kv "Status" "managed"

  # `|| true` keeps these resilient if the marker comments are ever
  # missing — without it, `set -o pipefail` would propagate grep's
  # non-zero exit and trip `set -e` in the calling shell.
  local generated="" stacks="" checks=""
  generated=$(grep -m1 '^# Generated:'        "$hook" 2>/dev/null | sed 's/^# Generated: //'        || true)
  stacks=$(   grep -m1 '^# Detected stacks:'  "$hook" 2>/dev/null | sed 's/^# Detected stacks: //'  || true)
  checks=$(   grep -m1 '^# Selected checks:'  "$hook" 2>/dev/null | sed 's/^# Selected checks: //'  || true)

  [[ -n "$generated" ]] && kv "Generated" "$generated"
  [[ -n "$stacks"    ]] && kv "Stacks"    "$stacks"
  [[ -n "$checks"    ]] && kv "Checks"    "$checks"

  # Permissions
  local perm
  perm=$(stat -c '%a' "$hook" 2>/dev/null || stat -f '%Lp' "$hook" 2>/dev/null || echo "?")
  kv "Mode" "$perm"
}

hanif_pre_commit_remove() {
  _hpc_require_git_repo || return 1

  local hook
  hook=$(_hpc_hook_path) || return 1

  if [[ ! -f "$hook" ]]; then
    error "No pre-commit hook to remove at $hook"
    return 1
  fi

  if ! _hpc_confirm "Remove pre-commit hook at $hook?"; then
    info "Aborted."
    return 0
  fi

  local stamp backup
  stamp=$(date -u +%Y%m%dT%H%M%SZ)
  backup="${hook}.bak.${stamp}"
  cp "$hook" "$backup"

  if ! grep -Fq "$HPC_MARK_BEGIN" "$hook"; then
    # Unmanaged file — just remove it (after the backup we already made).
    rm -f "$hook"
    success "Removed $hook (backup: $backup)"
    return 0
  fi

  # Strip the managed block. If what remains is just the shebang (or
  # nothing meaningful), remove the file entirely.
  local tmp
  tmp=$(mktemp)
  awk -v b="$HPC_MARK_BEGIN" -v e="$HPC_MARK_END" '
    $0 == b { skip=1; next }
    $0 == e { skip=0; next }
    !skip   { print }
  ' "$hook" > "$tmp"

  # Determine whether anything meaningful remains. Pure-shell loop —
  # avoids `grep | head` whose exit status under `set -o pipefail`
  # would trip `set -e` in the parent.
  local has_content=0 ln
  while IFS= read -r ln || [[ -n "$ln" ]]; do
    case "$ln" in
      ""|'#!'*) ;;
      *) has_content=1; break ;;
    esac
  done < "$tmp"

  if [[ "$has_content" -eq 0 ]]; then
    rm -f "$hook" "$tmp"
    success "Removed $hook (backup: $backup)"
  else
    mv "$tmp" "$hook"
    chmod 755 "$hook"
    success "Stripped managed block from $hook (backup: $backup)"
    info "User content outside the markers was preserved."
  fi
}

hanif_pre_commit_run() {
  _hpc_require_git_repo || return 1

  local hook root
  hook=$(_hpc_hook_path) || return 1
  root=$(_hpc_repo_root)

  if [[ ! -f "$hook" ]]; then
    error "No pre-commit hook installed at $hook"
    hint "  Install one with:  hanif pre-commit"
    return 1
  fi

  if [[ ! -x "$hook" ]]; then
    warning "Hook is not executable — fixing mode (chmod 755)."
    chmod 755 "$hook"
  fi

  (cd "$root" && bash "$hook")
}
