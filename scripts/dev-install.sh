#!/usr/bin/env bash

# Development installation script
# Installs Hanif CLI locally for development/testing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN_DIR="${HOME}/.local/bin"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
warning() { echo -e "${YELLOW}⚠${NC} $*"; }

main() {
  cd "$PROJECT_ROOT"
  
  info "Installing Hanif CLI for development..."
  
  # Create bin directory if it doesn't exist
  mkdir -p "$BIN_DIR"
  
  # Make executable
  chmod +x bin/hanif
  
  # Create symlink
  local bin_file="$BIN_DIR/hanif"
  local source_file="$PROJECT_ROOT/bin/hanif"
  
  if [[ -L "$bin_file" ]]; then
    warning "Removing existing symlink..."
    rm "$bin_file"
  elif [[ -f "$bin_file" ]]; then
    warning "File exists at $bin_file - backing up..."
    mv "$bin_file" "${bin_file}.backup"
  fi
  
  info "Creating symlink: $bin_file -> $source_file"
  ln -sf "$source_file" "$bin_file"
  
  success "Development installation complete!"
  
  # Check if in PATH
  if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo ""
    warning "Note: $BIN_DIR is not in your PATH"
    echo "Add this to your ~/.zshrc or ~/.bashrc:"
    echo "  export PATH=\"\$PATH:$BIN_DIR\""
    echo ""
    echo "Then run: source ~/.zshrc"
  fi
  
  echo ""
  echo "Test the installation:"
  echo "  hanif version"
  echo "  hanif help"
  echo ""
  echo "Development workflow:"
  echo "  1. Edit files in: $PROJECT_ROOT"
  echo "  2. Test immediately: hanif <command>"
  echo "  3. No reinstall needed (symlinked)"
  echo ""
}

main "$@"
