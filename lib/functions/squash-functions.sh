#!/usr/bin/env bash

# git-squash-from
# A CLI tool to squash Git commits interactively based on user input

set -euo pipefail

# Squash commits interactively
git_squash_from() {
  local count=$1

  if [ -z "$count" ] || ! echo "$count" | grep -Eq '^[0-9]+$'; then
    error "Please provide a valid numeric count."
    exit 1
  fi

  i=0
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

  echo "📜 Select a commit to squash everything into:"
  for j in $(seq 1 $i); do
    echo "$j) ${commits[j]}"
  done

  while true; do
    printf "Enter number [1-$i]: "
    read choice
    if echo "$choice" | grep -Eq "^[0-9]+$" && [ "$choice" -ge 1 ] && [ "$choice" -le "$i" ]; then
      base_hash=$(echo "${commits[choice]}" | awk '{print substr($1, 1, 7)}')
      
      # Extract selected commit's message for prompt
      selected_commit_msg=$(git log -1 --format='%s' "$base_hash")
      
      # Prompt user for custom message
      echo ""
      echo "💬 Enter custom message for squashed commit"
      echo "   (Press Enter to use: \"$selected_commit_msg\")"
      printf "Message: "
      read custom_msg
      
      # Trim whitespace from custom message
      custom_msg=$(echo "$custom_msg" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
      
      # Check if the selected commit is the root commit (has no parent).
      # Only use --root rebase when the commit genuinely has no parent,
      # not just because it's the last item in the displayed list.
      is_root_commit=$(git cat-file -p "$base_hash" | grep -c '^parent ' || true)
      if [ "$is_root_commit" -eq 0 ]; then
        info "Squashing all commits from the root..."
        if [ -n "$custom_msg" ]; then
          # Custom message: all commits get * hash format
          commit_message="$custom_msg"$'\n'"$(git log --format='%h %B' --reverse --all | awk '/^[0-9a-f]+ / {sub(/^/, "* "); print; next} NF==0 {next} {print}')"
        else
          # Default: first commit without hash, rest with * hash
          commit_message=$(git log --format='%h %B' --reverse --all | awk 'NR==1 {sub(/^[^ ]* /, ""); print; next} /^[0-9a-f]+ / {sub(/^/, "* "); print; next} NF==0 {next} {print}')
        fi
        rebase_cmd="git rebase -i --root"
      else
        info "Squashing commits from ${base_hash}^ to HEAD..."
        if [ -n "$custom_msg" ]; then
          # Custom message: all commits get * hash format
          commit_message="$custom_msg"$'\n'"$(git log --format='%h %B' --reverse "$base_hash^..HEAD" | awk '/^[0-9a-f]+ / {sub(/^/, "* "); print; next} NF==0 {next} {print}')"
        else
          # Default: first commit without hash, rest with * hash
          commit_message=$(git log --format='%h %B' --reverse "$base_hash^..HEAD" | awk 'NR==1 {sub(/^[^ ]* /, ""); print; next} /^[0-9a-f]+ / {sub(/^/, "* "); print; next} NF==0 {next} {print}')
        fi
        rebase_cmd="git rebase -i ${base_hash}^"
      fi

      # Create temp script for GIT_SEQUENCE_EDITOR to squash all except the first
      seq_script=$(mktemp)
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

      # Start rebase with interactive squashing
      GIT_SEQUENCE_EDITOR="$seq_script" $rebase_cmd

      rm -f "$seq_script"

      # Check for paused rebase and inject commit message
      if [ $? -eq 0 ]; then
        # Write commit message to temp file to preserve formatting
        msg_file=$(mktemp)
        cat > "$msg_file" <<EOF
$commit_message
EOF

        git commit --amend -F "$msg_file" >/dev/null 2>&1
        rm -f "$msg_file"

        if [ -d ".git/rebase-merge" ] || [ -d ".git/rebase-apply" ]; then
          git rebase --continue >/dev/null 2>&1
        fi

        success "Squash complete!"
      fi

      break
    else
      warning "Invalid selection. Try again."
    fi
  done
}
