#!/usr/bin/env bash
#
# git-setup-functions.sh
#
# Implementation of `hanif gsetup` — one-shot setup for a new git
# profile. See `lib/commands/git-setup.sh` for the dispatcher and help.
#
# Design notes
# ------------
# • We never touch the real $HOME during tests. Callers can override the
#   resolved home with HANIF_GSETUP_HOME so the test suite can point at
#   a mktemp dir.
# • Every file is written via a tempfile + mv to avoid half-written
#   states; permissions are tightened immediately.
# • The block we append to ~/.gitconfig is delimited with marker
#   comments so re-running for the SAME profile updates in place
#   instead of stacking duplicates.
# • The SSH key is generated non-interactively with no passphrase.
#   Users who want a passphrase can run ssh-keygen -p afterwards;
#   we tell them how in the final summary.

# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------

# Resolved HOME for all paths we touch. Honours HANIF_GSETUP_HOME so tests
# can isolate the filesystem completely.
_hanif_gsetup_home() {
  if [[ -n "${HANIF_GSETUP_HOME:-}" ]]; then
    echo "$HANIF_GSETUP_HOME"
  else
    echo "$HOME"
  fi
}

_hanif_gsetup_ssh_key_path() {
  printf '%s/.ssh/id_ed25519_%s' "$(_hanif_gsetup_home)" "$1"
}

_hanif_gsetup_profile_gitconfig() {
  printf '%s/.gitconfig-%s' "$(_hanif_gsetup_home)" "$1"
}

_hanif_gsetup_root_gitconfig() {
  printf '%s/.gitconfig' "$(_hanif_gsetup_home)"
}

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

# Profile names: alnum, underscore, hyphen. Keep tight so the name is
# safe to embed in filenames AND in git config section headers.
_hanif_gsetup_valid_profile() {
  [[ "$1" =~ ^[A-Za-z0-9_-]+$ ]]
}

# Git is permissive about user.name (almost any UTF-8 is fine) but we
# reject empty strings and characters that would break a config line —
# specifically newlines and the surrounding double-quote we wrap it in.
_hanif_gsetup_valid_name() {
  local n="$1"
  [[ -n "$n" ]] || return 1
  [[ "$n" != *$'\n'* ]] || return 1
  [[ "$n" != *'"'* ]] || return 1
  return 0
}

# Conservative email validation — we just need "looks like an email".
# Accepts: localpart@domain.tld with the usual harmless characters.
# Rejects whitespace, quotes, and anything that would break a config line.
_hanif_gsetup_valid_email() {
  [[ "$1" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]
}

# Read a non-empty line from the user. Re-prompts on empty input or
# when the supplied validator fails. Result is left in
# _HANIF_GSETUP_PROMPT_VALUE so the caller doesn't need command
# substitution (which would swallow the prompt's stderr/stdin wiring).
#
#   $1 = prompt label
#   $2 = optional default (shown in [brackets]; accepted on empty input)
#   $3 = optional validator function name; called with the candidate as $1
#   $4 = optional error message shown when the validator rejects input
_hanif_gsetup_prompt() {
  local label="$1"
  local default="${2:-}"
  local validator="${3:-}"
  local err_msg="${4:-Invalid value, please try again.}"
  local response prompt_str

  while true; do
    if [[ -n "$default" ]]; then
      prompt_str=$(_hanif_render 1 "${YELLOW}?${NC}  ${label} ${DIM}[${default}]${NC}: ")
    else
      prompt_str=$(_hanif_render 1 "${YELLOW}?${NC}  ${label}: ")
    fi
    read -r -p "$prompt_str" response
    [[ -z "$response" && -n "$default" ]] && response="$default"

    if [[ -z "$response" ]]; then
      error "Value is required."
      continue
    fi

    if [[ -n "$validator" ]] && ! "$validator" "$response"; then
      error "$err_msg"
      continue
    fi

    _HANIF_GSETUP_PROMPT_VALUE="$response"
    return 0
  done
}

# ---------------------------------------------------------------------------
# File writers
# ---------------------------------------------------------------------------

# Write the per-profile gitconfig. Creates a tempfile, chmods 600,
# then moves into place. Backs up any existing file as <file>.bak.
_hanif_gsetup_write_profile_gitconfig() {
  local profile="$1" name="$2" email="$3" key_path="$4"
  local target
  target=$(_hanif_gsetup_profile_gitconfig "$profile")

  local tmp
  tmp=$(mktemp)
  chmod 600 "$tmp"

  # Quote name in double quotes; we already validated that it contains
  # no newline and no double-quote so this is safe.
  cat > "$tmp" <<EOF
# Managed by \`hanif gsetup\` — per-profile gitconfig for "${profile}".
# Loaded automatically by ~/.gitconfig via includeIf for repos under
# the profile's directory.
[user]
    name = ${name}
    email = ${email}
[core]
    sshCommand = ssh -i ${key_path} -o IdentitiesOnly=yes
EOF

  if [[ -f "$target" ]]; then
    cp "$target" "${target}.bak"
  fi
  mv "$tmp" "$target"
  chmod 600 "$target"
}

# Marker pair used to delimit the includeIf block we append to ~/.gitconfig.
# We embed the profile so multiple profiles get their own discrete blocks
# and re-runs for the same profile update in place.
_hanif_gsetup_begin_marker() { printf '# >>> hanif gsetup: %s >>>' "$1"; }
_hanif_gsetup_end_marker()   { printf '# <<< hanif gsetup: %s <<<' "$1"; }

# Append (or replace) the includeIf block for the given profile in
# the user's root ~/.gitconfig. Idempotent — re-running for the same
# profile rewrites the existing block in place.
_hanif_gsetup_write_root_include() {
  local profile="$1" repos_dir="$2" profile_cfg="$3"
  local root
  root=$(_hanif_gsetup_root_gitconfig)

  mkdir -p "$(dirname "$root")"
  touch "$root"

  local begin end
  begin=$(_hanif_gsetup_begin_marker "$profile")
  end=$(_hanif_gsetup_end_marker "$profile")

  local tmp
  tmp=$(mktemp)
  chmod 600 "$tmp"

  # Strip any existing block for this profile, keep everything else.
  awk -v b="$begin" -v e="$end" '
    $0 == b { skip=1; next }
    $0 == e { skip=0; next }
    !skip   { print }
  ' "$root" > "$tmp"

  # Ensure trailing newline before appending so we don't glue to an
  # unterminated last line. `$(tail -c1 ...)` strips trailing newlines,
  # so an empty result means the file already ends with a newline.
  if [[ -s "$tmp" ]] && [[ -n "$(tail -c1 "$tmp")" ]]; then
    printf '\n' >> "$tmp"
  fi

  {
    printf '%s\n' "$begin"
    printf '[includeIf "gitdir:%s/"]\n' "$repos_dir"
    printf '    path = %s\n' "$profile_cfg"
    printf '%s\n' "$end"
  } >> "$tmp"

  cp "$root" "${root}.bak"
  mv "$tmp" "$root"
  chmod 644 "$root"
}

# Generate an ed25519 SSH key. Honours HANIF_GSETUP_SKIP_KEYGEN=1 so
# the test suite doesn't shell out to real ssh-keygen.
_hanif_gsetup_generate_key() {
  local key_path="$1" email="$2"
  local ssh_dir
  ssh_dir=$(dirname "$key_path")
  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"

  if [[ -n "${HANIF_GSETUP_SKIP_KEYGEN:-}" ]]; then
    # Test mode: write empty placeholder files so downstream code can
    # still verify paths/permissions without needing ssh-keygen.
    : > "$key_path"
    printf 'ssh-ed25519 AAAA-test-key-for-%s %s\n' "$(basename "$key_path")" "$email" > "${key_path}.pub"
  else
    if ! command_exists ssh-keygen; then
      error "ssh-keygen not found on PATH — install OpenSSH and re-run."
      return 1
    fi
    # -N "" : no passphrase. -q : quiet. -C : comment is the email.
    if ! ssh-keygen -t ed25519 -f "$key_path" -N "" -C "$email" -q; then
      error "ssh-keygen failed."
      return 1
    fi
  fi

  chmod 600 "$key_path"
  [[ -f "${key_path}.pub" ]] && chmod 644 "${key_path}.pub"
  return 0
}

# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

hanif_git_setup() {
  local profile="${1:-}"

  print_banner "Set Up a New Git Profile"
  echo ""
  hint "  This walks you through a one-time setup for a new git identity"
  hint "  (work / personal / freelance / experiments / …). Existing files"
  hint "  are backed up as <file>.bak before any change."
  echo ""

  # --- 1. Profile name ------------------------------------------------------
  if [[ -n "$profile" ]]; then
    if ! _hanif_gsetup_valid_profile "$profile"; then
      error "Invalid profile name: '$profile'"
      hint "  Names must match: ^[A-Za-z0-9_-]+\$"
      return 1
    fi
    kv "Profile" "$profile"
  else
    _hanif_gsetup_prompt \
      "Profile name (e.g. work, personal, freelance)" \
      "" \
      _hanif_gsetup_valid_profile \
      "Names must match ^[A-Za-z0-9_-]+\$ (no spaces, no dots)."
    profile="$_HANIF_GSETUP_PROMPT_VALUE"
  fi

  # --- 2. Repos directory ---------------------------------------------------
  local default_dir="$(_hanif_gsetup_home)/code/$profile"
  _hanif_gsetup_prompt "Where will repos for this profile live?" "$default_dir"
  local repos_dir="$_HANIF_GSETUP_PROMPT_VALUE"

  # Expand a leading "~" since `read` doesn't do tilde expansion.
  if [[ "$repos_dir" == "~" ]]; then
    repos_dir="$(_hanif_gsetup_home)"
  elif [[ "$repos_dir" == "~/"* ]]; then
    repos_dir="$(_hanif_gsetup_home)/${repos_dir#~/}"
  fi

  # --- 3. Git identity ------------------------------------------------------
  _hanif_gsetup_prompt "Git user.name (e.g. \"Hanif Mianjee\")" "" \
    _hanif_gsetup_valid_name \
    "Name must be non-empty and contain no newlines or double-quotes."
  local git_name="$_HANIF_GSETUP_PROMPT_VALUE"

  _hanif_gsetup_prompt "Git user.email" "" \
    _hanif_gsetup_valid_email \
    "Doesn't look like a valid email address."
  local git_email="$_HANIF_GSETUP_PROMPT_VALUE"

  # --- 4. Resolve target paths & summarise ---------------------------------
  local key_path profile_cfg root_cfg
  key_path=$(_hanif_gsetup_ssh_key_path "$profile")
  profile_cfg=$(_hanif_gsetup_profile_gitconfig "$profile")
  root_cfg=$(_hanif_gsetup_root_gitconfig)

  echo ""
  print_banner "Review"
  echo ""
  kv "Profile"        "$profile"
  kv "Repos dir"      "$repos_dir"
  kv "user.name"      "$git_name"
  kv "user.email"     "$git_email"
  kv "SSH key"        "$key_path"
  kv "Profile config" "$profile_cfg"
  kv "Root config"    "$root_cfg"
  echo ""

  if ! confirm "Create / update everything above?"; then
    info "Aborted — no changes written."
    return 0
  fi

  # --- 5. Repos directory ---------------------------------------------------
  if [[ ! -d "$repos_dir" ]]; then
    step "Creating repos directory" "$repos_dir"
    mkdir -p "$repos_dir"
  else
    info "Repos directory already exists — leaving as-is."
  fi

  # --- 6. SSH key -----------------------------------------------------------
  if [[ -f "$key_path" ]]; then
    warning "SSH key already exists at $key_path"
    hint "  Re-using an existing key is usually what you want — it stays"
    hint "  trusted by anything you've already added it to (GitHub, etc.)."
    if ! confirm "Reuse the existing key? (decline to abort)"; then
      info "Aborted — no changes written."
      return 0
    fi
    info "Reusing existing SSH key."
  else
    step "Generating SSH key" "$key_path"
    if ! _hanif_gsetup_generate_key "$key_path" "$git_email"; then
      return 1
    fi
    success "SSH key generated"
  fi

  # --- 7. Per-profile gitconfig --------------------------------------------
  if [[ -f "$profile_cfg" ]]; then
    warning "Per-profile gitconfig already exists: $profile_cfg"
    if ! confirm "Overwrite it with the new values? (a .bak is kept)"; then
      info "Skipped per-profile gitconfig."
    else
      step "Writing per-profile gitconfig" "$profile_cfg"
      _hanif_gsetup_write_profile_gitconfig "$profile" "$git_name" "$git_email" "$key_path"
      success "Wrote $profile_cfg"
    fi
  else
    step "Writing per-profile gitconfig" "$profile_cfg"
    _hanif_gsetup_write_profile_gitconfig "$profile" "$git_name" "$git_email" "$key_path"
    success "Wrote $profile_cfg"
  fi

  # --- 8. Root ~/.gitconfig includeIf block --------------------------------
  step "Updating root gitconfig" "$root_cfg"
  _hanif_gsetup_write_root_include "$profile" "$repos_dir" "$profile_cfg"
  success "includeIf block in place"

  # --- 9. Final summary + instructions -------------------------------------
  echo ""
  print_banner "Done — Add the public key to your remote"
  echo ""

  local pub_key="${key_path}.pub"
  if [[ -f "$pub_key" ]]; then
    info "Public key:"
    echo ""
    cat "$pub_key"
    echo ""
  else
    warning "Public key not found at $pub_key (skipping print)."
  fi

  cat <<EOF
GitHub
  1. Open https://github.com/settings/keys
  2. Click "New SSH key"
  3. Title: $(basename "$key_path")
  4. Key type: Authentication Key
  5. Paste the key above and save.
  6. Test:  ssh -T -i ${key_path} git@github.com

Azure DevOps
  1. Open https://dev.azure.com/  →  User settings  →  SSH public keys
  2. Click "New Key"
  3. Name: $(basename "$key_path")
  4. Paste the key above and save.

How it auto-applies
  Any repo cloned (or moved) under:
    ${repos_dir}
  will automatically use:
    user.name  = ${git_name}
    user.email = ${git_email}
    ssh key    = ${key_path}

  No per-repo configuration needed. Verify inside a repo with:
    git config user.email
    git config core.sshCommand

Tips
  • Add a passphrase to the key later with:  ssh-keygen -p -f ${key_path}
  • Re-run \`hanif gsetup ${profile}\` any time to update the values
    in place — the includeIf block is rewritten, not duplicated.
EOF
}
