#!/usr/bin/env bash

# Help command handler for Hanif CLI

# Show general help
show_help() {
  if [[ $# -eq 0 ]]; then
    show_general_help
    return
  fi

  local topic="$1"
  
  case "$topic" in
    git)
      source "${COMMANDS_DIR}/git.sh"
      show_git_help
      ;;
    
    squash)
      source "${COMMANDS_DIR}/squash.sh"
      show_squash_help
      ;;
    
    *)
      echo "❌ No help available for: $topic"
      echo ""
      show_general_help
      ;;
  esac
}

# Show general help information
show_general_help() {
  cat << 'EOF'
┌─────────────────────────────────────────────┐
│         Hanif CLI - Personal Tools          │
│                 Version 1.0.0               │
└─────────────────────────────────────────────┘

A simple, extensible CLI for your daily workflows.

USAGE
  hanif <command> [options]

COMMANDS
  git <subcommand>     Git workflow helpers
  squash <count>       Interactive commit squashing
  help [topic]         Show help
  version              Show version

GIT COMMANDS
  sync                 Full git sync (update, rebase, clean)
  nf "description"     New feature branch (extracts JIRA tickets)
  up                   Update main branch
  upall                Update all branches
  clean                Clean deleted branches
  rb <branch>          Rebase onto branch

SQUASH COMMAND
  Interactive commit squashing with smart message formatting
  
  hanif squash <count>
    → Shows last N commits, select which to squash into
    → Optionally provide custom message
    → Preserves all commits with hashes in message

EXAMPLES
  hanif git sync
  hanif git nf "add login"
  hanif git nf "JIRA-123: add feature"
    → Creates: feature/jira-123_add_feature
  hanif squash 5
    → Interactively squash last 5 commits
  hanif help squash
  hanif help git

ADDING COMMANDS
  1. Create lib/commands/mycommand.sh
  2. Register in bin/hanif
  3. Use: hanif mycommand

See README.md for details.

EOF
}
