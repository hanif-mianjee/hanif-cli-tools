#!/usr/bin/env bash
#
# stash-functions.sh — implementation of `hanif stash`.

_HANIF_STASH_INDEX_RE='^[0-9]+$'

# Count stashes.
_hanif_stash_count() {
  git stash list 2>/dev/null | wc -l | tr -d ' '
}

# Validate a stash index (numeric, in range). Echoes nothing on success,
# error and returns 1 on failure.
_hanif_stash_validate_index() {
  local idx="$1" count
  if [[ ! "$idx" =~ $_HANIF_STASH_INDEX_RE ]]; then
    error "Invalid stash index: $idx (must be a non-negative integer)"
    return 1
  fi
  count=$(_hanif_stash_count)
  if (( idx >= count )); then
    error "No such stash: stash@{$idx} (have $count stash(es))"
    return 1
  fi
}

# Render the stash list as a numbered table. Returns 1 if no stashes.
_hanif_stash_render_list() {
  local list
  list=$(git stash list 2>/dev/null)
  if [[ -z "$list" ]]; then
    info "No stashes"
    return 1
  fi
  # Each line: stash@{N}: WIP on <branch>: <hash> <subject>
  # We split into N | branch | message.
  echo "$list" | awk -F': ' '{
    # $1 = stash@{N}, $2 = "WIP on <branch>" or "On <branch>", rest = subject
    n = $1; sub(/stash@\{/, "", n); sub(/\}/, "", n)
    branch = $2; sub(/^WIP on /, "", branch); sub(/^On /, "", branch)
    subj = ""
    for (i = 3; i <= NF; i++) {
      subj = subj (i==3 ? "" : ": ") $i
    }
    # Strip a leading short hash like "a1b2c3d " from the subject.
    sub(/^[0-9a-f]{6,40} /, "", subj)
    if (subj == "") subj = "(no message)"
    printf "%s\t%s\t%s\n", n, branch, subj
  }' | render_table "#|BRANCH|MESSAGE"
}

hanif_stash() {
  is_git_repo || { error "Not inside a git repository"; return 1; }

  local sub="${1:-list}"
  shift 2>/dev/null || true

  case "$sub" in
    save|push)
      local name="$*"
      if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null && \
         [[ -z "$(git ls-files --others --exclude-standard 2>/dev/null)" ]]; then
        info "Nothing to stash — working tree is clean"
        return 0
      fi
      step "Stashing" "${name:-(no message)}"
      local -a cmd=(git stash push -u)
      if [[ -n "$name" ]]; then
        cmd+=(-m "$name")
      fi
      if "${cmd[@]}"; then
        success "Stashed"
        hint "Restore with: hanif stash pop"
      else
        error "git stash failed"
        return 1
      fi
      ;;
    list|ls)
      _hanif_stash_render_list || true
      ;;
    show)
      local idx="${1:-0}"
      _hanif_stash_validate_index "$idx" || return 1
      git stash show -p "stash@{$idx}"
      ;;
    pop|drop)
      local action="$sub"
      local idx="${1:-}"
      local count
      count=$(_hanif_stash_count)
      if (( count == 0 )); then
        info "No stashes"
        return 0
      fi
      if [[ -z "$idx" ]]; then
        if (( count == 1 )); then
          idx=0
        else
          info "Multiple stashes — pick one:"
          _hanif_stash_render_list
          local prompt_str
          prompt_str=$(_hanif_render 1 "${YELLOW}?${NC}  Stash # to ${action} ${DIM}[0-$((count-1))]${NC}: ")
          read -r -p "$prompt_str" idx
        fi
      fi
      _hanif_stash_validate_index "$idx" || return 1

      if [[ "$action" == drop ]]; then
        if ! confirm "Drop stash@{$idx} permanently?"; then
          info "Cancelled"
          return 0
        fi
        git stash drop "stash@{$idx}" && success "Dropped stash@{$idx}" \
          || { error "git stash drop failed"; return 1; }
      else
        if git stash pop "stash@{$idx}"; then
          success "Popped stash@{$idx}"
        else
          error "git stash pop failed (likely a merge conflict — resolve and continue)"
          return 1
        fi
      fi
      ;;
    *)
      error "Unknown stash subcommand: $sub"
      echo ""
      show_stash_help
      return 1
      ;;
  esac
}
