#!/usr/bin/env bash

# Git command handler for Hanif CLI

# Source git functions
# shellcheck source=../functions/git-functions.sh
source "${FUNCTIONS_DIR}/git-functions.sh"

# Git subcommand dispatcher
git_command() {
  if [[ $# -eq 0 ]]; then
    show_git_usage
    exit 1
  fi

  local subcommand="$1"
  shift

  case "$subcommand" in
    newfeature|nf)
      if [[ $# -eq 0 ]]; then
        error "Usage: hanif git newfeature \"description\""
        exit 1
      fi
      newfeature "$@"
      ;;
    
    up|update)
      gitup "$@"
      ;;
    
    upall|updateall)
      gitupall "$@"
      ;;
    
    clean)
      gitclean "$@"
      ;;
    
    rebase|rb)
      gitrebase "$@"
      ;;
    
    pull)
      # Custom pull command: fetch all and pull
      git rev-parse --git-dir >/dev/null 2>&1 || { error "Not a git repository"; exit 1; }
      info "Fetching from all remotes and pulling..."
      git fetch --all && git pull
      ;;
    
    status|st)
      git status "$@"
      ;;
    
    sync)
      # Full sync: update base branch, rebase current branch, clean old branches
      info "Starting full sync..."
      
      local base_branch="main"
      if git show-ref --verify --quiet refs/heads/main; then
        base_branch="main"
      elif git show-ref --verify --quiet refs/heads/master; then
        base_branch="master"
      fi
      
      local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
      
      # Update base branch
      gitup
      
      # If not on base branch, rebase
      if [[ "$current_branch" != "$base_branch" ]] && [[ "$current_branch" != "HEAD" ]]; then
        gitrebase "$base_branch"
      fi
      
      # Clean old branches
      gitclean
      
      success "Full sync complete!"
      ;;
    
    help|--help|-h)
      show_git_help
      ;;
    
    *)
      # Pass through to git for unknown commands
      info "Passing through to git: git $subcommand $*"
      git "$subcommand" "$@"
      ;;
  esac
}

# Show git subcommand usage
show_git_usage() {
  cat << 'EOF'
Git Commands:

Usage: hanif git <subcommand> [options]

Common Commands:
  sync                     Full sync (update, rebase, clean)
  nf, newfeature <desc>    Create feature branch
  up, update               Update main branch
  upall, updateall         Update all branches
  clean                    Delete branches removed from remote
  rb, rebase <branch>      Rebase onto branch
  pull                     Fetch all + pull
  st, status               Git status

Examples:
  hanif git sync
  hanif git nf "add feature"
  hanif git rb main

Tip: Unknown commands pass through to git
     hanif git commit -m "msg" → git commit -m "msg"

EOF
}

# Show detailed git help
show_git_help() {
  cat << 'EOF'
┌─────────────────────────────────────────────┐
│           Git Helper Commands               │
└─────────────────────────────────────────────┘

SYNC
  Full repository sync - perfect for starting work
  
  hanif git sync
  
  Does: Update main → Rebase current → Clean old branches

NEWFEATURE (nf)
  Create feature branch with smart naming
  
  hanif git nf "add login"
    → feature/add_login
  
  hanif git nf "JIRA-123: fix bug"
    → feature/jira-123_fix_bug

UPDATE (up)
  Update main/master branch
  
  hanif git up

UPDATE ALL (upall)
  Update all local branches (stashes, updates, restores)
  
  hanif git upall

CLEAN
  Delete local branches removed from remote
  Protects: main, master, current branch
  
  hanif git clean

REBASE (rb)
  Rebase current branch (updates base, stashes, rebases)
  
  hanif git rb main

PULL
  Fetch all remotes and pull
  
  hanif git pull

PASSTHROUGH
  Unknown commands pass to git
  
  hanif git commit -m "msg" → git commit -m "msg"

EOF
}
