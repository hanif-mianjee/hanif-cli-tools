#!/usr/bin/env bash

# Development uninstallation script

set -euo pipefail

BIN_DIR="${HOME}/.local/bin"
BIN_FILE="$BIN_DIR/hanif"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${YELLOW}ℹ${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }

main() {
  info "Uninstalling Hanif CLI development installation..."
  
  if [[ -L "$BIN_FILE" ]]; then
    rm "$BIN_FILE"
    success "Removed symlink: $BIN_FILE"
  elif [[ -f "$BIN_FILE" ]]; then
    info "Found non-symlink file at $BIN_FILE"
    read -r -p "Remove it? [y/N]: " response
    if [[ "$response" =~ ^[yY]$ ]]; then
      rm "$BIN_FILE"
      success "Removed: $BIN_FILE"
    fi
  else
    info "No installation found at $BIN_FILE"
  fi
  
  # Check for backup
  if [[ -f "${BIN_FILE}.backup" ]]; then
    info "Found backup file: ${BIN_FILE}.backup"
    read -r -p "Restore it? [y/N]: " response
    if [[ "$response" =~ ^[yY]$ ]]; then
      mv "${BIN_FILE}.backup" "$BIN_FILE"
      success "Restored backup"
    fi
  fi
  
  echo ""
  success "Uninstallation complete!"
}

main "$@"
