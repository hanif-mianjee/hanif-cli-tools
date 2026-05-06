#!/usr/bin/env bash
#
# stash command — friendlier git stash with named entries and a picker.

register_command --name "stash" --group "Git" \
  --handler "stash_command" \
  --description "Friendlier git stash (save / list / pop / drop)"

stash_command() {
  case "${1:-}" in
    help|--help|-h)
      show_stash_help
      return 0
      ;;
  esac

  # shellcheck source=../functions/stash-functions.sh
  source "${FUNCTIONS_DIR}/stash-functions.sh"
  hanif_stash "$@"
}

show_stash_help() {
  print_banner "Friendlier git stash"
  cat <<'EOF'

DESCRIPTION
  A small wrapper around `git stash` that:
    • lets you name stashes when you save them
    • shows them in a clean numbered table
    • lets you pop / drop by number (no more remembering stash@{N})

USAGE
  hanif stash save [name]    Stash uncommitted changes (incl. untracked)
  hanif stash list           Show all stashes in a table
  hanif stash pop  [N]       Pop a stash (interactive picker if N omitted)
  hanif stash drop [N]       Drop a stash (interactive picker if N omitted)
  hanif stash show [N]       Show the diff of a stash
  hanif stash help           Show this help

EXAMPLES
  hanif stash save "wip on login form"
  hanif stash list
  hanif stash pop          # asks if there is more than one
  hanif stash pop 0        # pop stash@{0}
  hanif stash drop 1

NOTES
  • "save" runs `git stash push -u` so untracked files are included.
  • "pop" / "drop" with no number opens an interactive picker when
    you have more than one stash, or just acts on stash@{0} when
    you have exactly one.

EOF
}
