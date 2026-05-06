#!/usr/bin/env bash
#
# Common utility functions for Hanif CLI.
#
# Sourced by ``bin/hanif`` at startup. Keep this file lean — only utilities
# that are used in two or more places belong here.

# Color codes (only set if not already defined to allow re-sourcing).
#
# Colors are disabled automatically when:
#   - The relevant stream (stdout for most helpers, stderr for ``error``) is
#     not a TTY (so piped/captured output stays clean for tests and scripts).
#   - The ``NO_COLOR`` environment variable is set (https://no-color.org/).
#   - ``HANIF_NO_COLOR`` is set (escape hatch for our own callers).
if [[ -z "${HANIF_COLORS_DEFINED:-}" ]]; then
  if [[ -z "${NO_COLOR:-}" && -z "${HANIF_NO_COLOR:-}" ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly CYAN='\033[0;36m'
    readonly MAGENTA='\033[0;35m'
    readonly GRAY='\033[0;90m'
    readonly BOLD='\033[1m'
    readonly DIM='\033[2m'
    readonly NC='\033[0m' # Reset
  else
    readonly RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA=''
    readonly GRAY='' BOLD='' DIM='' NC=''
  fi
  readonly HANIF_COLORS_DEFINED=1
fi

# Strip color codes when the target stream is not a TTY. Returns the original
# string when colors should be shown, or a stripped copy when they shouldn't.
#   $1 = fd (1 for stdout, 2 for stderr)
#   $2 = string to render
_hanif_render() {
  local fd="$1"
  local s="$2"
  if [[ -n "${NO_COLOR:-}" || -n "${HANIF_NO_COLOR:-}" ]] || [[ ! -t "$fd" ]]; then
    # Use sed to strip ANSI CSI sequences. Bash parameter expansion can't
    # easily match this multi-character escape pattern (\033[...m), so sed
    # is the clearest tool here.
    # shellcheck disable=SC2001
    printf '%b' "$s" | sed $'s/\033\\[[0-9;]*m//g'
  else
    printf '%b' "$s"
  fi
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
info()    { _hanif_render 1 "${BLUE}ℹ${NC}  $*"; printf '\n'; }
success() { _hanif_render 1 "${GREEN}✓${NC}  $*"; printf '\n'; }
warning() { _hanif_render 1 "${YELLOW}⚠${NC}  $*"; printf '\n'; }
error()   { _hanif_render 2 "${RED}✗${NC}  $*" >&2; printf '\n' >&2; }

# Print a numbered/labelled step. Useful inside multi-stage commands.
#   step "Fetching" "from origin"
step()    { _hanif_render 1 "${CYAN}→${NC}  ${BOLD}$1${NC}${2:+ $2}"; printf '\n'; }

# Print a faint hint line (e.g. "Tip: …" or contextual guidance).
hint()    { _hanif_render 1 "${DIM}$*${NC}"; printf '\n'; }

# Print a colored boxed banner. Width is fixed at 47 chars to match the
# existing aesthetic of the help screens.
#   print_banner "Hanif CLI v${VERSION}"
print_banner() {
  local title="$1"
  local width=47
  local pad=$(( width - ${#title} ))
  (( pad < 0 )) && pad=0
  local left=$(( pad / 2 ))
  local right=$(( pad - left ))
  local lpad rpad
  lpad=$(printf '%*s' "$left" '')
  rpad=$(printf '%*s' "$right" '')
  local bar
  bar=$(printf '─%.0s' $(seq 1 $width))
  _hanif_render 1 "${CYAN}┌${bar}┐${NC}"; printf '\n'
  _hanif_render 1 "${CYAN}│${NC}${lpad}${BOLD}${title}${NC}${rpad}${CYAN}│${NC}"; printf '\n'
  _hanif_render 1 "${CYAN}└${bar}┘${NC}"; printf '\n'
}

# Aligned key/value printer.
#   kv "Profile" "~/.zshrc"   →  Profile  ~/.zshrc
# The key is dim+bold so the value is what your eye lands on.
#   $1 = key (label)
#   $2 = value
#   $3 = optional padding width for the key column (default 14)
kv() {
  local key="$1" value="$2" pad="${3:-14}"
  _hanif_render 1 "  ${BOLD}${CYAN}$(printf '%-*s' "$pad" "$key")${NC}  ${value}"
  printf '\n'
}

# Render a tabular view from tab-separated rows on stdin.
#
# The first argument is a pipe-separated list of header labels; subsequent
# rows are read from stdin as TAB-separated values. Column widths are
# auto-sized to the widest cell. Output uses light box-drawing characters
# and is colorized (cyan borders, bold headers) when stdout is a TTY.
#
# Usage:
#   {
#     printf '%s\t%s\n' FOO "bar"
#     printf '%s\t%s\n' BAZ "qux"
#   } | render_table "KEY|VALUE"
#
# Notes:
#   - Cells must not contain raw TAB or newline characters.
#   - ANSI escape sequences in cell values are NOT supported (they would
#     throw off the width calculation). Pass plain strings only.
render_table() {
  local header_spec="${1:-}"
  if [[ -z "$header_spec" ]]; then
    error "render_table: header spec is required"
    return 1
  fi

  # Parse headers (pipe-separated).
  local -a headers=()
  local IFS='|'
  read -r -a headers <<< "$header_spec"
  IFS=$' \t\n'
  local ncols=${#headers[@]}

  # Read all rows into memory so we can size columns.
  local -a rows=()
  local line
  while IFS= read -r line; do
    rows+=("$line")
  done

  # Initialize widths from header lengths.
  local -a widths=()
  local i
  for ((i = 0; i < ncols; i++)); do
    widths[i]=${#headers[i]}
  done

  # Expand widths to fit data.
  local row col_idx
  local -a cells
  for row in "${rows[@]}"; do
    IFS=$'\t' read -r -a cells <<< "$row"
    for ((i = 0; i < ncols; i++)); do
      local cell="${cells[i]:-}"
      (( ${#cell} > widths[i] )) && widths[i]=${#cell}
    done
  done

  # Build separator: ┌──┬──┐, ├──┼──┤, └──┴──┘
  local sep_top sep_mid sep_bot
  sep_top="${CYAN}┌"; sep_mid="${CYAN}├"; sep_bot="${CYAN}└"
  for ((i = 0; i < ncols; i++)); do
    local bar
    bar=$(printf '─%.0s' $(seq 1 $((widths[i] + 2))))
    sep_top+="${bar}"
    sep_mid+="${bar}"
    sep_bot+="${bar}"
    if (( i < ncols - 1 )); then
      sep_top+="┬"; sep_mid+="┼"; sep_bot+="┴"
    else
      sep_top+="┐${NC}"; sep_mid+="┤${NC}"; sep_bot+="┘${NC}"
    fi
  done

  # Header row.
  _hanif_render 1 "$sep_top"; printf '\n'
  local line_str="${CYAN}│${NC}"
  for ((i = 0; i < ncols; i++)); do
    line_str+=" ${BOLD}$(printf '%-*s' "${widths[i]}" "${headers[i]}")${NC} ${CYAN}│${NC}"
  done
  _hanif_render 1 "$line_str"; printf '\n'
  _hanif_render 1 "$sep_mid"; printf '\n'

  # Data rows.
  for row in "${rows[@]}"; do
    IFS=$'\t' read -r -a cells <<< "$row"
    line_str="${CYAN}│${NC}"
    for ((i = 0; i < ncols; i++)); do
      local cell="${cells[i]:-}"
      line_str+=" $(printf '%-*s' "${widths[i]}" "$cell") ${CYAN}│${NC}"
    done
    _hanif_render 1 "$line_str"; printf '\n'
  done

  _hanif_render 1 "$sep_bot"; printf '\n'
}

# ---------------------------------------------------------------------------
# Environment helpers
# ---------------------------------------------------------------------------

# Check if a command exists on PATH.
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check whether the current directory is inside a git repository.
is_git_repo() {
  git rev-parse --git-dir >/dev/null 2>&1
}

# Print the current git branch name (or empty string).
get_current_branch() {
  git rev-parse --abbrev-ref HEAD 2>/dev/null
}

# Check whether a local branch exists.
branch_exists() {
  local branch="$1"
  git show-ref --verify --quiet "refs/heads/$branch"
}

# Confirm an action interactively. Returns 0 for yes, 1 for no.
confirm() {
  local prompt="${1:-Are you sure?}"
  local response
  local prompt_str
  prompt_str=$(_hanif_render 1 "${YELLOW}?${NC}  ${prompt} ${DIM}[y/N]${NC}: ")
  read -r -p "$prompt_str" response
  case "$response" in
    [yY][eE][sS]|[yY]) return 0 ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------

# Warn if git is missing or older than the recommended minimum.
check_git_version() {
  if ! command_exists git; then
    error "Git is not installed"
    return 1
  fi

  local min_version="2.0.0"
  local git_version
  git_version=$(git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)

  # Simple version comparison (good enough for major.minor.patch).
  if [[ "$(printf '%s\n' "$min_version" "$git_version" | sort -V | head -n1)" != "$min_version" ]]; then
    warning "Git version $git_version detected. Recommended: $min_version or higher"
  fi
}

# ---------------------------------------------------------------------------
# Git/branch name sanitization
# ---------------------------------------------------------------------------

# Sanitize an arbitrary string into a git-branch-safe slug:
#   "Fix - Bug!" -> "fix_bug"
sanitize_branch_name() {
  local input="$1"

  # Keep only alphanumeric, spaces, underscores, hyphens; collapse runs of
  # spaces/underscores/hyphens into a single space.
  local clean
  clean=$(echo "$input" | tr -cd '[:alnum:] _-' | sed -E 's/[[:space:]_-]+/ /g')

  # Spaces -> underscores.
  clean=$(echo "$clean" | tr ' ' '_')

  # Collapse multiple underscores.
  clean=$(echo "$clean" | sed -E 's/_+/_/g')

  # Trim leading/trailing underscores.
  clean=$(echo "$clean" | sed -E 's/^_+|_+$//g')

  # Lowercase for consistency.
  echo "$clean" | tr '[:upper:]' '[:lower:]'
}

# ---------------------------------------------------------------------------
# Portability shims
# ---------------------------------------------------------------------------

# Portable in-place sed (macOS requires -i '', Linux requires -i).
sed_inplace() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

# ---------------------------------------------------------------------------
# Exports — sourced files (and subshells) need access to these.
# ---------------------------------------------------------------------------
export -f info success warning error step hint print_banner kv render_table _hanif_render
export -f command_exists is_git_repo get_current_branch branch_exists
export -f confirm check_git_version
export -f sanitize_branch_name sed_inplace
