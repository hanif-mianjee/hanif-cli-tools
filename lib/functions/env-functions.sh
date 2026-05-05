#!/usr/bin/env bash
#
# env-functions.sh
#
# Implementation of ``hanif env`` — persistent environment variable
# management. See ``lib/commands/env.sh`` for the dispatcher and help.

# ---------------------------------------------------------------------------
# Path & shell detection
# ---------------------------------------------------------------------------

# Detect the user's interactive shell, returning one of: bash, zsh, fish, sh.
# Honours $HANIF_ENV_SHELL for testing/override.
_hanif_env_detect_shell() {
  if [[ -n "${HANIF_ENV_SHELL:-}" ]]; then
    echo "$HANIF_ENV_SHELL"
    return
  fi
  local shell_name="${SHELL##*/}"
  case "$shell_name" in
    zsh|bash|fish) echo "$shell_name" ;;
    *)             echo "bash" ;;  # sensible default
  esac
}

# Path to the managed env file. Honours $HANIF_ENV_FILE for testing.
_hanif_env_file() {
  if [[ -n "${HANIF_ENV_FILE:-}" ]]; then
    echo "$HANIF_ENV_FILE"
    return
  fi
  local shell
  shell=$(_hanif_env_detect_shell)
  if [[ "$shell" == "fish" ]]; then
    echo "${HOME}/.hanif/env.fish"
  else
    echo "${HOME}/.hanif/env.sh"
  fi
}

# Path to the user's shell profile. Honours $HANIF_ENV_PROFILE.
_hanif_env_profile() {
  if [[ -n "${HANIF_ENV_PROFILE:-}" ]]; then
    echo "$HANIF_ENV_PROFILE"
    return
  fi
  local shell
  shell=$(_hanif_env_detect_shell)
  case "$shell" in
    zsh)  echo "${HOME}/.zshrc" ;;
    fish) echo "${HOME}/.config/fish/conf.d/hanif.fish" ;;
    bash)
      if [[ "$(uname -s)" == "Darwin" ]]; then
        echo "${HOME}/.bash_profile"
      else
        echo "${HOME}/.bashrc"
      fi
      ;;
    *)    echo "${HOME}/.profile" ;;
  esac
}

_hanif_env_is_fish() {
  [[ "$(_hanif_env_detect_shell)" == "fish" ]]
}

# Begin/end markers for the managed block in the user's profile.
# Kept as constants so we can reliably detect & remove the block later.
readonly HANIF_ENV_BEGIN="# >>> hanif env >>>"
readonly HANIF_ENV_END="# <<< hanif env <<<"

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

# Strict KEY validation. POSIX env var name rules.
_hanif_env_valid_key() {
  [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
}

# Parse "KEY=VALUE" or ("KEY" "VALUE") into _HANIF_ENV_KEY / _HANIF_ENV_VALUE.
# Returns 0 on success, 1 on bad input.
_hanif_env_parse_kv() {
  _HANIF_ENV_KEY=""
  _HANIF_ENV_VALUE=""
  if [[ $# -eq 0 ]]; then
    return 1
  fi

  if [[ $# -eq 1 ]]; then
    local arg="$1"
    if [[ "$arg" != *=* ]]; then
      return 1
    fi
    _HANIF_ENV_KEY="${arg%%=*}"
    _HANIF_ENV_VALUE="${arg#*=}"
  else
    _HANIF_ENV_KEY="$1"
    shift
    _HANIF_ENV_VALUE="$*"
  fi

  if ! _hanif_env_valid_key "$_HANIF_ENV_KEY"; then
    return 2
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Managed file: read / write / parse
# ---------------------------------------------------------------------------

# Ensure the managed file exists with a header block.
_hanif_env_ensure_file() {
  local file
  file=$(_hanif_env_file)
  local dir
  dir=$(dirname "$file")
  mkdir -p "$dir"
  if [[ ! -f "$file" ]]; then
    if _hanif_env_is_fish; then
      cat > "$file" <<'EOF'
# Managed by `hanif env` — persistent environment variables for fish.
# Edit with `hanif env edit` or directly; `hanif env set/unset` will rewrite
# matching lines while preserving everything else.
EOF
    else
      cat > "$file" <<'EOF'
# Managed by `hanif env` — persistent environment variables.
# Edit with `hanif env edit` or directly; `hanif env set/unset` will rewrite
# matching lines while preserving everything else.
EOF
    fi
    chmod 600 "$file"
  fi
}

# Print just the KEY of every export line in the managed file, one per line.
_hanif_env_keys() {
  local file
  file=$(_hanif_env_file)
  [[ -f "$file" ]] || return 0
  if _hanif_env_is_fish; then
    grep -E '^set -gx [A-Za-z_][A-Za-z0-9_]* ' "$file" 2>/dev/null \
      | awk '{print $3}'
  else
    grep -E '^export [A-Za-z_][A-Za-z0-9_]*=' "$file" 2>/dev/null \
      | sed -E 's/^export ([A-Za-z_][A-Za-z0-9_]*)=.*$/\1/'
  fi
}

# Print the raw export line for KEY, or empty if not set.
_hanif_env_get_line() {
  local key="$1"
  local file
  file=$(_hanif_env_file)
  [[ -f "$file" ]] || return 0
  if _hanif_env_is_fish; then
    grep -E "^set -gx ${key} " "$file" 2>/dev/null | tail -n1
  else
    grep -E "^export ${key}=" "$file" 2>/dev/null | tail -n1
  fi
}

# Print the (decoded) VALUE of KEY by sourcing the line in a subshell.
# Safe because the managed file is only written by us via printf '%q'.
_hanif_env_get_value() {
  local key="$1"
  local line
  line=$(_hanif_env_get_line "$key")
  [[ -z "$line" ]] && return 1
  if _hanif_env_is_fish; then
    # set -gx KEY 'value with spaces'
    # Strip the prefix and surrounding single quotes if any.
    local v="${line#set -gx ${key} }"
    # Unwrap single quotes and reverse the escapes from _hanif_env_quote_value
    # (in this order: \' → ' first, \\ → \ second).
    if [[ "$v" == \'*\' ]]; then
      v="${v:1:-1}"
      v="${v//\\\'/\'}"
      v="${v//\\\\/\\}"
    fi
    printf '%s' "$v"
  else
    # Source the single line in a clean subshell to decode any %q quoting.
    bash -c "$(printf '%s\n' "$line"; printf 'printf %%s "$%s"\n' "$key")"
  fi
}

# Encode a VALUE using the managed file's quoting convention.
#   bash/zsh : printf '%q'
#   fish     : single-quoted with embedded single quotes escaped
_hanif_env_quote_value() {
  local value="$1"
  if _hanif_env_is_fish; then
    # fish single-quote rules: only \\ and \' are special.
    local q="${value//\\/\\\\}"
    q="${q//\'/\\\'}"
    printf "'%s'" "$q"
  else
    printf '%q' "$value"
  fi
}

# Build the export line for KEY=VALUE.
_hanif_env_format_line() {
  local key="$1" value="$2"
  local quoted
  quoted=$(_hanif_env_quote_value "$value")
  if _hanif_env_is_fish; then
    printf 'set -gx %s %s\n' "$key" "$quoted"
  else
    printf 'export %s=%s\n' "$key" "$quoted"
  fi
}

# Write KEY=VALUE atomically to the managed file. Replaces any existing
# entry for KEY. Creates a .bak side-file before writing.
_hanif_env_write() {
  local key="$1" value="$2"
  local file
  file=$(_hanif_env_file)
  _hanif_env_ensure_file

  local new_line
  new_line=$(_hanif_env_format_line "$key" "$value")

  local tmp
  tmp=$(mktemp)
  chmod 600 "$tmp"

  local pattern
  if _hanif_env_is_fish; then
    pattern="^set -gx ${key} "
  else
    pattern="^export ${key}="
  fi

  # Drop existing line(s) for this KEY, keep everything else.
  grep -Ev "$pattern" "$file" > "$tmp" || true
  printf '%s\n' "$new_line" >> "$tmp"

  cp "$file" "${file}.bak"
  mv "$tmp" "$file"
  chmod 600 "$file"
}

# Remove KEY from the managed file. Returns 1 if not present.
_hanif_env_delete() {
  local key="$1"
  local file
  file=$(_hanif_env_file)
  [[ -f "$file" ]] || return 1

  local pattern
  if _hanif_env_is_fish; then
    pattern="^set -gx ${key} "
  else
    pattern="^export ${key}="
  fi

  grep -Eq "$pattern" "$file" 2>/dev/null || return 1

  local tmp
  tmp=$(mktemp)
  chmod 600 "$tmp"
  grep -Ev "$pattern" "$file" > "$tmp" || true
  cp "$file" "${file}.bak"
  mv "$tmp" "$file"
  chmod 600 "$file"
  return 0
}

# ---------------------------------------------------------------------------
# Profile wiring
# ---------------------------------------------------------------------------

# Returns 0 if the profile contains a hanif-managed source block.
_hanif_env_profile_has_block() {
  local profile
  profile=$(_hanif_env_profile)
  [[ -f "$profile" ]] || return 1
  grep -qF "$HANIF_ENV_BEGIN" "$profile" 2>/dev/null
}

# Append the source block to the profile (idempotent — caller checks first).
_hanif_env_profile_install() {
  local profile
  profile=$(_hanif_env_profile)
  local file
  file=$(_hanif_env_file)
  mkdir -p "$(dirname "$profile")"
  touch "$profile"

  {
    printf '\n%s\n' "$HANIF_ENV_BEGIN"
    if _hanif_env_is_fish; then
      printf 'if test -f %s\n    source %s\nend\n' "$file" "$file"
    else
      printf '# Persistent env vars managed by `hanif env`. Edit via that\n'
      printf '# command, or run `hanif env path` to find this file.\n'
      printf '[ -f %q ] && . %q\n' "$file" "$file"
    fi
    printf '%s\n' "$HANIF_ENV_END"
  } >> "$profile"
}

# Remove the hanif-managed block from the profile (used by `unset --purge`).
_hanif_env_profile_uninstall() {
  local profile
  profile=$(_hanif_env_profile)
  [[ -f "$profile" ]] || return 0
  _hanif_env_profile_has_block || return 0
  local tmp
  tmp=$(mktemp)
  chmod 600 "$tmp"
  awk -v b="$HANIF_ENV_BEGIN" -v e="$HANIF_ENV_END" '
    $0 == b { skip=1; next }
    $0 == e { skip=0; next }
    !skip   { print }
  ' "$profile" > "$tmp"
  cp "$profile" "${profile}.bak"
  mv "$tmp" "$profile"
}

# Ask the user for permission to wire the profile, then install the block.
# No-op if already installed. Returns 0 either way (don't fail the parent
# command just because the user declined — they can still source manually).
_hanif_env_ensure_profile_wired() {
  if _hanif_env_profile_has_block; then
    return 0
  fi

  local profile file
  profile=$(_hanif_env_profile)
  file=$(_hanif_env_file)

  echo ""
  warning "Your shell profile does not yet source Hanif's env file."
  kv "Profile" "$profile"
  kv "Env file" "$file"
  echo ""
  hint "  Adding one idempotent block to your profile means new shells"
  hint "  pick up persisted vars automatically. Existing shells must"
  hint "  still 'source' the file once (see: hanif env source)."
  echo ""

  if confirm "Add the source block to your profile now?"; then
    _hanif_env_profile_install
    success "Profile updated"
    kv "Profile" "$profile"
    hint "  Open a new shell or run: source $profile"
  else
    info "Skipped — your profile was not modified."
    hint "  You can wire it up later by re-running 'hanif env set'."
  fi
}

# ---------------------------------------------------------------------------
# Public subcommand handlers
# ---------------------------------------------------------------------------

hanif_env_set() {
  if [[ $# -eq 0 ]]; then
    error "Usage: hanif env set KEY=VALUE"
    hint "       hanif env set KEY VALUE"
    return 1
  fi

  local rc=0
  _hanif_env_parse_kv "$@" || rc=$?
  case $rc in
    1)
      error "Could not parse — expected KEY=VALUE or KEY VALUE"
      return 1
      ;;
    2)
      error "Invalid variable name: '$_HANIF_ENV_KEY'"
      hint "  Names must match: ^[A-Za-z_][A-Za-z0-9_]*$"
      return 1
      ;;
  esac

  local key="$_HANIF_ENV_KEY"
  local value="$_HANIF_ENV_VALUE"
  local file
  file=$(_hanif_env_file)

  _hanif_env_ensure_file

  # Check for overwrite.
  local existing
  existing=$(_hanif_env_get_value "$key" || true)
  local existed=0
  if _hanif_env_get_line "$key" >/dev/null 2>&1 && [[ -n "$(_hanif_env_get_line "$key")" ]]; then
    existed=1
  fi

  print_banner "Persist Environment Variable"
  echo ""
  kv "Key" "$key"
  kv "Value" "$value"
  kv "File" "$file"
  echo ""

  if (( existed )); then
    warning "'$key' is already set in the managed file."
    kv "Current" "$existing"
    echo ""
    if ! confirm "Overwrite the existing value?"; then
      info "Aborted — no changes written."
      return 0
    fi
  else
    if ! confirm "Write this variable to the managed file?"; then
      info "Aborted — no changes written."
      return 0
    fi
  fi

  _hanif_env_write "$key" "$value"
  if (( existed )); then
    success "Updated '$key' in $file"
  else
    success "Added '$key' to $file"
  fi

  _hanif_env_ensure_profile_wired

  echo ""
  hint "  To load into your CURRENT shell, run:"
  if _hanif_env_is_fish; then
    hint "    source $file"
  else
    hint "    source $file"
  fi
}

hanif_env_unset() {
  if [[ $# -eq 0 ]]; then
    error "Usage: hanif env unset KEY"
    return 1
  fi
  local key="$1"
  if ! _hanif_env_valid_key "$key"; then
    error "Invalid variable name: '$key'"
    return 1
  fi

  local existing
  if ! existing=$(_hanif_env_get_value "$key" 2>/dev/null) || [[ -z "$(_hanif_env_get_line "$key")" ]]; then
    warning "'$key' is not in the managed file — nothing to remove."
    return 0
  fi

  print_banner "Remove Environment Variable"
  echo ""
  kv "Key" "$key"
  kv "Current" "$existing"
  kv "File" "$(_hanif_env_file)"
  echo ""

  if ! confirm "Remove this variable?"; then
    info "Aborted — no changes written."
    return 0
  fi

  if _hanif_env_delete "$key"; then
    success "Removed '$key' from the managed file"
    echo ""
    hint "  '$key' is still set in your CURRENT shell. To clear it now:"
    hint "    unset $key"
  else
    error "Failed to remove '$key'"
    return 1
  fi
}

hanif_env_list() {
  local file
  file=$(_hanif_env_file)

  print_banner "Persistent Environment Variables"
  echo ""
  kv "File" "$file"
  kv "Profile" "$(_hanif_env_profile)"
  if _hanif_env_profile_has_block; then
    kv "Wired" "yes  ✓"
  else
    kv "Wired" "no   (run 'hanif env set …' to wire automatically)"
  fi
  echo ""

  if [[ ! -f "$file" ]]; then
    info "No managed env file yet — run 'hanif env set KEY=VALUE' to create one."
    return 0
  fi

  local -a keys=()
  while IFS= read -r k; do
    [[ -n "$k" ]] && keys+=("$k")
  done < <(_hanif_env_keys)

  if [[ ${#keys[@]} -eq 0 ]]; then
    info "No variables set yet."
    hint "  Add one with:  hanif env set MY_VAR=hello"
    return 0
  fi

  local k v display
  {
    for k in "${keys[@]}"; do
      v=$(_hanif_env_get_value "$k" 2>/dev/null || echo "")
      display="$v"
      # Truncate very long values for readability.
      if [[ ${#display} -gt 60 ]]; then
        display="${display:0:57}..."
      fi
      # Mask values that look like secrets so `list` is shoulder-surf safe.
      # Use plain ASCII — render_table aligns by byte count, so multi-byte
      # characters (•) and ANSI escapes would throw off column widths.
      case "$k" in
        *TOKEN*|*SECRET*|*PASSWORD*|*PASSWD*|*KEY*|*API*)
          if [[ ${#v} -gt 4 ]]; then
            display="****${v: -4}  (masked)"
          else
            display="****  (masked)"
          fi
          ;;
      esac
      printf '%s\t%s\n' "$k" "$display"
    done
  } | render_table "KEY|VALUE"

  echo ""
  hint "  Reveal a masked value with:  hanif env get <KEY>"
}

hanif_env_get() {
  if [[ $# -eq 0 ]]; then
    error "Usage: hanif env get KEY"
    return 1
  fi
  local key="$1"
  if ! _hanif_env_valid_key "$key"; then
    error "Invalid variable name: '$key'"
    return 1
  fi

  local file
  file=$(_hanif_env_file)
  local persisted="(not set)"
  if [[ -f "$file" ]] && [[ -n "$(_hanif_env_get_line "$key")" ]]; then
    persisted=$(_hanif_env_get_value "$key" 2>/dev/null || echo "(unreadable)")
  fi

  local current
  # Look up live value via env without invoking eval on user input.
  current=$(env | awk -F= -v k="$key" '$1 == k { sub(/^[^=]+=/, ""); print }')
  [[ -z "$current" ]] && current="(not exported)"

  print_banner "Variable: $key"
  echo ""
  kv "Persisted" "$persisted"
  kv "Current"   "$current"
  kv "File"      "$file"

  if [[ "$persisted" != "(not set)" && "$current" != "(not exported)" && "$persisted" != "$current" ]]; then
    echo ""
    warning "Persisted and current values differ — run 'source $file' to refresh."
  fi
}

hanif_env_source_hint() {
  local file
  file=$(_hanif_env_file)
  print_banner "Load Persisted Variables"
  echo ""
  if [[ ! -f "$file" ]]; then
    warning "No managed env file exists yet — nothing to source."
    hint "  Create one with:  hanif env set MY_VAR=value"
    return 0
  fi

  info "Sub-processes (like this CLI) cannot mutate the parent shell."
  info "Run the following in your CURRENT shell to load the variables:"
  echo ""
  if _hanif_env_is_fish; then
    _hanif_render 1 "    ${BOLD}${GREEN}source $file${NC}"; printf '\n'
  else
    _hanif_render 1 "    ${BOLD}${GREEN}source $file${NC}"; printf '\n'
  fi
  echo ""
  hint "  New shells pick this up automatically (provided the profile is wired)."
}

hanif_env_edit() {
  local file
  file=$(_hanif_env_file)
  _hanif_env_ensure_file
  local editor="${EDITOR:-${VISUAL:-vi}}"
  info "Opening $file with $editor"
  "$editor" "$file"
}

hanif_env_paths() {
  local file profile
  file=$(_hanif_env_file)
  profile=$(_hanif_env_profile)
  print_banner "Hanif Env Paths"
  echo ""
  kv "Shell"    "$(_hanif_env_detect_shell)"
  kv "Env file" "$file"
  kv "Profile"  "$profile"
  if _hanif_env_profile_has_block; then
    kv "Wired"   "yes  ✓"
  else
    kv "Wired"   "no"
  fi
}
