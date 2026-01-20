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

DESCRIPTION
  A personal productivity CLI tool with git helpers,
  automation scripts, and daily workflow commands.

USAGE
  hanif <command> [subcommand] [options]

COMMANDS
  git <subcommand>
    Powerful git workflow helpers
    
    Subcommands:
      newfeature (nf)    Create feature branch
      up                 Update main branch
      upall              Update all branches
      clean              Clean deleted branches
      rebase (rb)        Rebase workflow
      pull               Fetch all + pull
      sync               Full sync workflow
      status (st)        Git status
      
    Examples:
      hanif git nf "add feature"
      hanif git up
      hanif git sync

  help [topic]
    Show detailed help for a topic
    
    Examples:
      hanif help
      hanif help git

  version
    Show version information

GETTING STARTED
  1. Create a new feature:
     $ hanif git nf "my awesome feature"
  
  2. Update your branches:
     $ hanif git upall
  
  3. Full sync workflow:
     $ hanif git sync

TIPS
  - Most commands have short aliases (nf, rb, st)
  - Unknown git commands pass through to git
  - Use 'hanif help <command>' for details

INSTALLATION
  npm:       npm install -g hanif-cli
  Homebrew:  brew install hanif-cli
  Script:    curl -fsSL <url> | bash

DOCUMENTATION
  Repository: https://github.com/yourusername/hanif-cli-tools
  Issues:     https://github.com/yourusername/hanif-cli-tools/issues

EOF
}
