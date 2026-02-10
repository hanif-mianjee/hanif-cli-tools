#!/usr/bin/env bash

# Build script for Hanif CLI
# Prepares the package for distribution

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
error() { echo -e "${RED}✗${NC} $*" >&2; }

main() {
  cd "$PROJECT_ROOT"
  
  info "Building Hanif CLI..."
  
  # 1. Verify all files exist
  info "Checking required files..."
  local required_files=(
    "bin/hanif"
    "lib/commands/git.sh"
    "lib/commands/help.sh"
    "lib/functions/git-functions.sh"
    "lib/utils/common.sh"
    "README.md"
  )
  
  for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
      error "Missing required file: $file"
      exit 1
    fi
    success "Found: $file"
  done
  
  # 2. Make scripts executable
  info "Setting executable permissions..."
  chmod +x bin/hanif
  chmod +x lib/commands/*.sh 2>/dev/null || true
  chmod +x lib/functions/*.sh 2>/dev/null || true
  chmod +x lib/utils/*.sh 2>/dev/null || true
  success "Permissions set"
  
  # 3. Run tests
  if [[ "${SKIP_TESTS:-0}" != "1" ]]; then
    info "Running tests..."
    if bash tests/run-tests.sh; then
      success "All tests passed"
    else
      error "Tests failed"
      exit 1
    fi
  else
    info "Skipping tests (SKIP_TESTS=1)"
  fi
  
  # 4. Run linter (if shellcheck available)
  if command -v shellcheck >/dev/null 2>&1; then
    info "Running shellcheck..."
    if shellcheck bin/hanif lib/**/*.sh 2>/dev/null || true; then
      success "Linting complete"
    else
      error "Linting found issues (non-fatal)"
    fi
  else
    info "Skipping shellcheck (not installed)"
  fi
  
  # 5. Create distribution info
  info "Creating build info..."
  cat > .buildinfo << EOF
Build Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Version: $(grep '^VERSION=' bin/hanif | head -1 | cut -d'"' -f2)
Git Commit: $(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
Git Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
EOF
  success "Build info created"
  
  echo ""
  success "Build complete!"
  echo ""
  echo "Next steps:"
  echo "  1. Review changes: git status"
  echo "  2. Test locally: ./bin/hanif help"
  echo "  3. Publish: bash scripts/publish.sh"
  echo ""
  
  cat .buildinfo
}

main "$@"
