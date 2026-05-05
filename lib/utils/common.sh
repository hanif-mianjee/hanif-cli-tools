#!/usr/bin/env bash
#
# Common utility functions for Hanif CLI.
#
# Sourced by ``bin/hanif`` at startup. Keep this file lean — only utilities
# that are used in two or more places belong here.

# Color codes (only set if not already defined to allow re-sourcing).
if [[ -z "${HANIF_COLORS_DEFINED:-}" ]]; then
  readonly RED='\033[0;31m'
  readonly GREEN='\033[0;32m'
  readonly YELLOW='\033[1;33m'
  readonly BLUE='\033[0;34m'
  readonly NC='\033[0m' # No Color
  readonly HANIF_COLORS_DEFINED=1
fi

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
info()    { echo -e "${BLUE}ℹ${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
warning() { echo -e "${YELLOW}⚠${NC} $*"; }
error()   { echo -e "${RED}✗${NC} $*" >&2; }

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
  read -r -p "$(echo -e "${YELLOW}?${NC} ${prompt} [y/N]: ")" response
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
export -f info success warning error
export -f command_exists is_git_repo get_current_branch branch_exists
export -f confirm check_git_version
export -f sanitize_branch_name sed_inplace
