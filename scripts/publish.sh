#!/usr/bin/env bash

# Publishing script for Hanif CLI
# Automates the release process

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
error() { echo -e "${RED}✗${NC} $*" >&2; }
warning() { echo -e "${YELLOW}⚠${NC} $*"; }

confirm() {
  local prompt="${1:-Continue?}"
  local response
  read -r -p "$(echo -e "${YELLOW}?${NC} ${prompt} [y/N]: ")" response
  case "$response" in
    [yY][eE][sS]|[yY]) return 0 ;;
    *) return 1 ;;
  esac
}

main() {
  cd "$PROJECT_ROOT"
  
  echo "┌─────────────────────────────────────────────┐"
  echo "│       Hanif CLI Publishing Script          │"
  echo "└─────────────────────────────────────────────┘"
  echo ""
  
  # 1. Check git status
  info "Checking git status..."
  if [[ -n "$(git status --porcelain)" ]]; then
    error "Working directory is not clean"
    git status --short
    exit 1
  fi
  success "Working directory is clean"
  
  # 2. Check branch
  local branch
  branch=$(git rev-parse --abbrev-ref HEAD)
  if [[ "$branch" != "main" ]] && [[ "$branch" != "master" ]]; then
    error "Not on main/master branch (current: $branch)"
    if ! confirm "Continue anyway?"; then
      exit 1
    fi
  fi
  success "On branch: $branch"
  
  # 3. Pull latest
  info "Pulling latest changes..."
  git pull origin "$branch"
  success "Up to date"
  
  # 4. Run tests
  info "Running tests..."
  if ! bash tests/run-tests.sh; then
    error "Tests failed"
    exit 1
  fi
  success "All tests passed"
  
  # 5. Run linter
  if command -v shellcheck >/dev/null 2>&1; then
    info "Running linter..."
    shellcheck bin/hanif lib/**/*.sh 2>/dev/null || warning "Linter found issues"
  fi
  
  # 6. Get current version
  local current_version
  current_version=$(grep '"version"' package.json | head -1 | cut -d'"' -f4)
  info "Current version: $current_version"
  
  # 7. Ask for version bump
  echo ""
  echo "Select version bump type:"
  echo "  1) patch (${current_version} → $(npm version patch --no-git-tag-version 2>/dev/null | tail -1 | tr -d 'v'))"
  echo "  2) minor (${current_version} → $(npm version minor --no-git-tag-version 2>/dev/null | tail -1 | tr -d 'v'))"
  echo "  3) major (${current_version} → $(npm version major --no-git-tag-version 2>/dev/null | tail -1 | tr -d 'v'))"
  echo "  4) custom"
  echo "  5) skip (keep current version)"
  
  # Reset package.json after preview
  git checkout package.json 2>/dev/null
  
  read -r -p "Choice [1-5]: " choice
  
  local new_version=""
  case "$choice" in
    1) npm version patch --no-git-tag-version; new_version=$(grep '"version"' package.json | head -1 | cut -d'"' -f4) ;;
    2) npm version minor --no-git-tag-version; new_version=$(grep '"version"' package.json | head -1 | cut -d'"' -f4) ;;
    3) npm version major --no-git-tag-version; new_version=$(grep '"version"' package.json | head -1 | cut -d'"' -f4) ;;
    4) read -r -p "Enter version: " new_version; npm version "$new_version" --no-git-tag-version ;;
    5) new_version="$current_version" ;;
    *) error "Invalid choice"; exit 1 ;;
  esac
  
  info "Version: $new_version"
  
  # 8. Update version in other files
  if [[ "$new_version" != "$current_version" ]]; then
    info "Updating version in all files..."

    # bin/hanif - VERSION variable
    sed -i '' "s/^VERSION=\".*\"/VERSION=\"${new_version}\"/" bin/hanif
    success "Updated bin/hanif"

    # hanif-cli.rb - version and url
    sed -i '' "s|archive/v.*\.tar\.gz|archive/v${new_version}.tar.gz|" hanif-cli.rb
    sed -i '' "s/^  version \".*\"/  version \"${new_version}\"/" hanif-cli.rb
    success "Updated hanif-cli.rb"

    # README.md - version badge
    sed -i '' "s/version-[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*-blue/version-${new_version}-blue/" README.md
    success "Updated README.md badge"

    # CHANGELOG.md - open for manual editing
    if confirm "Open CHANGELOG.md to add release notes?"; then
      ${EDITOR:-vim} CHANGELOG.md
    fi
  fi
  
  # 9. Build
  info "Running build..."
  bash scripts/build.sh
  success "Build complete"
  
  # 10. Review changes
  echo ""
  info "Review changes:"
  git diff
  echo ""
  
  if ! confirm "Proceed with publishing?"; then
    warning "Aborted"
    exit 0
  fi
  
  # 11. Commit version bump
  if [[ "$new_version" != "$current_version" ]]; then
    git add package.json bin/hanif hanif-cli.rb CHANGELOG.md README.md
    git commit -m "chore: release version $new_version"
  fi
  
  # 12. Create tag
  git tag -a "v${new_version}" -m "Release version ${new_version}"
  success "Created tag: v${new_version}"
  
  # 13. Push
  info "Pushing to git..."
  git push origin "$branch"
  git push origin "v${new_version}"
  success "Pushed to git"
  
  # 14. Publish to npm
  if confirm "Publish to npm?"; then
    info "Publishing to npm..."
    if npm publish; then
      success "Published to npm"
    else
      error "npm publish failed"
      warning "Tag v${new_version} has been created but not pushed to npm"
      exit 1
    fi
  else
    warning "Skipped npm publish"
  fi
  
  # 15. Create GitHub release
  echo ""
  info "Next steps:"
  echo "  1. Create GitHub release: https://github.com/hanif-mianjee/hanif-cli-tools/releases/new"
  echo "  2. Update Homebrew formula with new sha256"
  echo "  3. Test installation:"
  echo "       npm install -g hanif-cli"
  echo "       hanif version"
  echo ""
  
  success "Publishing complete! 🎉"
}

main "$@"
