#!/usr/bin/env bash
#
# wip / unwip — park work in progress, then restore it.

register_command --name "wip" --group "Git" \
  --handler "wip_command" \
  --description "Stage everything and commit as a WIP marker"

register_command --name "unwip" --group "Git" \
  --handler "unwip_command" \
  --description "Undo the last WIP commit, restoring staged state"

wip_command() {
  case "${1:-}" in
    help|--help|-h)
      show_wip_help
      return 0
      ;;
  esac

  is_git_repo || { error "Not inside a git repository"; return 1; }

  # Refuse if a merge/rebase/cherry-pick is in progress so we don't bury it.
  local gd
  gd=$(git rev-parse --git-dir 2>/dev/null)
  if [[ -e "$gd/MERGE_HEAD" || -d "$gd/rebase-merge" || -d "$gd/rebase-apply" || -e "$gd/CHERRY_PICK_HEAD" ]]; then
    error "Refusing to create a WIP commit while a merge/rebase/cherry-pick is in progress"
    hint "Finish or 'hanif undo' the in-progress operation first"
    return 1
  fi

  if git diff --quiet HEAD 2>/dev/null && git diff --cached --quiet 2>/dev/null && \
     [[ -z "$(git ls-files --others --exclude-standard 2>/dev/null)" ]]; then
    info "Nothing to WIP — working tree is clean"
    return 0
  fi

  local msg="WIP"
  if [[ $# -gt 0 ]]; then
    msg="WIP: $*"
  else
    msg="WIP: $(date +'%Y-%m-%d %H:%M:%S')"
  fi

  step "Staging" "all changes"
  git add -A || { error "git add failed"; return 1; }
  step "Committing" "$msg"
  if git commit -m "$msg" --no-verify; then
    success "Parked as WIP"
    hint "Restore with: hanif unwip"
  else
    error "git commit failed"
    return 1
  fi
}

unwip_command() {
  case "${1:-}" in
    help|--help|-h)
      show_wip_help
      return 0
      ;;
  esac

  is_git_repo || { error "Not inside a git repository"; return 1; }

  local last
  last=$(git log -1 --pretty=%s 2>/dev/null) || {
    error "No commits in this repository"
    return 1
  }
  if [[ "$last" != WIP* ]]; then
    error "HEAD is not a WIP commit (subject: '$last')"
    hint "unwip only undoes commits whose subject starts with 'WIP'"
    return 1
  fi

  step "Reverting" "$last"
  if git reset --soft HEAD~1; then
    success "WIP commit undone (changes restored to staged state)"
    hint "Run 'git status' to see what's staged, or 'git reset' to unstage"
  else
    error "git reset --soft HEAD~1 failed"
    return 1
  fi
}

show_wip_help() {
  print_banner "Park / Restore Work In Progress"
  cat <<'EOF'

DESCRIPTION
  hanif wip stages everything in the working tree (including
  untracked files) and creates a single commit whose message
  begins with "WIP:". Use it to safely switch branches or step
  away mid-task. Pre-commit hooks are skipped (--no-verify).

  hanif unwip is the inverse: if HEAD's commit message starts
  with "WIP", it soft-resets one commit so all the changes are
  back in your index, ready to keep working on.

USAGE
  hanif wip                Park current changes as "WIP: <timestamp>"
  hanif wip <message>      Park as "WIP: <message>"
  hanif unwip              Undo the last WIP commit (soft reset)
  hanif wip help           Show this help

EXAMPLES
  hanif wip
  hanif wip refactor in progress
  hanif unwip

NOTES
  • Refuses to create a WIP commit while a merge/rebase/cherry-pick
    is in progress — those need to be finished or aborted first.
  • unwip refuses unless HEAD's subject begins with "WIP" so you
    can't accidentally undo a real commit.

EOF
}
