#!/usr/bin/env bash
#
# Squash command — interactive commit squashing.

register_command --name "squash" --group "Other" \
  --handler "squash_command" \
  --description "Interactive commit squashing (default: 20)"

squash_command() {
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    error "Not a git repository"
    return 1
  fi

  local subcommand="${1:-20}"

  case "$subcommand" in
    help|--help|-h)
      show_squash_help
      ;;
    *)
      # shellcheck source=../functions/squash-functions.sh
      source "${FUNCTIONS_DIR}/squash-functions.sh"
      git_squash_from "$subcommand"
      ;;
  esac
}

show_squash_help() {
  print_banner "Interactive Commit Squashing"
  cat <<'EOF'

DESCRIPTION
  Interactively squash Git commits with smart message formatting.
  Choose which commit to squash into and optionally provide a
  custom message. All squashed commits are preserved in the
  final message with their hashes.

USAGE
  hanif squash [count]    (default: 20)

FEATURES
  🎯 Interactive commit selection
  📝 Custom commit messages (optional)
  🔄 Preserves commit history with hashes
  🌳 Root commit support (squash all commits)
  💬 Multi-line message support

WORKFLOW
  1. Select commits to view:
     📜 Select a commit to squash everything into:
     1) a524b8f Fifth commit
     2) ef3798f Fourth commit
     3) 1a6c6d8 Third commit
     Enter number [1-3]: 3

  2. Provide custom message (optional):
     💬 Enter custom message for squashed commit
        (Press Enter to use: "Third commit")
     Message: OM-1200 Major refactor

     • Press Enter: use selected commit's message
     • Type message: use as first line of squashed commit

  3. Result with custom message:
     OM-1200 Major refactor
     * 1a6c6d8 Third commit
     * ef3798f Fourth commit
     * a524b8f Fifth commit

     Result without custom message:
     Third commit
     * ef3798f Fourth commit
     * a524b8f Fifth commit

EXAMPLES
  # Clean up feature branch (8 commits)
  hanif squash 8
  # Select commit #1, add: "feat: implement user auth"

  # Prepare for PR (squash last 5 WIP commits)
  hanif squash 5
  # Select commit #2, press Enter to keep its message

  # Squash from root (all commits)
  hanif squash 10
  # Select option 10 to squash everything

  # Re-squash (add commits after previous squash)
  hanif squash 3
  # Works seamlessly with already-squashed commits

TIPS
  • Root commit is auto-detected (squash from root when selecting the initial commit)
  • Default count is 20 if not specified
  • Press Enter to keep selected commit message
  • Custom messages become the first line
  • All commits preserved with hashes in message body
  • Re-squashing preserves previous formatting

EOF
}
