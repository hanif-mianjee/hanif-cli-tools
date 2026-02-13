#!/usr/bin/env bash

# Hanif CLI Installation Script
# Usage: curl -fsSL https://raw.githubusercontent.com/hanif-mianjee/hanif-cli-tools/main/install.sh | bash

set -euo pipefail

# Configuration
REPO_URL="https://github.com/hanif-mianjee/hanif-cli-tools"
INSTALL_DIR="${HOME}/.hanif-cli"
BIN_DIR="${HOME}/.local/bin"
VERSION="${HANIF_VERSION:-latest}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
warning() { echo -e "${YELLOW}⚠${NC} $*"; }
error() { echo -e "${RED}✗${NC} $*" >&2; }

# Check prerequisites
check_prerequisites() {
  info "Checking prerequisites..."
  
  if ! command -v git >/dev/null 2>&1; then
    error "Git is not installed. Please install Git first."
    exit 1
  fi
  
  if ! command -v bash >/dev/null 2>&1; then
    error "Bash is not available."
    exit 1
  fi
  
  success "Prerequisites satisfied"
}

# Create directories
setup_directories() {
  info "Setting up directories..."
  
  mkdir -p "$INSTALL_DIR"
  mkdir -p "$BIN_DIR"
  
  success "Directories created"
}

# Clone or update repository
install_files() {
  info "Installing Hanif CLI..."
  
  if [[ -d "$INSTALL_DIR/.git" ]]; then
    warning "Existing installation found. Updating..."
    cd "$INSTALL_DIR"
    git fetch --all
    git reset --hard origin/main
  else
    info "Cloning repository..."
    rm -rf "$INSTALL_DIR"
    git clone "$REPO_URL" "$INSTALL_DIR"
  fi
  
  cd "$INSTALL_DIR"
  
  if [[ "$VERSION" != "latest" ]]; then
    info "Checking out version: $VERSION"
    git checkout "$VERSION"
  fi
  
  success "Files installed"
}

# Create symlink
create_symlink() {
  info "Creating symlink..."
  
  local bin_file="$BIN_DIR/hanif"
  local source_file="$INSTALL_DIR/bin/hanif"
  
  # Make executable
  chmod +x "$source_file"
  
  # Remove old symlink if exists
  [[ -L "$bin_file" ]] && rm "$bin_file"
  
  # Create new symlink
  ln -sf "$source_file" "$bin_file"
  
  success "Symlink created: $bin_file -> $source_file"
}

# Update shell configuration
update_shell_config() {
  local shell_config=""
  local shell_name=""
  
  # Detect shell
  if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == *"zsh"* ]]; then
    shell_config="$HOME/.zshrc"
    shell_name="zsh"
  elif [[ -n "${BASH_VERSION:-}" ]] || [[ "$SHELL" == *"bash"* ]]; then
    shell_config="$HOME/.bashrc"
    shell_name="bash"
  fi
  
  if [[ -z "$shell_config" ]]; then
    warning "Could not detect shell configuration file"
    return
  fi
  
  info "Updating $shell_name configuration..."
  
  # Check if BIN_DIR is in PATH
  if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    if ! grep -q "$BIN_DIR" "$shell_config" 2>/dev/null; then
      echo "" >> "$shell_config"
      echo "# Hanif CLI" >> "$shell_config"
      echo "export PATH=\"\$PATH:$BIN_DIR\"" >> "$shell_config"
      success "Added $BIN_DIR to PATH in $shell_config"
      warning "Please run: source $shell_config"
    fi
  fi
}

# Verify installation
verify_installation() {
  info "Verifying installation..."
  
  export PATH="$PATH:$BIN_DIR"
  
  if command -v hanif >/dev/null 2>&1; then
    local version
    version=$(HANIF_SKIP_UPDATE_CHECK=1 hanif version 2>/dev/null || echo "unknown")
    success "Installation verified: $version"
    return 0
  else
    error "Installation verification failed"
    return 1
  fi
}

# Print next steps
print_next_steps() {
  cat << EOF

┌─────────────────────────────────────────────┐
│     Hanif CLI Installed Successfully!       │
└─────────────────────────────────────────────┘

Next steps:

  1. Reload your shell:
     $(echo -e "${YELLOW}source ~/.zshrc${NC}")  (or ~/.bashrc)

  2. Try it:
     $(echo -e "${BLUE}hanif version${NC}")
     $(echo -e "${BLUE}hanif help${NC}")
     $(echo -e "${BLUE}hanif git sync${NC}")

Documentation: ${REPO_URL}

EOF
}

# Uninstall function
uninstall() {
  warning "Uninstalling Hanif CLI..."
  
  rm -rf "$INSTALL_DIR"
  rm -f "$BIN_DIR/hanif"
  
  success "Hanif CLI uninstalled"
  info "You may want to remove PATH modifications from your shell config"
}

# Main installation flow
main() {
  cat << 'EOF'
┌─────────────────────────────────────────────┐
│       Hanif CLI Installation Script         │
└─────────────────────────────────────────────┘

EOF

  # Handle uninstall
  if [[ "${1:-}" == "uninstall" ]]; then
    uninstall
    exit 0
  fi

  check_prerequisites
  setup_directories
  install_files
  create_symlink
  update_shell_config
  
  if verify_installation; then
    print_next_steps
  else
    error "Installation completed but verification failed"
    info "Try running: export PATH=\"\$PATH:$BIN_DIR\""
    exit 1
  fi
}

main "$@"
