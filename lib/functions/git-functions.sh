# Git Helper Functions for zsh
# Source this file in your ~/.zshrc

# gitup - Update main/master branch
# Usage: gitup
gitup() {
  is_git_repo || { error "Not a git repository"; return 1; }

  local target
  if git show-ref --verify --quiet refs/heads/main; then
    target="main"
  else
    target="master"
  fi

  step "Switching to $target"
  git checkout "$target" || return 1

  step "Fetching all remotes & pulling"
  git fetch --all && git pull
  success "$target is up to date"
}

# gitupall - Update all local branches with remote changes
# Usage: gitupall
# - Stashes local changes before updating
# - Fetches once and merges locally (avoids multiple password prompts)
# - Restores stash after completion
gitupall() {
  is_git_repo || { error "Not a git repository"; return 1; }

  local stash_created=false

  if [[ -n "$(git status --porcelain)" ]]; then
    step "Stashing local changes"
    git stash push -m "Auto stash before updating branches" && stash_created=true
  fi

  step "Fetching all remote updates"
  git fetch --all || { error "Failed to fetch"; return 1; }

  local current_branch=$(git rev-parse --abbrev-ref HEAD)

  info "Updating all local branches…"
  for branch in $(git branch --format='%(refname:short)'); do
    hint "──────────────────────────────"
    step "Updating" "$branch"

    git checkout "$branch" 2>/dev/null || { warning "Could not checkout $branch"; continue; }

    local upstream=$(git rev-parse --abbrev-ref "$branch@{upstream}" 2>/dev/null)
    if [[ -n "$upstream" ]]; then
      git merge --ff-only "$upstream" || warning "Could not fast-forward $branch"
    else
      info "No upstream configured for $branch"
    fi
  done

  step "Switching back to" "$current_branch"
  git checkout "$current_branch" 2>/dev/null

  success "All branches updated"

  if [[ "$stash_created" == "true" ]]; then
    step "Restoring stashed changes"
    git stash pop || warning "Stash pop failed — run 'git stash pop' manually"
  fi
}

# gitclean - Delete local branches that were removed from remote
# Usage: gitclean
# - Protects main, master, and current branch
# - Only deletes branches that have been removed from origin
gitclean() {
  is_git_repo || { error "Not a git repository"; return 1; }

  local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  [[ "$current_branch" == "HEAD" ]] && { warning "Detached HEAD state"; current_branch=""; }

  # Build the protected branch list, excluding empty entries (defensive against
  # the detached HEAD case above where current_branch is "").
  local protected_branches=("main" "master")
  [[ -n "$current_branch" ]] && protected_branches+=("$current_branch")

  step "Fetching updates from origin"
  git fetch -p || { error "Failed to fetch"; return 1; }

  info "Checking for local branches that were deleted from remote…"

  # Collect outcomes so we can render a summary table at the end.
  local -a summary_rows=()
  local deleted_count=0 kept_count=0 protected_count=0

  for branch in $(git for-each-ref --format='%(refname:short)' refs/heads/); do
    # Skip protected branches
    if [[ " ${protected_branches[*]} " =~ " ${branch} " ]]; then
      hint "  ⛔  Skipping protected branch: $branch"
      summary_rows+=("$(printf '%s\t%s\t%s' "$branch" "protected" "kept (protected)")")
      protected_count=$((protected_count + 1))
      continue
    fi

    # Check if branch has upstream
    local upstream=$(git rev-parse --abbrev-ref "$branch@{upstream}" 2>/dev/null)
    if [[ -z "$upstream" ]]; then
      hint "  •  Keeping local-only branch: $branch"
      summary_rows+=("$(printf '%s\t%s\t%s' "$branch" "local-only" "kept (no upstream)")")
      kept_count=$((kept_count + 1))
      continue
    fi

    # Check if upstream still exists (using local refs after fetch -p)
    if ! git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
      warning "Deleting branch (gone from remote): $branch"
      git branch -D "$branch"
      summary_rows+=("$(printf '%s\t%s\t%s' "$branch" "gone" "deleted")")
      deleted_count=$((deleted_count + 1))
    else
      hint "  ✓  Keeping active branch: $branch"
      summary_rows+=("$(printf '%s\t%s\t%s' "$branch" "active" "kept")")
      kept_count=$((kept_count + 1))
    fi
  done

  # Render summary table.
  if [[ ${#summary_rows[@]} -gt 0 ]]; then
    echo ""
    print_banner "Branch Cleanup Summary"
    echo ""
    printf '%s\n' "${summary_rows[@]}" | render_table "BRANCH|UPSTREAM|RESULT"
    echo ""
    success "Done — $deleted_count deleted, $kept_count kept, $protected_count protected"
  fi
}

# newfeature - Create a new branch with smart naming
# Usage: newfeature [--prefix <p> | --no-prefix] <description>
#        newfeature "TICKET-123: description"
#
# The branch prefix defaults to "feature" and is resolved in this order:
#   1. --prefix <p> / -p <p> / --no-prefix   (this invocation only)
#   2. $HANIF_NF_PREFIX                      (persist with: hanif env set)
#   3. "feature"
#
# Examples:
#   newfeature "add user authentication"
#     → creates: feature/add_user_authentication
#
#   newfeature "OM-755: fix login bug"
#     → creates: feature/OM-755_fix_login_bug
#
#   newfeature --prefix hotfix "OM-755: fix login bug"
#     → creates: hotfix/OM-755_fix_login_bug
#
#   newfeature --no-prefix "spike idea"
#     → creates: spike_idea
newfeature() {
  is_git_repo || { error "Not a git repository"; return 1; }

  # ---- Leading flags -----------------------------------------------------
  # Parsed here rather than only in the command handler so the exported
  # ``newfeature`` shell function behaves identically to ``hanif nf``. Parsing
  # stops at the first non-flag word, so the description itself may still
  # contain anything — including a literal "--prefix" — beyond that point.
  local prefix="${HANIF_NF_PREFIX-feature}"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prefix|-p)
        if [[ $# -lt 2 ]]; then
          error "Missing value for $1"
          hint "  newfeature --prefix hotfix 'OM-755: fix login bug'"
          return 1
        fi
        prefix="$2"
        shift 2
        ;;
      --no-prefix)
        prefix=""
        shift
        ;;
      --)
        shift
        break
        ;;
      *)
        break
        ;;
    esac
  done

  if [[ -z "${1:-}" ]]; then
    error "Usage: newfeature [--prefix <p>|--no-prefix] <description>"
    hint "  newfeature add login form"
    hint "  newfeature 'TICKET-123: add login form'"
    return 1
  fi

  # Join the remaining words so quoting stays optional.
  local input="$*"

  # Normalise the prefix: drop a trailing slash (exactly one is added below)
  # and reject anything git would not accept inside a ref path.
  prefix="${prefix%/}"
  if [[ -n "$prefix" && ! "$prefix" =~ ^[A-Za-z0-9._/-]+$ ]]; then
    error "Invalid branch prefix: $prefix"
    hint "  Use letters, numbers and . _ / - only (e.g. --prefix hotfix)"
    return 1
  fi

  # Step 1: Extract optional ticket number from start of input.
  # Matches patterns like: OM-755, JIRA-123, ABC-42
  # Example: "OM-755: fix bug" → ticket="OM-755"
  local ticket
  ticket=$(printf '%s' "$input" | grep -oE '^[A-Za-z]+-[0-9]+' || true)

  # Step 2: Get description (remove the ticket if one was found). Parameter
  # expansion rather than sed, so no part of the input is ever interpreted as
  # a regular expression.
  local description="${input#"$ticket"}"

  # Step 3: Slugify. sanitize_branch_name (lib/utils/common.sh) is the shared
  # implementation: it turns disallowed characters into word separators,
  # collapses runs, trims and lowercases.
  local clean
  clean=$(sanitize_branch_name "$description")

  # Step 4: Build the name. The ticket keeps its original case so the branch
  # still matches the ID in Jira / Azure Boards.
  local branch_name="$clean"
  if [[ -n "$ticket" ]]; then
    if [[ -n "$clean" ]]; then
      branch_name="${ticket}_${clean}"
    else
      branch_name="$ticket"
    fi
  fi

  # A description made only of punctuation sanitizes away to nothing; without
  # this we would hand git a bare "feature/" and surface a cryptic git error.
  if [[ -z "$branch_name" ]]; then
    error "Description contains no usable characters: $input"
    hint "  Include at least one letter or number, e.g. 'OM-755: fix login bug'"
    return 1
  fi

  [[ -n "$prefix" ]] && branch_name="${prefix}/${branch_name}"

  # Step 5: Enforce max length (60 chars) to keep branch names reasonable,
  # trimming back to the last word boundary instead of cutting mid-word.
  if [[ ${#branch_name} -gt 60 ]]; then
    branch_name="${branch_name:0:60}"
    local trimmed="${branch_name%_*}"
    # Only trim back if a boundary exists after the prefix, so we can never
    # reduce the name to just the prefix.
    if [[ "$trimmed" != "$branch_name" && -n "${trimmed##*/}" ]]; then
      branch_name="$trimmed"
    fi
  fi

  # Drop a separator left dangling by truncation.
  branch_name="${branch_name%[-_]}"

  step "Creating branch" "$branch_name"
  git checkout -b "$branch_name"
}

# gitrebase - Rebase current branch onto updated base branch
# Usage: gitrebase main
# - Updates the base branch first
# - Stashes local changes before rebase
# - Restores stash after successful rebase
gitrebase() {
  is_git_repo || { error "Not a git repository"; return 1; }

  if [[ -z "${1:-}" ]]; then
    error "Usage: gitrebase <base-branch>"
    hint "  Example: gitrebase main"
    return 1
  fi

  local base_branch="$1"
  local current_branch=$(git rev-parse --abbrev-ref HEAD)
  
  # Validations
  [[ "$current_branch" == "HEAD" ]] && { error "Cannot rebase from detached HEAD"; return 1; }
  [[ "$current_branch" == "$base_branch" ]] && { error "Cannot rebase a branch onto itself"; return 1; }
  git show-ref --verify --quiet "refs/heads/$base_branch" || { error "Base branch '$base_branch' does not exist"; return 1; }

  # Stash if needed
  local stash_created=false
  if [[ -n "$(git status --porcelain)" ]]; then
    step "Stashing local changes"
    git stash push -m "Auto stash before rebase with $base_branch" && stash_created=true || { error "Failed to stash"; return 1; }
  fi

  # Update base branch
  step "Updating base branch" "'$base_branch'"
  git checkout "$base_branch" || { [[ "$stash_created" == "true" ]] && git stash pop; return 1; }
  
  if ! git fetch --all; then
    error "Failed to fetch updates"
    git checkout "$current_branch" 2>/dev/null
    [[ "$stash_created" == "true" ]] && git stash pop
    return 1
  fi
  
  git pull --ff-only || warning "Could not fast-forward $base_branch"
  
  # Return to current branch
  step "Switching back to" "'$current_branch'"
  git checkout "$current_branch" || { [[ "$stash_created" == "true" ]] && git stash pop; return 1; }

  # Rebase
  step "Rebasing" "'$current_branch' onto '$base_branch'"
  if git rebase "$base_branch"; then
    success "Rebase completed successfully"
  else
    warning "Rebase conflicts — resolve and run: git rebase --continue"
    info "Or abort with: git rebase --abort"
    [[ "$stash_created" == "true" ]] && info "Run 'git stash pop' after resolving rebase"
    return 1
  fi

  # Restore stash
  if [[ "$stash_created" == "true" ]]; then
    step "Restoring stashed changes"
    git stash pop || warning "Stash pop failed — run 'git stash pop' manually"
  fi

  success "Done — '$current_branch' rebased onto '$base_branch'"
}

# gitamend - Amend the last commit with staged changes
# Usage: gitamend          (keeps existing message, stages all changes)
#        gitamend "msg"    (updates commit message)
# - Stages all changes, amends last commit with current date
# - Useful for small fixes/typos you want folded into the last commit
gitamend() {
  is_git_repo || { error "Not a git repository"; return 1; }

  # Stage all changes
  git add -A

  local has_changes=true
  if [[ -z "$(git diff --cached --name-only)" ]]; then
    has_changes=false
  fi

  if [[ -n "${1:-}" ]]; then
    # Message provided: amend even without changes (to update message)
    git commit --amend --date=now --no-verify -m "$*"
  elif [[ "$has_changes" = true ]]; then
    git commit --amend --date=now --no-edit --no-verify
  else
    warning "No changes to amend and no message provided"
    return 1
  fi

  success "Amended last commit"
}

# gitignore - Add a path to .gitignore and remove it from git tracking
# Usage: gitignore <path>
# - Creates .gitignore if it doesn't exist
# - Appends path to .gitignore (avoids duplicates)
# - Removes path from git index (keeps file on disk)
gitignore_add() {
  is_git_repo || { error "Not a git repository"; return 1; }

  if [[ -z "${1:-}" ]]; then
    error "Usage: hanif gi <path>"
    hint "  Example: hanif gi .env"
    hint "  Example: hanif gi node_modules/"
    return 1
  fi

  local path="$1"

  # Create .gitignore if it doesn't exist
  if [[ ! -f .gitignore ]]; then
    info "Creating .gitignore file…"
    touch .gitignore
    success "Created .gitignore"
  fi

  # Check if path is already in .gitignore
  if grep -qxF "$path" .gitignore 2>/dev/null; then
    warning "'$path' is already in .gitignore"
  else
    # Append path to .gitignore
    echo "$path" >> .gitignore
    success "Added '$path' to .gitignore"
  fi

  # Remove from git index (keep file on disk)
  if git ls-files --error-unmatch "$path" >/dev/null 2>&1; then
    info "Removing '$path' from git index…"
    git rm -r --cached "$path" >/dev/null 2>&1
    success "Removed '$path' from git tracking (file kept on disk)"
  else
    info "'$path' is not currently tracked by git"
  fi

  echo ""
  info "Next steps:"
  hint "  1. Review changes: git status"
  hint "  2. Commit:         git commit -m \"Add $path to .gitignore\""
}