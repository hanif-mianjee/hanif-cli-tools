#!/usr/bin/env bash
#
# Git command handlers for Hanif CLI.
#
# This file registers all git-related top-level commands AND a legacy
# ``hanif git <subcommand>`` passthrough for backwards compatibility.
# Adding a new git command is a one-liner: add a register_command call and a
# matching handler at the bottom.

# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------
register_command --name "sync"   --group "Git" \
  --handler "git_sync_handler" \
  --description "Full sync (update, rebase, clean)"

register_command --name "nf"     --aliases "newfeature" --group "Git" \
  --handler "git_nf_handler" \
  --description "Create feature branch"

register_command --name "up"     --aliases "update"     --group "Git" \
  --handler "git_up_handler" \
  --description "Update main branch"

register_command --name "upall"  --aliases "updateall"  --group "Git" \
  --handler "git_upall_handler" \
  --description "Update all branches"

register_command --name "clean"  --group "Git" \
  --handler "git_clean_handler" \
  --description "Delete branches removed from remote"

register_command --name "rb"     --aliases "rebase"     --group "Git" \
  --handler "git_rebase_handler" \
  --description "Rebase onto branch"

register_command --name "pull"   --group "Git" \
  --handler "git_pull_handler" \
  --description "Fetch all + pull"

register_command --name "st"     --aliases "status"     --group "Git" \
  --handler "git_status_handler" \
  --description "Git status"

register_command --name "amend"  --group "Git" \
  --handler "git_amend_handler" \
  --description "Amend last commit with current changes"

register_command --name "gi"     --aliases "gitignore"  --group "Git" \
  --handler "git_gitignore_handler" \
  --description "Add to .gitignore & remove from tracking"

# Legacy ``hanif git <subcommand>`` form. Scheduled for removal in v2.0.0;
# kept until then for backwards compatibility.
register_command --name "git" --group "Git" \
  --handler "git_legacy_handler" \
  --description "Legacy: hanif git <subcommand> (deprecated)"

# ---------------------------------------------------------------------------
# Lazy loader for the heavy git function library.
# ---------------------------------------------------------------------------
_git_load_funcs() {
  if [[ -z "${HANIF_GIT_FUNCS_LOADED:-}" ]]; then
    # shellcheck source=../functions/git-functions.sh
    source "${FUNCTIONS_DIR}/git-functions.sh"
    HANIF_GIT_FUNCS_LOADED=1
  fi
  check_git_version
}

# Helper used by handlers that take an optional ``help`` first argument.
_git_help_or_run() {
  local fn="$1"
  shift
  case "${1:-}" in
    help|--help|-h) show_git_help; return 0 ;;
  esac
  "$fn" "$@"
}

# ---------------------------------------------------------------------------
# Top-level handlers
# ---------------------------------------------------------------------------
git_sync_handler() {
  _git_load_funcs
  info "Starting full sync..."

  local base_branch="main"
  if git show-ref --verify --quiet refs/heads/main; then
    base_branch="main"
  elif git show-ref --verify --quiet refs/heads/master; then
    base_branch="master"
  fi

  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

  gitup

  if [[ -n "$current_branch" ]] && \
     [[ "$current_branch" != "$base_branch" ]] && \
     [[ "$current_branch" != "HEAD" ]]; then
    gitrebase "$base_branch"
  fi

  gitclean
  success "Full sync complete!"
}

git_nf_handler() {
  _git_load_funcs

  # Only treat help as help when it is the *sole* argument, so a description
  # may legitimately begin with the word "help" (hanif nf help text is wrong).
  if [[ $# -eq 1 ]]; then
    case "$1" in
      help|--help|-h) show_git_help; return 0 ;;
    esac
  fi

  if [[ $# -eq 0 ]]; then
    # Prompt instead of erroring when a human is at the keyboard. ``read -r``
    # performs no expansion whatsoever, so this is the only input path that
    # survives backticks, <, > and $ intact — the shell would otherwise mangle
    # them (command substitution / redirection) long before hanif is reached.
    if [[ -t 0 ]]; then
      echo "" >&2
      _hanif_render 1 "${BOLD}${MAGENTA}🌿  New branch${NC}" >&2; printf '\n' >&2
      hint "   (paste the ticket title as-is — no quoting needed)" >&2
      local nf_prompt
      nf_prompt=$(_hanif_render 1 "${YELLOW}?${NC}  Description: ")
      printf '%s' "$nf_prompt" >&2
      local description=""
      IFS= read -r description || return 1
      if [[ -z "$description" ]]; then
        error "No description given"
        return 1
      fi
      newfeature "$description"
      return $?
    fi
    error "Usage: hanif nf [--prefix <p>|--no-prefix] <description>"
    hint "  hanif nf add login form"
    hint "  hanif nf 'JIRA-123: add login form'"
    hint "  hanif nf              (prompts — safest for titles with \` < > \$)"
    return 1
  fi

  # Accept multi-word descriptions without requiring quotes — mirrors how
  # ``hanif squash`` reads multi-word commit messages. ``newfeature`` strips
  # any leading flags and joins the rest with a single space, so:
  #   hanif nf add login form          → "add login form"
  #   hanif nf 'JIRA-123: add login'   → "JIRA-123: add login"
  # both produce the same result.
  newfeature "$@"
}

git_up_handler()    { _git_load_funcs; _git_help_or_run gitup    "$@"; }
git_upall_handler() { _git_load_funcs; _git_help_or_run gitupall "$@"; }
git_clean_handler() { _git_load_funcs; _git_help_or_run gitclean "$@"; }
git_rebase_handler(){ _git_load_funcs; _git_help_or_run gitrebase "$@"; }
git_amend_handler() { _git_load_funcs; _git_help_or_run gitamend "$@"; }

git_pull_handler() {
  _git_load_funcs
  is_git_repo || { error "Not a git repository"; return 1; }
  info "Fetching from all remotes and pulling..."
  git fetch --all && git pull
}

git_status_handler() {
  _git_load_funcs
  git status "$@"
}

git_gitignore_handler() {
  _git_load_funcs
  case "${1:-}" in
    help|--help|-h) show_git_help; return 0 ;;
  esac
  gitignore_add "$@"
}

# Legacy ``hanif git <subcommand>`` dispatcher. Routes the subcommand back
# through the registry so behavior stays identical to the new top-level form.
git_legacy_handler() {
  _git_load_funcs

  if [[ $# -eq 0 ]]; then
    show_git_usage
    return 1
  fi

  local subcommand="$1"
  shift

  case "$subcommand" in
    help|--help|-h) show_git_help; return 0 ;;
  esac

  if registry_has "$subcommand"; then
    dispatch_command "$subcommand" "$@"
    return $?
  fi

  # Pass-through to git for unknown subcommands (e.g. `hanif git commit -m`).
  info "Passing through to git: git $subcommand $*"
  git "$subcommand" "$@"
}

# ---------------------------------------------------------------------------
# Help / usage screens (kept here so they live next to the commands they
# describe).
# ---------------------------------------------------------------------------
show_git_usage() {
  cat <<'EOF'
Git Commands:

Usage: hanif <command> [options]

Commands:
  sync                     Full sync (update, rebase, clean)
  nf, newfeature <desc>    Create a branch (multi-word ok; --prefix to override)
  up, update               Update main branch
  upall, updateall         Update all branches
  clean                    Delete branches removed from remote
  rb, rebase <branch>      Rebase onto branch
  amend ["message"]         Amend last commit with changes
  pull                     Fetch all + pull
  st, status               Git status
  gi, gitignore <path>     Add to .gitignore & untrack
  gsetup, git-setup [name] Set up a new git profile (config + SSH key)

Examples:
  hanif sync
  hanif nf add login form
  hanif nf 'JIRA-123: add feature'
    → Creates: feature/JIRA-123_add_feature
  hanif nf --prefix hotfix 'JIRA-124: patch login'
    → Creates: hotfix/JIRA-124_patch_login
  hanif rb main

Tip: `hanif git <command>` also works (legacy syntax)
     Unknown git commands pass through: hanif git commit -m "msg"

EOF
}

show_git_help() {
  print_banner "Git Helper Commands"
  cat <<'EOF'

SYNC
  Full repository sync - perfect for starting work

  hanif sync

  Does: Update main → Rebase current → Clean old branches

NEWFEATURE (nf)
  Create a branch with smart naming
  Automatically extracts JIRA/ticket numbers
  Multi-word descriptions work without quotes

  hanif nf [--prefix <p> | --no-prefix] <description>

  hanif nf add login
    → feature/add_login

  hanif nf JIRA-123 fix bug
    → feature/JIRA-123_fix_bug

  hanif nf 'OM-456 implement feature'
    → feature/OM-456_implement_feature

  Supports: JIRA-123, ABC-456, OM-789, etc.

  BRANCH PREFIX
    Defaults to "feature". Resolution order:
      1. --prefix <p> / -p <p> / --no-prefix   (this run only)
      2. $HANIF_NF_PREFIX                      (hanif env set HANIF_NF_PREFIX bugfix)
      3. feature

    hanif nf --prefix hotfix 'OM-9: patch login'
      → hotfix/OM-9_patch_login

    hanif nf --no-prefix 'spike idea'
      → spike_idea

  TITLES WITH SPECIAL CHARACTERS
    Backticks, <, > and $ are interpreted by your shell before hanif ever
    runs — double quotes do NOT protect them, and content is silently lost.
    Use single quotes, or run bare `hanif nf` and paste at the prompt:

      hanif nf
      ?  Description: OM-900: create `<env>_catalog.my_table` in all envs
        → feature/OM-900_create_env_catalog_my_table_in_all_envs

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

GITIGNORE (gi)
  Add path to .gitignore and remove from git tracking
  Files stay on disk — only removed from git index

  hanif gi .env
    → Adds .env to .gitignore, untracks it

  hanif gi node_modules/
    → Adds node_modules/ to .gitignore, untracks it

  hanif gitignore "*.log"
    → Adds *.log pattern to .gitignore, untracks matching files

  Features:
  • Creates .gitignore if it doesn't exist
  • Prevents duplicate entries
  • Removes from git index (keeps files on disk)
  • Works with files, directories, and glob patterns

PULL
  Fetch all remotes and pull

  hanif pull

GSETUP (git-setup)
  One-shot setup for a new git identity (work, personal, freelance, …).
  Generates an ed25519 SSH key, writes a per-profile gitconfig, and
  appends an idempotent `includeIf` block to ~/.gitconfig so git
  picks the right name/email AND ssh key automatically based on
  which directory the repo lives in.

  hanif gsetup work
    → asks for repos dir (default ~/code/work), user.name, user.email
    → creates ~/.ssh/id_ed25519_work
    → writes ~/.gitconfig-work
    → appends includeIf block to ~/.gitconfig
    → prints public key + GitHub / Azure DevOps instructions

  Run `hanif gsetup --help` for full details.

LEGACY SYNTAX
  `hanif git <command>` still works for backward compatibility.
  Unknown commands pass to git: hanif git commit -m "msg"

EOF
}
