#!/usr/bin/env bash

# Common utility functions for Hanif CLI

# Color codes (only set if not already defined)
if [[ -z "${HANIF_COLORS_DEFINED:-}" ]]; then
  readonly RED='\033[0;31m'
  readonly GREEN='\033[0;32m'
  readonly YELLOW='\033[1;33m'
  readonly BLUE='\033[0;34m'
  readonly NC='\033[0m' # No Color
  readonly HANIF_COLORS_DEFINED=1
fi

# Logging functions
info() {
  echo -e "${BLUE}ℹ${NC} $*"
}

success() {
  echo -e "${GREEN}✓${NC} $*"
}

warning() {
  echo -e "${YELLOW}⚠${NC} $*"
}

error() {
  echo -e "${RED}✗${NC} $*" >&2
}

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check if in git repository
is_git_repo() {
  git rev-parse --git-dir >/dev/null 2>&1
}

# Get current git branch
get_current_branch() {
  git rev-parse --abbrev-ref HEAD 2>/dev/null
}

# Check if branch exists
branch_exists() {
  local branch="$1"
  git show-ref --verify --quiet "refs/heads/$branch"
}

# Confirm action (returns 0 for yes, 1 for no)
confirm() {
  local prompt="${1:-Are you sure?}"
  local response
  
  read -r -p "$(echo -e "${YELLOW}?${NC} ${prompt} [y/N]: ")" response
  case "$response" in
    [yY][eE][sS]|[yY]) 
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Print separator
separator() {
  echo "────────────────────────────────────────"
}

# Print header
header() {
  echo ""
  separator
  echo "$*"
  separator
}

# Validate command arguments
require_args() {
  local count=$1
  shift
  local actual=$#
  
  if [[ $actual -lt $count ]]; then
    error "Insufficient arguments: expected at least $count, got $actual"
    return 1
  fi
  return 0
}

# Get script version
get_version() {
  echo "${VERSION:-1.0.0}"
}

# Check minimum git version
check_git_version() {
  if ! command_exists git; then
    error "Git is not installed"
    return 1
  fi
  
  local min_version="2.0.0"
  local git_version
  git_version=$(git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
  
  # Simple version comparison (good enough for major.minor.patch)
  if [[ "$(printf '%s\n' "$min_version" "$git_version" | sort -V | head -n1)" != "$min_version" ]]; then
    warning "Git version $git_version detected. Recommended: $min_version or higher"
  fi
}

# Safe stash (returns 1 if stash was created, 0 otherwise)
safe_stash() {
  local message="${1:-Auto stash by Hanif CLI}"
  
  if [[ -n "$(git status --porcelain)" ]]; then
    info "Stashing local changes..."
    git stash push -m "$message"
    return 1  # Stash was created
  fi
  return 0  # No stash needed
}

# Safe stash pop
safe_stash_pop() {
  info "Restoring stashed changes..."
  if ! git stash pop; then
    warning "Stash pop failed - you may need to resolve conflicts"
    echo "Run 'git stash list' to see your stashes"
    return 1
  fi
  return 0
}

# Truncate string to max length
truncate_string() {
  local string="$1"
  local max_length="${2:-60}"
  
  if [[ ${#string} -gt $max_length ]]; then
    echo "${string:0:$max_length}"
  else
    echo "$string"
  fi
}

# Sanitize string for branch names
sanitize_branch_name() {
  local input="$1"
  
  # Keep only alphanumeric, spaces, underscores, hyphens
  local clean
  clean=$(echo "$input" | tr -cd '[:alnum:] _-')
  
  # Convert spaces to underscores
  clean=$(echo "$clean" | tr ' ' '_')
  
  # Normalize multiple underscores to single
  clean=$(echo "$clean" | sed -E 's/_+/_/g')
  
  # Trim leading/trailing underscores
  clean=$(echo "$clean" | sed -E 's/^_+|_+$//g')
  
  # Convert to lowercase
  clean=$(echo "$clean" | tr '[:upper:]' '[:lower:]')
  
  echo "$clean"
}

# Check if running in CI environment
is_ci() {
  [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]] || [[ -n "${GITLAB_CI:-}" ]]
}

# Print debug info (only if DEBUG=1)
debug() {
  if [[ "${DEBUG:-0}" == "1" ]]; then
    echo -e "${BLUE}[DEBUG]${NC} $*" >&2
  fi
}

# Execute command with retry
retry() {
  local max_attempts="${1:-3}"
  local delay="${2:-2}"
  shift 2
  local command=("$@")
  local attempt=1
  
  while [[ $attempt -le $max_attempts ]]; do
    if "${command[@]}"; then
      return 0
    fi
    
    if [[ $attempt -lt $max_attempts ]]; then
      warning "Command failed (attempt $attempt/$max_attempts). Retrying in ${delay}s..."
      sleep "$delay"
    fi
    
    ((attempt++))
  done
  
  error "Command failed after $max_attempts attempts"
  return 1
}

# Export functions for use in sourced scripts
export -f info success warning error
export -f command_exists is_git_repo get_current_branch branch_exists
export -f confirm separator header require_args
export -f get_version check_git_version
export -f safe_stash safe_stash_pop
export -f truncate_string sanitize_branch_name
export -f is_ci debug retry
