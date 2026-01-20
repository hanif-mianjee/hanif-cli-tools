# Git Helper Functions for zsh
# Source this file in your ~/.zshrc

# gitup - Update main/master branch
# Usage: gitup
gitup() {
  git rev-parse --git-dir >/dev/null 2>&1 || { echo "❌ Not a git repository"; return 1; }

  if git show-ref --verify --quiet refs/heads/main; then
    git checkout main || return 1
  else
    git checkout master || return 1
  fi
  
  git fetch --all && git pull
}

# gitupall - Update all local branches with remote changes
# Usage: gitupall
# - Stashes local changes before updating
# - Fetches once and merges locally (avoids multiple password prompts)
# - Restores stash after completion
gitupall() {
  git rev-parse --git-dir >/dev/null 2>&1 || { echo "❌ Not a git repository"; return 1; }

  local stash_created=false
  
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "Stashing local changes..."
    git stash push -m "Auto stash before updating branches" && stash_created=true
  fi

  echo "Fetching all remote updates..."
  git fetch --all || { echo "❌ Failed to fetch"; return 1; }

  local current_branch=$(git rev-parse --abbrev-ref HEAD)

  echo "Updating all local branches..."
  for branch in $(git branch --format='%(refname:short)'); do
    echo "--------------------------"
    echo "Updating branch: $branch"
    
    git checkout "$branch" 2>/dev/null || { echo "⚠️ Could not checkout $branch"; continue; }
    
    local upstream=$(git rev-parse --abbrev-ref "$branch@{upstream}" 2>/dev/null)
    if [[ -n "$upstream" ]]; then
      git merge --ff-only "$upstream" || echo "⚠️ Could not fast-forward $branch"
    else
      echo "ℹ️ No upstream configured for $branch"
    fi
  done

  echo "Switching back to $current_branch..."
  git checkout "$current_branch" 2>/dev/null

  echo "✨ All branches updated!"

  if [[ "$stash_created" == "true" ]]; then
    echo "Restoring stashed changes..."
    git stash pop || echo "⚠️ Stash pop failed - run 'git stash pop' manually"
  fi
}

# gitclean - Delete local branches that were removed from remote
# Usage: gitclean
# - Protects main, master, and current branch
# - Only deletes branches that have been removed from origin
gitclean() {
  git rev-parse --git-dir >/dev/null 2>&1 || { echo "❌ Not a git repository"; return 1; }

  local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  [[ "$current_branch" == "HEAD" ]] && { echo "⚠️ Detached HEAD state"; current_branch=""; }

  local protected_branches=("main" "master" "$current_branch")

  echo "Fetching updates from origin..."
  git fetch -p || { echo "❌ Failed to fetch"; return 1; }

  echo "🔍 Checking for local branches that were deleted from remote..."
  for branch in $(git for-each-ref --format='%(refname:short)' refs/heads/); do
    # Skip protected branches
    if [[ " ${protected_branches[*]} " =~ " ${branch} " ]]; then
      echo "⛔ Skipping protected branch: $branch"
      continue
    fi

    # Check if branch has upstream
    local upstream=$(git rev-parse --abbrev-ref "$branch@{upstream}" 2>/dev/null)
    if [[ -z "$upstream" ]]; then
      echo "🛑 Keeping local-only branch: $branch"
      continue
    fi

    # Check if upstream still exists (using local refs after fetch -p)
    if ! git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
      echo "🗑 Deleting branch (gone from remote): $branch"
      git branch -D "$branch"
    else
      echo "✔ Keeping active branch: $branch"
    fi
  done
}

# newfeature - Create a new feature branch with smart naming
# Usage: newfeature "description"
#        newfeature "TICKET-123: description"
# 
# Examples:
#   newfeature "add user authentication"
#     → creates: feature/add_user_authentication
#   
#   newfeature "OM-755: fix login bug"
#     → creates: feature/om-755_fix_login_bug
#   
#   newfeature "JIRA-123 Update API endpoints"
#     → creates: feature/jira-123_update_api_endpoints
newfeature() {
  git rev-parse --git-dir >/dev/null 2>&1 || { echo "❌ Not a git repository"; return 1; }

  if [ -z "$1" ]; then
    echo "❌ Usage: newfeature \"description\" or newfeature \"TICKET-123: description\""
    return 1
  fi

  # Step 1: Extract optional ticket number from start of input
  # Matches patterns like: OM-755, JIRA-123, ABC-42
  # Example: "OM-755: fix bug" → ticket="OM-755"
  local ticket=$(echo "$1" | grep -oE '^[A-Za-z]+-[0-9]+')
  
  # Step 2: Get description (remove ticket if it was found)
  # Example: "OM-755: fix bug" → description=": fix bug"
  # Example: "fix bug" → description="fix bug"
  local description="$1"
  [[ -n "$ticket" ]] && description=$(echo "$1" | sed "s/^$ticket//")
  
  # Step 3: Clean description to be git-branch-safe
  # - Keep only: letters, numbers, spaces, underscores, hyphens
  # - Convert spaces to underscores
  # Example: ": fix bug!" → "__fix_bug"
  local clean=$(echo "$description" | tr -cd '[:alnum:] _-' | tr ' ' '_')
  
  # Step 4: Normalize multiple underscores to single underscore
  # Example: "__fix_bug" → "_fix_bug"
  clean=$(echo "$clean" | sed 's/_\+/_/g')
  
  # Step 5: Trim leading/trailing underscores
  # Example: "_fix_bug" → "fix_bug"
  clean=$(echo "$clean" | sed 's/^_//; s/_$//')
  
  # Step 6: Convert to lowercase for consistency
  # Example: "Fix_Bug" → "fix_bug"
  clean=$(echo "$clean" | tr '[:upper:]' '[:lower:]')
  
  # Step 7: Build final branch name
  # With ticket: feature/om-755_fix_bug
  # Without ticket: feature/fix_bug
  local branch_name
  if [[ -n "$ticket" ]]; then
    # ticket=$(echo "$ticket" | tr '[:upper:]' '[:lower:]')  # lowercase ticket too
    branch_name="feature/${ticket}_${clean}"
  else
    branch_name="feature/${clean}"
  fi
  
  # Step 8: Enforce max length (60 chars) to keep branch names reasonable
  # Example: very long name → truncated to 60 chars
  branch_name=$(echo "$branch_name" | cut -c1-60)
  
  # Step 9: Final cleanup - remove trailing underscore if truncation created one
  # Example: "feature/om-755_very_long_name_" → "feature/om-755_very_long_name"
  branch_name=$(echo "$branch_name" | sed 's/_$//')

  echo "🚀 Creating branch: $branch_name"
  git checkout -b "$branch_name"
}

# gitrebase - Rebase current branch onto updated base branch
# Usage: gitrebase main
# - Updates the base branch first
# - Stashes local changes before rebase
# - Restores stash after successful rebase
gitrebase() {
  git rev-parse --git-dir >/dev/null 2>&1 || { echo "❌ Not a git repository"; return 1; }

  if [ -z "$1" ]; then
    echo "❌ Usage: gitrebase <base-branch>"
    echo "Example: gitrebase main"
    return 1
  fi

  local base_branch="$1"
  local current_branch=$(git rev-parse --abbrev-ref HEAD)
  
  # Validations
  [[ "$current_branch" == "HEAD" ]] && { echo "❌ Cannot rebase from detached HEAD"; return 1; }
  [[ "$current_branch" == "$base_branch" ]] && { echo "❌ Cannot rebase a branch onto itself"; return 1; }
  git show-ref --verify --quiet "refs/heads/$base_branch" || { echo "❌ Base branch '$base_branch' does not exist"; return 1; }

  # Stash if needed
  local stash_created=false
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "Stashing local changes..."
    git stash push -m "Auto stash before rebase with $base_branch" && stash_created=true || { echo "❌ Failed to stash"; return 1; }
  fi

  # Update base branch
  echo "Updating base branch '$base_branch'..."
  git checkout "$base_branch" || { [[ "$stash_created" == "true" ]] && git stash pop; return 1; }
  
  if ! git fetch --all; then
    echo "❌ Failed to fetch updates"
    git checkout "$current_branch" 2>/dev/null
    [[ "$stash_created" == "true" ]] && git stash pop
    return 1
  fi
  
  git pull --ff-only || echo "⚠️ Could not fast-forward $base_branch"
  
  # Return to current branch
  echo "Switching back to '$current_branch'..."
  git checkout "$current_branch" || { [[ "$stash_created" == "true" ]] && git stash pop; return 1; }

  # Rebase
  echo "Rebasing '$current_branch' onto '$base_branch'..."
  if git rebase "$base_branch"; then
    echo "✨ Rebase completed successfully!"
  else
    echo "⚠️ Rebase conflicts - resolve and run: git rebase --continue"
    echo "ℹ️ Or abort with: git rebase --abort"
    [[ "$stash_created" == "true" ]] && echo "ℹ️ Run 'git stash pop' after resolving rebase"
    return 1
  fi

  # Restore stash
  if [[ "$stash_created" == "true" ]]; then
    echo "Restoring stashed changes..."
    git stash pop || echo "⚠️ Stash pop failed - run 'git stash pop' manually"
  fi

  echo "✅ Done! '$current_branch' rebased onto '$base_branch'"
}