#!/usr/bin/env bash
#
# squash-functions.sh
#
# Interactive Git commit squashing engine. Used by ``lib/commands/squash.sh``.

set -euo pipefail

# git_squash_from <count>
#
# Show the last <count> commits, ask the user which one to squash everything
# into, ask for an optional new message, then run an interactive rebase that
# squashes all subsequent commits into the chosen base.
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

  echo "📜 Select a commit to squash everything into:"
  for j in $(seq 1 $i); do
    echo "$j) ${commits[j]}"
  done

  while true; do
    printf "Enter number [1-%s]: " "$i"
    read -r choice
    if echo "$choice" | grep -Eq "^[0-9]+$" && [ "$choice" -ge 1 ] && [ "$choice" -le "$i" ]; then
      local base_hash
      base_hash=$(echo "${commits[choice]}" | awk '{print substr($1, 1, 7)}')

      # Validate the hash strictly — defensive against any future changes to
      # how ``commits`` is populated. The hash MUST match a 7-hex-character
      # pattern; reject anything else before passing it to git.
      if ! [[ "$base_hash" =~ ^[0-9a-fA-F]{7}$ ]]; then
        error "Invalid commit hash extracted: '$base_hash'"
        exit 1
      fi

      local selected_commit_msg
      selected_commit_msg=$(git log -1 --format='%s' "$base_hash")

      echo ""
      echo "💬 Enter custom message for squashed commit"
      echo "   (Press Enter to use: \"$selected_commit_msg\")"
      printf "Message: "
      read -r custom_msg

      # Trim whitespace and surrounding quotes from the custom message.
      custom_msg=$(echo "$custom_msg" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/^"\(.*\)"$/\1/; s/^'"'"'\(.*\)'"'"'$/\1/')

      # Determine if the selected commit is a true root commit (no parent).
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

      # Invoke the rebase as an array (no shell-string eval). Capture
      # rebase status without tripping ``set -e``.
      local rebase_ok=true
      GIT_SEQUENCE_EDITOR="$seq_script" "${rebase_cmd[@]}" || rebase_ok=false

      rm -f "$seq_script"

      if [ "$rebase_ok" = true ]; then
        # Write the final commit message via -F to preserve all formatting,
        # using a securely-created temp file.
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
      else
        warning "Rebase encountered conflicts. Resolve them and run: git rebase --continue"
      fi

      break
    else
      warning "Invalid selection. Try again."
    fi
  done
}
