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

    svg)
      source "${COMMANDS_DIR}/svg.sh"
      show_svg_help
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
│                 Version 0.0.0               │
└─────────────────────────────────────────────┘

A simple, extensible CLI for your daily workflows.

USAGE
  hanif <command> [options]

GIT COMMANDS
  sync                 Full git sync (update, rebase, clean)
  nf "description"     New feature branch (extracts JIRA tickets)
  up                   Update main branch
  upall                Update all branches
  clean                Clean deleted branches
  rb <branch>          Rebase onto branch
  pull                 Fetch all + pull
  st                   Git status
  squash [count]       Interactive commit squashing (default: 20)

OTHER COMMANDS
  svg <subcommand>     SVG to PNG conversion
  help [topic]         Show help
  version              Show version

EXAMPLES
  hanif sync
  hanif nf "add login"
  hanif nf "JIRA-123: add feature"
    → Creates: feature/jira-123_add_feature
  hanif squash 5
  hanif svg convert logo.svg 64,128,256
  hanif help git

LEGACY
  `hanif git <subcommand>` still works for backward compatibility.

EOF
}
