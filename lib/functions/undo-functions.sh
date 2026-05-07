#!/usr/bin/env bash
#
# undo-functions.sh — implementation of `hanif undo`.

# Strict confirmation — requires literal "yes". Used for destructive ops.
_hanif_undo_confirm_destructive() {
  local prompt="$1"
  local response
  local prompt_str
  prompt_str=$(_hanif_render 1 "${RED}!${NC}  ${prompt} ${DIM}(type 'yes' to confirm)${NC}: ")
  read -r -p "$prompt_str" response
  [[ "$response" == "yes" ]]
}

# Build the menu of available actions for the current repo state. Echoes
# one "id|label" per line.
_hanif_undo_actions() {
  local gd
  gd=$(git rev-parse --git-dir 2>/dev/null) || return 1

  if [[ -d "$gd/rebase-merge" || -d "$gd/rebase-apply" ]]; then
    echo "abort-rebase|Abort the in-progress rebase (git rebase --abort)"
  fi
  if [[ -e "$gd/MERGE_HEAD" ]]; then
    echo "abort-merge|Abort the in-progress merge (git merge --abort)"
  fi
  if [[ -e "$gd/CHERRY_PICK_HEAD" ]]; then
    echo "abort-cherry|Abort the in-progress cherry-pick (git cherry-pick --abort)"
  fi
  if git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
    echo "soft-reset|Undo the last commit, KEEP changes staged (git reset --soft HEAD~1)"
    echo "hard-reset|Undo the last commit, DISCARD changes (git reset --hard HEAD~1)"
  fi
  if ! git diff --cached --quiet 2>/dev/null; then
    echo "unstage|Unstage all files (git reset HEAD)"
  fi
  if ! git diff --quiet 2>/dev/null; then
    echo "discard-unstaged|DISCARD all unstaged changes (git checkout -- .)"
  fi
}

hanif_undo() {
  is_git_repo || { error "Not inside a git repository"; return 1; }

  local actions
  actions=$(_hanif_undo_actions)
  if [[ -z "$actions" ]]; then
    info "Nothing to undo — working tree is clean and there is no in-progress operation"
    return 0
  fi

  print_banner "Undo Menu"
  echo ""
  local -a ids=() labels=()
  local id label line
  while IFS='|' read -r id label; do
    [[ -z "$id" ]] && continue
    ids+=("$id")
    labels+=("$label")
  done <<< "$actions"

  local i
  for ((i = 0; i < ${#ids[@]}; i++)); do
    printf '  %d) %s\n' "$((i + 1))" "${labels[i]}"
  done
  printf '  q) cancel\n'
  echo ""

  local choice prompt_str
  prompt_str=$(_hanif_render 1 "${YELLOW}?${NC}  Choose an action ${DIM}[1-${#ids[@]} or q]${NC}: ")
  read -r -p "$prompt_str" choice
  case "$choice" in
    q|Q|"") info "Cancelled"; return 0 ;;
  esac
  if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#ids[@]} )); then
    error "Invalid choice: $choice"
    return 1
  fi

  local action="${ids[choice-1]}"
  case "$action" in
    abort-rebase)
      step "Aborting" "rebase"
      git rebase --abort && success "Rebase aborted" || { error "Failed"; return 1; }
      ;;
    abort-merge)
      step "Aborting" "merge"
      git merge --abort && success "Merge aborted" || { error "Failed"; return 1; }
      ;;
    abort-cherry)
      step "Aborting" "cherry-pick"
      git cherry-pick --abort && success "Cherry-pick aborted" || { error "Failed"; return 1; }
      ;;
    soft-reset)
      local subj
      subj=$(git log -1 --pretty=%s)
      if confirm "Undo last commit '$subj' (changes will be staged)?"; then
        git reset --soft HEAD~1 && success "Last commit undone (changes staged)" \
          || { error "Failed"; return 1; }
      else
        info "Cancelled"
      fi
      ;;
    hard-reset)
      local subj
      subj=$(git log -1 --pretty=%s)
      warning "This will permanently discard the changes in commit '$subj'"
      if _hanif_undo_confirm_destructive "Permanently discard last commit?"; then
        git reset --hard HEAD~1 && success "Last commit discarded" \
          || { error "Failed"; return 1; }
      else
        info "Cancelled"
      fi
      ;;
    unstage)
      if confirm "Unstage all currently-staged files?"; then
        git reset HEAD >/dev/null && success "All files unstaged" \
          || { error "Failed"; return 1; }
      else
        info "Cancelled"
      fi
      ;;
    discard-unstaged)
      warning "This will permanently discard all unstaged changes in the working tree"
      if _hanif_undo_confirm_destructive "Permanently discard unstaged changes?"; then
        git checkout -- . && success "Unstaged changes discarded" \
          || { error "Failed"; return 1; }
      else
        info "Cancelled"
      fi
      ;;
    *)
      error "Unknown action: $action"
      return 1
      ;;
  esac
}
