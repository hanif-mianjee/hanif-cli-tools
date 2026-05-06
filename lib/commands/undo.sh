#!/usr/bin/env bash
#
# undo command — interactive "undo the last git thing" menu.

register_command --name "undo" --group "Git" \
  --handler "undo_command" \
  --description "Interactive 'undo the last git thing' menu"

undo_command() {
  case "${1:-}" in
    help|--help|-h)
      show_undo_help
      return 0
      ;;
  esac

  # shellcheck source=../functions/undo-functions.sh
  source "${FUNCTIONS_DIR}/undo-functions.sh"
  hanif_undo "$@"
}

show_undo_help() {
  print_banner "Undo the Last Git Thing"
  cat <<'EOF'

DESCRIPTION
  Friendly menu over the most-Googled "how do I undo this?" git
  recipes. Detects what's actually undoable in the current repo
  (in-progress merge/rebase, last commit, staged files) and only
  offers the relevant choices. Every action asks for confirmation.

USAGE
  hanif undo               Open the interactive menu
  hanif undo help          Show this help

WHAT IT CAN UNDO
  1. Abort an in-progress merge / rebase / cherry-pick
  2. Undo the last commit, keeping the changes (soft reset)
  3. Undo the last commit, discarding the changes (hard reset)
  4. Unstage all files (git reset HEAD)
  5. Discard unstaged changes in the working tree (git checkout --)

NOTES
  • "Discard" actions are destructive and require typing 'yes' to
    confirm — there is no second chance.
  • Use 'hanif unwip' for WIP-specific commits.

EOF
}
