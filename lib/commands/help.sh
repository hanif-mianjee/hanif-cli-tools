#!/usr/bin/env bash
#
# Help command — topic-based help.
#
# The help command is invoked directly by ``bin/hanif`` (not via the
# registry) so that ``hanif help`` works even before any user-defined
# commands are loaded. As a result this file does NOT call
# ``register_command``.

# Show general help, or topic-specific help when an argument is given.
#
# NOTE on availability of ``show_*_help`` functions:
# ``bin/hanif`` sources every file in ``lib/commands/`` at startup (see
# ``_load_commands``) before this function can ever be invoked, so each of
# the topic-specific help functions (``show_git_help``, ``show_squash_help``,
# ``show_bumpversion_help``, ``show_svg_help``) is already defined in the
# current shell when ``show_help`` runs. No per-call ``source`` is needed.
# This wiring is locked down by:
#   - tests/test-registry.sh::test_cli_help_topics_resolve  (covers all topics)
#   - tests/test-squash.sh::test_help_squash_topic
#   - tests/test-bumpversion.sh (help bv)
#   - tests/test-gitignore.sh (help gi → routes to git help)
show_help() {
  if [[ $# -eq 0 ]]; then
    show_general_help
    return
  fi

  local topic="$1"

  case "$topic" in
    git)
      show_git_help
      ;;
    squash)
      show_squash_help
      ;;
    bumpversion|bv)
      show_bumpversion_help
      ;;
    svg)
      show_svg_help
      ;;
    env|e)
      show_env_help
      ;;
    gsetup|git-setup)
      show_git_setup_help
      ;;
    # Git subcommands route to the git help screen.
    sync|nf|up|upall|clean|rb|pull|st|amend|gitignore|gi)
      show_git_help
      ;;
    *)
      error "No help available for: $topic"
      echo ""
      show_general_help
      ;;
  esac
}

show_general_help() {
  print_banner "Hanif CLI v${VERSION}"
  cat <<EOF

A simple, extensible CLI for your daily workflows.

USAGE
  hanif <command> [options]

GIT COMMANDS
  sync                 Full git sync (update, rebase, clean)
  nf <description>     New feature branch (extracts JIRA tickets)
  up                   Update main branch
  upall                Update all branches
  clean                Clean deleted branches
  rb <branch>          Rebase onto branch
  pull                 Fetch all + pull
  st                   Git status
  amend ["message"]    Amend last commit with current changes
  squash [count]       Interactive commit squashing (default: 20)
  gi <path>            Add to .gitignore & remove from tracking
  gsetup [profile]     Set up a new git profile (config + SSH key)

OTHER COMMANDS
  bv [subcommand]      Version bumping (bump2version compatible)
  svg <subcommand>     SVG to PNG conversion
  env <subcommand>     Manage persistent environment variables
  self-update          Update Hanif CLI to latest version
  help [topic]         Show help
  version              Show version

EXAMPLES
  hanif sync
  hanif nf add login form
  hanif nf "JIRA-123: add feature"
    → Creates: feature/jira-123_add_feature
  hanif squash 5
  hanif svg convert logo.svg 64,128,256
  hanif gi .env
  hanif env set API_KEY=sk-abc123
  hanif help git

LEGACY
  'hanif git <subcommand>' still works for backward compatibility.

EOF
}
