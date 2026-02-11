#!/usr/bin/env bash

# Background update check for Hanif CLI
# Checks once per day if a new version is available on origin/main

HANIF_INSTALL_DIR="${HOME}/.hanif-cli"
UPDATE_CACHE_FILE="${HANIF_INSTALL_DIR}/.update-cache"
UPDATE_CHECK_INTERVAL=86400  # 24 hours in seconds

# Get file modification time in seconds since epoch (portable)
_get_file_mtime() {
  local file="$1"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    stat -f '%m' "$file" 2>/dev/null || echo 0
  else
    stat -c '%Y' "$file" 2>/dev/null || echo 0
  fi
}

# Run a background fetch and write result to cache
_background_update_check() {
  local install_dir="$1"
  local cache_file="$2"

  (
    # Silence everything
    exec >/dev/null 2>&1

    cd "$install_dir" || exit 1

    git fetch --all || exit 1

    local local_head remote_head
    local_head=$(git rev-parse HEAD 2>/dev/null)
    remote_head=$(git rev-parse origin/main 2>/dev/null)

    if [[ -n "$local_head" && -n "$remote_head" && "$local_head" != "$remote_head" ]]; then
      echo "update_available" > "$cache_file"
    else
      echo "up_to_date" > "$cache_file"
    fi
  ) &
  disown
}

# Check for updates - call this after running the main command
check_for_updates() {
  # Skip in CI environments
  [[ -n "${CI:-}" ]] && return 0

  # Skip if not installed via git clone (e.g., development checkout)
  [[ -d "${HANIF_INSTALL_DIR}/.git" ]] || return 0

  # Read cache and show notice if update available
  if [[ -f "$UPDATE_CACHE_FILE" ]]; then
    local cache_content
    cache_content=$(cat "$UPDATE_CACHE_FILE" 2>/dev/null)
    if [[ "$cache_content" == "update_available" ]]; then
      echo ""
      echo -e "\033[1;33mUpdate available!\033[0m Run '\033[1mhanif self-update\033[0m' to upgrade."
    fi
  fi

  # Check if we should spawn a background check
  local now
  now=$(date +%s)

  if [[ -f "$UPDATE_CACHE_FILE" ]]; then
    local mtime
    mtime=$(_get_file_mtime "$UPDATE_CACHE_FILE")
    local age=$(( now - mtime ))
    if [[ $age -lt $UPDATE_CHECK_INTERVAL ]]; then
      return 0
    fi
  fi

  # Spawn background check
  _background_update_check "$HANIF_INSTALL_DIR" "$UPDATE_CACHE_FILE"
}
