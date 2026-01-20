#!/usr/bin/env bash

# Verification script to check project completeness

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

success() { echo -e "${GREEN}✓${NC} $*"; }
error() { echo -e "${RED}✗${NC} $*"; }
info() { echo -e "${BLUE}ℹ${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "┌─────────────────────────────────────────────┐"
echo "│   Hanif CLI - Project Verification         │"
echo "└─────────────────────────────────────────────┘"
echo ""

# Check required files
info "Checking required files..."
REQUIRED_FILES=(
  "bin/hanif"
  "lib/commands/git.sh"
  "lib/commands/help.sh"
  "lib/functions/git-functions.sh"
  "lib/utils/common.sh"
  "tests/test-framework.sh"
  "tests/test-git.sh"
  "tests/run-tests.sh"
  "scripts/build.sh"
  "scripts/publish.sh"
  "scripts/dev-install.sh"
  "scripts/dev-uninstall.sh"
  "install.sh"
  "package.json"
  "hanif-cli.rb"
  "README.md"
  "CONTRIBUTING.md"
  "CHANGELOG.md"
  "LICENSE"
  ".gitignore"
)

all_files_ok=true
for file in "${REQUIRED_FILES[@]}"; do
  if [[ -f "$file" ]]; then
    success "$file"
  else
    error "Missing: $file"
    all_files_ok=false
  fi
done

echo ""

# Check executables
info "Checking executable permissions..."
EXECUTABLES=(
  "bin/hanif"
  "tests/run-tests.sh"
  "tests/test-framework.sh"
  "tests/test-git.sh"
  "scripts/build.sh"
  "scripts/publish.sh"
  "scripts/dev-install.sh"
  "scripts/dev-uninstall.sh"
  "install.sh"
)

all_exec_ok=true
for file in "${EXECUTABLES[@]}"; do
  if [[ -x "$file" ]]; then
    success "$file is executable"
  else
    error "$file is not executable"
    all_exec_ok=false
  fi
done

echo ""

# Test CLI
info "Testing CLI..."
if ./bin/hanif version >/dev/null 2>&1; then
  success "CLI executable works"
  ./bin/hanif version
else
  error "CLI executable failed"
  all_files_ok=false
fi

echo ""

# Run tests
info "Running test suite..."
if bash tests/run-tests.sh >/dev/null 2>&1; then
  success "All tests passed"
else
  error "Tests failed"
  all_files_ok=false
fi

echo ""

# Check documentation
info "Checking documentation..."
DOCS=(
  "README.md"
  "QUICKSTART.md"
  "CONTRIBUTING.md"
  "CHANGELOG.md"
  "PROJECT_SUMMARY.md"
  "QUICK_REFERENCE.md"
  "docs/DEVELOPMENT.md"
  "docs/PUBLISHING.md"
  "docs/ARCHITECTURE.md"
)

doc_count=0
for doc in "${DOCS[@]}"; do
  if [[ -f "$doc" ]]; then
    ((doc_count++))
  fi
done
success "Found $doc_count documentation files"

echo ""

# Count statistics
info "Project Statistics..."
file_count=$(find . -type f -not -path '*/\.*' -not -name 'functions_BK.sh' -not -name 'functions.sh' | wc -l | tr -d ' ')
dir_count=$(find . -type d -not -path '*/\.*' | grep -v '^\.$' | wc -l | tr -d ' ')
success "Files created: $file_count"
success "Directories: $dir_count"

echo ""

# Final verdict
echo "┌─────────────────────────────────────────────┐"
if [[ "$all_files_ok" == "true" ]] && [[ "$all_exec_ok" == "true" ]]; then
  echo "│  ✓ Project is COMPLETE and READY TO USE!  │"
else
  echo "│  ⚠ Project has some issues                │"
fi
echo "└─────────────────────────────────────────────┘"
echo ""

if [[ "$all_files_ok" == "true" ]] && [[ "$all_exec_ok" == "true" ]]; then
  info "Next steps:"
  echo "  1. Test: ./bin/hanif help"
  echo "  2. Install: bash scripts/dev-install.sh"
  echo "  3. Use: hanif git nf \"my feature\""
  echo "  4. Read: QUICKSTART.md"
  echo ""
  exit 0
else
  warn "Please fix the issues above"
  exit 1
fi
