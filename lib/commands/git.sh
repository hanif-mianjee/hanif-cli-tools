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

Subcommands:
  newfeature, nf <desc>    Create a new feature branch
  up, update               Update main/master branch
  upall, updateall         Update all local branches
  clean                    Delete branches removed from remote
  rebase, rb <branch>      Rebase current branch onto another
  pull                     Fetch all and pull
  status, st               Show git status
  sync                     Full sync (update, rebase, clean)
  help                     Show detailed help

Examples:
  hanif git newfeature "add user auth"
  hanif git nf "OM-755: fix login bug"
  hanif git up
  hanif git rebase main
  hanif git sync

For more details: hanif help git
EOF
}

# Show detailed git help
show_git_help() {
  cat << 'EOF'
┌─────────────────────────────────────────────┐
│           Git Helper Commands               │
└─────────────────────────────────────────────┘

NEWFEATURE (nf)
  Create a new feature branch with smart naming
  
  Usage:
    hanif git newfeature "description"
    hanif git nf "TICKET-123: description"
  
  Examples:
    hanif git nf "add user authentication"
      → creates: feature/add_user_authentication
    
    hanif git nf "OM-755: fix login bug"
      → creates: feature/om-755_fix_login_bug
  
  Features:
    - Extracts ticket numbers (JIRA-123, OM-755, etc.)
    - Sanitizes branch names
    - Enforces 60 char limit
    - Converts to lowercase

UP (update)
  Update main/master branch with latest changes
  
  Usage:
    hanif git up
  
  What it does:
    - Checks out main/master
    - Fetches from all remotes
    - Pulls latest changes

UPALL (updateall)
  Update all local branches with remote changes
  
  Usage:
    hanif git upall
  
  What it does:
    - Stashes local changes
    - Fetches all remotes (single fetch)
    - Fast-forwards all branches
    - Restores to original branch
    - Restores stash

CLEAN
  Delete local branches removed from remote
  
  Usage:
    hanif git clean
  
  What it does:
    - Protects main, master, and current branch
    - Deletes branches gone from origin
    - Keeps local-only branches
  
  Safety:
    - Never deletes protected branches
    - Only deletes if remote tracking is gone

REBASE (rb)
  Rebase current branch onto another branch
  
  Usage:
    hanif git rebase <base-branch>
    hanif git rb main
  
  What it does:
    - Updates base branch first
    - Stashes local changes
    - Rebases current branch
    - Restores stash
  
  Example:
    hanif git rb main

PULL
  Fetch from all remotes and pull
  
  Usage:
    hanif git pull
  
  What it does:
    git fetch --all && git pull

SYNC
  Full repository sync workflow
  
  Usage:
    hanif git sync
  
  What it does:
    1. Updates main/master
    2. Rebases current branch (if not on main)
    3. Cleans deleted branches
  
  Perfect for: Starting work after being away

STATUS (st)
  Show git status
  
  Usage:
    hanif git status
    hanif git st

PASSTHROUGH
  Any unrecognized command is passed to git
  
  Example:
    hanif git commit -m "fix bug"
      → executes: git commit -m "fix bug"

EOF
}
