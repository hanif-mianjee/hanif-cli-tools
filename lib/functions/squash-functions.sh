#!/usr/bin/env bash
#
# squash-functions.sh
#
# Interactive Git commit squashing engine. Used by ``lib/commands/squash.sh``.
#
# Public entry points:
#   git_squash_from <count>            — interactive picker over last <count>
#   git_squash_from_hash <hash>        — squash <hash>..HEAD (skip picker)
#   git_squash_range <older> <newer>   — squash inclusive range, preserving
#                                        commits after <newer> via cherry-pick

set -euo pipefail

# _git_squash_validate_hash <ref>
#
# Resolve a user-supplied ref to a 7-char short hash if and only if it is a
# valid commit. Echoes the short hash on success, returns non-zero otherwise.
_git_squash_validate_hash() {
  local ref="$1"
  if ! git rev-parse --verify "${ref}^{commit}" >/dev/null 2>&1; then
    return 1
  fi
  git rev-parse --short=7 "$ref" 2>/dev/null
}

# _git_squash_prompt_message <base_hash>
#
# Show the standard "custom message" prompt used by the picker flow, using
# the selected commit's subject as the default. Echoes the (trimmed) custom
# message — empty string means "use selected commit's message".
_git_squash_prompt_message() {
  local base_hash="$1"
  local selected_commit_msg
  selected_commit_msg=$(git log -1 --format='%s' "$base_hash")

  echo "" >&2
  _hanif_render 1 "${BOLD}${MAGENTA}💬  Enter custom message for squashed commit${NC}" >&2; printf '\n' >&2
  hint "   (Press Enter to use: \"$selected_commit_msg\")" >&2
  local msg_prompt
  msg_prompt=$(_hanif_render 1 "${YELLOW}?${NC}  Message: ")
  printf '%s' "$msg_prompt" >&2
  local custom_msg
  read -r custom_msg

  # Trim whitespace and surrounding quotes.
  custom_msg=$(echo "$custom_msg" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/^"\(.*\)"$/\1/; s/^'"'"'\(.*\)'"'"'$/\1/')
  printf '%s' "$custom_msg"
}

# _git_squash_run_from_base <base_hash> [custom_msg]
#
# Core engine: squash every commit from <base_hash> through HEAD (inclusive)
# into a single commit. <base_hash> must already be validated. If
# <custom_msg> is empty, the selected commit's own subject becomes the first
# line of the squashed message.
#
# Handles true root commits (no parent) via ``git rebase -i --root``.
# Returns 0 on success, non-zero on rebase conflict.
_git_squash_run_from_base() {
  local base_hash="$1"
  local custom_msg="${2:-}"

  # Defensive re-validation of the hash before passing to git.
  if ! [[ "$base_hash" =~ ^[0-9a-fA-F]{7,40}$ ]]; then
    error "Invalid commit hash: '$base_hash'"
    return 1
  fi

  local is_root_commit
  is_root_commit=$(git cat-file -p "$base_hash" | grep -c '^parent ' || true)

  local commit_message
  local -a rebase_cmd
  if [ "$is_root_commit" -eq 0 ]; then
    info "Squashing all commits from the root..."
    if [ -n "$custom_msg" ]; then
      commit_message="$custom_msg"$'\n'"$(git log --format='%h %B' --reverse --all | awk '/^[0-9a-f]+ / {sub(/^/, "* "); print; next} NF==0 {next} {print}')"
    else
      commit_message=$(git log --format='%h %B' --reverse --all | awk 'NR==1 {sub(/^[^ ]* /, ""); print; next} /^[0-9a-f]+ / {sub(/^/, "* "); print; next} NF==0 {next} {print}')
    fi
    rebase_cmd=(git rebase -i --root)
  else
    info "Squashing commits from ${base_hash}^ to HEAD..."
    if [ -n "$custom_msg" ]; then
      commit_message="$custom_msg"$'\n'"$(git log --format='%h %B' --reverse "$base_hash^..HEAD" | awk '/^[0-9a-f]+ / {sub(/^/, "* "); print; next} NF==0 {next} {print}')"
    else
      commit_message=$(git log --format='%h %B' --reverse "$base_hash^..HEAD" | awk 'NR==1 {sub(/^[^ ]* /, ""); print; next} /^[0-9a-f]+ / {sub(/^/, "* "); print; next} NF==0 {next} {print}')
    fi
    rebase_cmd=(git rebase -i "${base_hash}^")
  fi

  # Build a temp script for GIT_SEQUENCE_EDITOR that turns every "pick"
  # line after the first into "squash". Use mktemp securely.
  local seq_script
  seq_script=$(mktemp)
  chmod 700 "$seq_script"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    cat > "$seq_script" <<'EOSCRIPT'
#!/bin/bash
sed -i '' '2,$s/^pick /squash /' "$1"
EOSCRIPT
  else
    cat > "$seq_script" <<'EOSCRIPT'
#!/bin/bash
sed -i '2,$s/^pick /squash /' "$1"
EOSCRIPT
  fi
  chmod +x "$seq_script"

  local rebase_ok=true
  GIT_SEQUENCE_EDITOR="$seq_script" "${rebase_cmd[@]}" || rebase_ok=false

  rm -f "$seq_script"

  if [ "$rebase_ok" = true ]; then
    local msg_file
    msg_file=$(mktemp)
    chmod 600 "$msg_file"
    printf '%s\n' "$commit_message" > "$msg_file"

    git commit --amend -F "$msg_file" >/dev/null 2>&1
    rm -f "$msg_file"

    if [ -d ".git/rebase-merge" ] || [ -d ".git/rebase-apply" ]; then
      git rebase --continue >/dev/null 2>&1
    fi

    success "Squash complete!"
    return 0
  else
    warning "Rebase encountered conflicts. Resolve them and run: git rebase --continue"
    return 1
  fi
}

# git_squash_from <count>
#
# Show the last <count> commits, ask the user which one to squash everything
# into, ask for an optional new message, then run the squash engine.
git_squash_from() {
  local count=$1

  if [ -z "$count" ] || ! echo "$count" | grep -Eq '^[0-9]+$'; then
    error "Please provide a valid numeric count."
    exit 1
  fi

  local i=0
  local -a commits
  while IFS= read -r line && [ "$i" -lt "$count" ]; do
    i=$((i + 1))
    commits[i]="$line"
  done <<EOF
$(git log --oneline --decorate -n "$count")
EOF

  if [ "$i" -eq 0 ]; then
    error "No commits found."
    exit 1
  fi

  echo ""
  _hanif_render 1 "${BOLD}${MAGENTA}📜  Select a commit to squash everything into:${NC}"; printf '\n'
  for j in $(seq 1 $i); do
    _hanif_render 1 "  ${CYAN}$(printf '%2d' "$j")${NC})  ${commits[j]}"; printf '\n'
  done
  echo ""

  while true; do
    local prompt_str
    prompt_str=$(_hanif_render 1 "${YELLOW}?${NC}  Enter number ${DIM}[1-$i]${NC}: ")
    printf '%s' "$prompt_str"
    read -r choice
    if echo "$choice" | grep -Eq "^[0-9]+$" && [ "$choice" -ge 1 ] && [ "$choice" -le "$i" ]; then
      local base_hash
      base_hash=$(echo "${commits[choice]}" | awk '{print substr($1, 1, 7)}')

      if ! [[ "$base_hash" =~ ^[0-9a-fA-F]{7}$ ]]; then
        error "Invalid commit hash extracted: '$base_hash'"
        exit 1
      fi

      local custom_msg
      custom_msg=$(_git_squash_prompt_message "$base_hash")

      _git_squash_run_from_base "$base_hash" "$custom_msg" || true
      break
    else
      warning "Invalid selection. Try again."
    fi
  done
}

# git_squash_from_hash <hash>
#
# Skip the picker: squash everything from <hash> through HEAD into a single
# commit. <hash> may be any ref/short/long hash; it is validated up front.
git_squash_from_hash() {
  local input_hash="$1"
  local base_hash

  if ! base_hash=$(_git_squash_validate_hash "$input_hash"); then
    error "'$input_hash' is not a valid commit in this repository."
    exit 1
  fi

  local subject
  subject=$(git log -1 --format='%s' "$base_hash")

  echo ""
  _hanif_render 1 "${BOLD}${MAGENTA}🎯  Squashing from commit:${NC}"; printf '\n'
  _hanif_render 1 "  ${CYAN}${base_hash}${NC}  ${subject}"; printf '\n'

  local custom_msg
  custom_msg=$(_git_squash_prompt_message "$base_hash")

  _git_squash_run_from_base "$base_hash" "$custom_msg" || true
}

# git_squash_range <older> <newer>
#
# Squash the inclusive range <older>..<newer> into a single commit, then
# replay any commits that came after <newer> on top via cherry-pick. Refuses
# to run with a dirty working tree or a detached HEAD.
git_squash_range() {
  local older_input="$1"
  local newer_input="$2"
  local older_hash newer_hash

  if ! older_hash=$(_git_squash_validate_hash "$older_input"); then
    error "'$older_input' is not a valid commit in this repository."
    exit 1
  fi
  if ! newer_hash=$(_git_squash_validate_hash "$newer_input"); then
    error "'$newer_input' is not a valid commit in this repository."
    exit 1
  fi

  if [ "$older_hash" = "$newer_hash" ]; then
    error "Older and newer hashes are the same commit. Use 'hanif squash <hash>' for a single hash."
    exit 1
  fi

  if ! git merge-base --is-ancestor "$older_hash" "$newer_hash"; then
    error "Older hash ($older_hash) must be an ancestor of newer hash ($newer_hash)."
    hint "   Pass the commits in <older> <newer> order."
    exit 1
  fi

  # Require a non-detached HEAD so we can safely reset/cherry-pick.
  local current_branch
  current_branch=$(git symbolic-ref --short -q HEAD || true)
  if [ -z "$current_branch" ]; then
    error "Range squash requires a checked-out branch (detached HEAD detected)."
    exit 1
  fi

  # Require a clean working tree.
  if ! git diff --quiet || ! git diff --cached --quiet; then
    error "Working tree is not clean. Commit or stash your changes before running a range squash."
    exit 1
  fi

  # Ensure newer is reachable from HEAD — otherwise reset would lose history.
  if ! git merge-base --is-ancestor "$newer_hash" HEAD; then
    error "Newer hash ($newer_hash) is not reachable from HEAD on branch '$current_branch'."
    exit 1
  fi

  # Capture commits AFTER newer up to HEAD (oldest first) for replay.
  local -a trailing_commits=()
  if [ "$(git rev-parse "$newer_hash")" != "$(git rev-parse HEAD)" ]; then
    while IFS= read -r c; do
      [ -n "$c" ] && trailing_commits+=("$c")
    done < <(git rev-list --reverse "${newer_hash}..HEAD")
  fi

  local trailing_count=${#trailing_commits[@]}
  local range_count
  range_count=$(git rev-list --count "${older_hash}^..${newer_hash}")

  echo ""
  _hanif_render 1 "${BOLD}${MAGENTA}🎯  Range squash plan:${NC}"; printf '\n'
  _hanif_render 1 "  • Squash ${CYAN}${range_count}${NC} commits from ${CYAN}${older_hash}${NC} through ${CYAN}${newer_hash}${NC}"; printf '\n'
  if [ "$trailing_count" -gt 0 ]; then
    _hanif_render 1 "  • Replay ${CYAN}${trailing_count}${NC} trailing commit(s) on top via cherry-pick"; printf '\n'
  fi

  local custom_msg
  custom_msg=$(_git_squash_prompt_message "$newer_hash")

  # Fast path: range ends at HEAD, no trailing commits to preserve.
  if [ "$trailing_count" -eq 0 ]; then
    _git_squash_run_from_base "$older_hash" "$custom_msg" || true
    return
  fi

  # Save current HEAD so the user can recover via reflog if anything goes wrong.
  local original_head
  original_head=$(git rev-parse HEAD)
  info "Original HEAD saved (for reflog recovery): $original_head"

  # Move branch tip to <newer> so the engine treats <newer> as HEAD.
  if ! git reset --hard "$newer_hash" >/dev/null 2>&1; then
    error "Failed to reset branch to $newer_hash."
    exit 1
  fi

  if ! _git_squash_run_from_base "$older_hash" "$custom_msg"; then
    error "Squash failed. To recover the original branch state, run:"
    hint "   git reset --hard $original_head"
    exit 1
  fi

  # Replay trailing commits in order.
  info "Replaying $trailing_count trailing commit(s) via cherry-pick..."
  local c
  for c in "${trailing_commits[@]}"; do
    if ! git cherry-pick "$c" >/dev/null 2>&1; then
      error "Cherry-pick failed for commit $c."
      hint "   Resolve conflicts, then run: git cherry-pick --continue"
      hint "   To restore the original branch state instead, run:"
      hint "   git cherry-pick --abort && git reset --hard $original_head"
      exit 1
    fi
  done

  success "Range squash complete! ($range_count commits squashed, $trailing_count replayed)"
}
