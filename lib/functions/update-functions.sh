#!/usr/bin/env bash

# Self-update functions for Hanif CLI

INSTALL_DIR="${HOME}/.hanif-cli"
INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/hanif-mianjee/hanif-cli-tools/main/install.sh"

# Self-update by re-running the install script
self_update() {
  local current_version="${VERSION:-unknown}"
  info "Current version: Hanif CLI v${current_version}"
  echo ""

  if ! command_exists curl; then
    error "curl is required for self-update but is not installed"
    return 1
  fi

  info "Updating Hanif CLI..."
  echo ""

  if curl -fsSL "$INSTALL_SCRIPT_URL" | bash; then
    echo ""
    # Clear stale update cache so "Update available!" isn't shown post-update
    echo "up_to_date" > "${HOME}/.hanif-cli/.update-cache"
    # Re-source to pick up new version
    local new_version
    if [[ -f "${INSTALL_DIR}/bin/hanif" ]]; then
      new_version=$("${INSTALL_DIR}/bin/hanif" version 2>/dev/null || echo "unknown")
    else
      new_version="unknown"
    fi
    success "Update complete! ${new_version}"
  else
    error "Update failed. Please try again or reinstall manually."
    echo "  curl -fsSL $INSTALL_SCRIPT_URL | bash"
    return 1
  fi
}
