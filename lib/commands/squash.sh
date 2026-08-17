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

  local arg1="${1:-}"
  local arg2="${2:-}"

  case "$arg1" in
    help|--help|-h)
      show_squash_help
      return 0
      ;;
  esac

  # shellcheck source=../functions/squash-functions.sh
  source "${FUNCTIONS_DIR}/squash-functions.sh"

  # Two-arg form: range squash <older> <newer>
  if [ -n "$arg1" ] && [ -n "$arg2" ]; then
    git_squash_range "$arg1" "$arg2"
    return $?
  fi

  # Single arg: count (pure digits) or hash (anything else, validated).
  if [ -z "$arg1" ]; then
    git_squash_from "20"
    return $?
  fi

  if [[ "$arg1" =~ ^[0-9]+$ ]]; then
    git_squash_from "$arg1"
    return $?
  fi

  if [[ "$arg1" =~ ^[0-9a-fA-F]{4,40}$ ]]; then
    git_squash_from_hash "$arg1"
    return $?
  fi

  error "Invalid argument: '$arg1'"
  hint "   Usage: hanif squash [count|<hash>|<older> <newer>]"
  hint "   Run 'hanif squash --help' for details."
  return 1
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
  hanif squash [count]            Pick from last <count> commits (default 20)
  hanif squash <hash>             Squash <hash>..HEAD (skip the picker)
  hanif squash <older> <newer>    Squash inclusive range; commits after
                                  <newer> are preserved via cherry-pick

FEATURES
  🎯 Interactive commit selection (or skip via hash)
  📝 Custom commit messages (optional)
  🔄 Preserves commit history with hashes
  🌳 Root commit support (squash all commits)
  💬 Multi-line message support
  ↪️  Range mode preserves trailing commits via cherry-pick

WORKFLOW (count / picker mode)
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

HASH MODE
  When you already know the base commit hash, skip the picker:
    hanif squash 1a6c6d8

  Squashes every commit from 1a6c6d8 through HEAD into one commit.
  Same custom-message prompt as picker mode.

RANGE MODE
  Squash an arbitrary inclusive range without losing trailing work:
    hanif squash 1a6c6d8 ef3798f

  Requirements:
    • Clean working tree (commit or stash changes first)
    • Checked-out branch (no detached HEAD)
    • <older> must be an ancestor of <newer>
    • <newer> must be reachable from HEAD

  Behavior:
    1. Squashes commits in <older>..<newer> into a single commit.
    2. Cherry-picks any commits that came after <newer> back on top.
    3. On cherry-pick conflict, stops and prints recovery commands.

EXAMPLES
  # Pick from last 8 commits
  hanif squash 8

  # Skip the picker — squash from a known hash to HEAD
  hanif squash 1a6c6d8

  # Squash a range, keeping the 2 commits after ef3798f intact
  hanif squash 1a6c6d8 ef3798f

  # Squash from root (all commits)
  hanif squash 50          # then pick the bottom-most entry

TIPS
  • Pure-digit args are always treated as a count, never as a hash.
  • Default count is 20 if no argument is given.
  • Press Enter at the message prompt to keep the selected commit's message.
  • Custom messages become the first line; original hashes are preserved below.
  • Range mode prints the original HEAD so you can recover via:
        git reset --hard <original-head>

EOF
}
