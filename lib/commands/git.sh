#!/usr/bin/env bash

# Git command handler for Hanif CLI

# Source git functions
# shellcheck source=../functions/git-functions.sh
source "${FUNCTIONS_DIR}/git-functions.sh"

# Git subcommand dispatcher
git_command() {
  check_git_version

  if [[ $# -eq 0 ]]; then
    show_git_usage
    exit 1
  fi

  local subcommand="$1"
  shift

  case "$subcommand" in
    newfeature|nf)
      if [[ $# -eq 0 ]]; then
        error "Usage: hanif nf \"description\""
        exit 1
      fi
      case "$1" in
        help|--help|-h) show_git_help; return ;;
      esac
      newfeature "$@"
      ;;
    
    up|update)
      case "${1:-}" in
        help|--help|-h) show_git_help; return ;;
      esac
      gitup "$@"
      ;;

    upall|updateall)
      case "${1:-}" in
        help|--help|-h) show_git_help; return ;;
      esac
      gitupall "$@"
      ;;

    clean)
      case "${1:-}" in
        help|--help|-h) show_git_help; return ;;
      esac
      gitclean "$@"
      ;;
    
    rebase|rb)
      case "${1:-}" in
        help|--help|-h) show_git_help; return ;;
      esac
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

    amend)
      case "${1:-}" in
        help|--help|-h) show_git_help; return ;;
      esac
      gitamend "$@"
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

Usage: hanif <command> [options]

Commands:
  sync                     Full sync (update, rebase, clean)
  nf, newfeature <desc>    Create feature branch
  up, update               Update main branch
  upall, updateall         Update all branches
  clean                    Delete branches removed from remote
  rb, rebase <branch>      Rebase onto branch
  amend ["message"]         Amend last commit with changes
  pull                     Fetch all + pull
  st, status               Git status

Examples:
  hanif sync
  hanif nf "add feature"
  hanif nf "JIRA-123: add feature"
    → Creates: feature/jira-123_add_feature
  hanif rb main

Tip: `hanif git <command>` also works (legacy syntax)
     Unknown git commands pass through: hanif git commit -m "msg"

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

  hanif sync

  Does: Update main → Rebase current → Clean old branches

NEWFEATURE (nf)
  Create feature branch with smart naming
  Automatically extracts JIRA/ticket numbers

  hanif nf "add login"
    → feature/add_login

  hanif nf "JIRA-123: fix bug"
    → feature/jira-123_fix_bug

  hanif nf "OM-456 implement feature"
    → feature/om-456_implement_feature

  Supports: JIRA-123, ABC-456, OM-789, etc.

UPDATE (up)
  Update main/master branch

  hanif up

UPDATE ALL (upall)
  Update all local branches (stashes, updates, restores)

  hanif upall

CLEAN
  Delete local branches removed from remote
  Protects: main, master, current branch

  hanif clean

REBASE (rb)
  Rebase current branch (updates base, stashes, rebases)

  hanif rb main

AMEND
  Amend last commit with all current changes
  Updates commit date. Useful for small fixes/typos.

  hanif amend
    → Stages all changes, amends last commit (keeps message)

  hanif amend "updated message"
    → Stages all changes, amends with new message

PULL
  Fetch all remotes and pull

  hanif pull

LEGACY SYNTAX
  `hanif git <command>` still works for backward compatibility.
  Unknown commands pass to git: hanif git commit -m "msg"

EOF
}
