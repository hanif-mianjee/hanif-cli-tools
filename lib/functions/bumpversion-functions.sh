#!/usr/bin/env bash

# Bump version functions for Hanif CLI
# A bump2version-compatible version bumping engine
# Compatible with Bash 3.2+ (no associative arrays or declare -g)

set -euo pipefail

# ─────────────────────────────────────────────
# Global state (set by parse functions)
# ─────────────────────────────────────────────
# Config values stored as BV_CFG_<key> variables
# Part values stored as BV_PART_<partname>_<key> variables
# File values stored as BV_FILE_<index>_<key> variables
# Version parts stored as BV_VP_<partname> variables

BV_FILE_COUNT=0
BV_FILE_LIST=""          # space-separated list of file paths
BV_SERIALIZE_COUNT=0
BV_SERIALIZE_LIST=""     # newline-separated serialize patterns
BV_PART_LIST=""          # space-separated list of part names

# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────

_bv_sanitize_key() {
  # Replace dots, hyphens, slashes with underscores for variable names
  echo "$1" | tr '.-/' '___'
}

_bv_set_config() {
  local key="$1" value="$2"
  eval "BV_CFG_${key}=\"\${value}\""
}

_bv_get_config() {
  local key="$1"
  eval "echo \"\${BV_CFG_${key}:-}\""
}

_bv_set_part() {
  local part="$1" key="$2" value="$3"
  eval "BV_PART_${part}_${key}=\"\${value}\""
}

_bv_get_part() {
  local part="$1" key="$2"
  eval "echo \"\${BV_PART_${part}_${key}:-}\""
}

_bv_set_file_prop() {
  local idx="$1" key="$2" value="$3"
  eval "BV_FILE_${idx}_${key}=\"\${value}\""
}

_bv_get_file_prop() {
  local idx="$1" key="$2"
  eval "echo \"\${BV_FILE_${idx}_${key}:-}\""
}

_bv_set_vp() {
  local part="$1" value="$2"
  eval "BV_VP_${part}=\"\${value}\""
}

_bv_get_vp() {
  local part="$1"
  eval "echo \"\${BV_VP_${part}:-}\""
}

_bv_set_nvp() {
  local part="$1" value="$2"
  eval "BV_NVP_${part}=\"\${value}\""
}

_bv_get_nvp() {
  local part="$1"
  eval "echo \"\${BV_NVP_${part}:-}\""
}

_bv_to_lower() {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

# ─────────────────────────────────────────────
# Config Parser
# ─────────────────────────────────────────────

parse_bumpversion_config() {
  local config_file="${1:-.bumpversion.cfg}"

  if [[ ! -f "$config_file" ]]; then
    error "Config file not found: $config_file"
    if confirm "Initialize bumpversion config now?"; then
      bumpversion_init
      # Re-check if config was created
      if [[ ! -f "$config_file" ]]; then
        return 1
      fi
    else
      info "Run 'hanif bv init' to create a config"
      return 1
    fi
  fi

  # Reset state
  BV_FILE_COUNT=0
  BV_FILE_LIST=""
  BV_SERIALIZE_COUNT=0
  BV_SERIALIZE_LIST=""
  BV_PART_LIST=""

  local current_section=""
  local current_part=""
  local current_file=""
  local current_file_idx=-1

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Strip comments and leading/trailing whitespace
    line=$(echo "$line" | sed 's/#.*//; s/^[[:space:]]*//; s/[[:space:]]*$//')

    # Skip empty lines
    [[ -z "$line" ]] && continue

    # Section headers
    if [[ "$line" =~ ^\[(.+)\]$ ]]; then
      current_section="${BASH_REMATCH[1]}"
      current_part=""
      current_file=""

      if [[ "$current_section" == "bumpversion" ]]; then
        : # Main section
      elif [[ "$current_section" =~ ^bumpversion:part:(.+)$ ]]; then
        current_part="${BASH_REMATCH[1]}"
        BV_PART_LIST="${BV_PART_LIST} ${current_part}"
      elif [[ "$current_section" =~ ^bumpversion:file:(.+)$ ]]; then
        current_file="${BASH_REMATCH[1]}"
        current_file_idx=$BV_FILE_COUNT
        _bv_set_file_prop "$current_file_idx" "path" "$current_file"
        BV_FILE_LIST="${BV_FILE_LIST} ${current_file}"
        BV_FILE_COUNT=$((BV_FILE_COUNT + 1))
      fi
      continue
    fi

    # Key = value pairs
    if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
      local key value
      key=$(echo "${BASH_REMATCH[1]}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
      value=$(echo "${BASH_REMATCH[2]}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

      if [[ "$current_section" == "bumpversion" ]]; then
        _bv_set_config "$key" "$value"
        if [[ "$key" == "serialize" ]]; then
          if [[ -n "$value" ]]; then
            BV_SERIALIZE_LIST="${BV_SERIALIZE_LIST}${value}"$'\n'
            BV_SERIALIZE_COUNT=$((BV_SERIALIZE_COUNT + 1))
          fi
        fi
      elif [[ -n "$current_part" ]]; then
        _bv_set_part "$current_part" "$key" "$value"
      elif [[ -n "$current_file" ]]; then
        local safe_key
        safe_key=$(_bv_sanitize_key "$key")
        _bv_set_file_prop "$current_file_idx" "$safe_key" "$value"
      fi
    # Handle continuation lines (indented values, like serialize patterns)
    elif [[ "$current_section" == "bumpversion" && -n "$line" && "$line" != *"="* ]]; then
      # Check if this looks like a serialize continuation
      if [[ "$line" =~ ^\{.+ ]]; then
        BV_SERIALIZE_LIST="${BV_SERIALIZE_LIST}${line}"$'\n'
        BV_SERIALIZE_COUNT=$((BV_SERIALIZE_COUNT + 1))
      fi
    fi
  done < "$config_file"

  # Defaults
  if [[ -z "$(_bv_get_config "commit")" ]]; then
    _bv_set_config "commit" "True"
  fi
  if [[ -z "$(_bv_get_config "tag")" ]]; then
    _bv_set_config "tag" "True"
  fi
  if [[ -z "$(_bv_get_config "tag_name")" ]]; then
    _bv_set_config "tag_name" "v{new_version}"
  fi
  if [[ -z "$(_bv_get_config "commit_message")" ]]; then
    _bv_set_config "commit_message" "Bump version: {current_version} → {new_version}"
  fi

  # Default serialize patterns
  if [[ $BV_SERIALIZE_COUNT -eq 0 ]]; then
    BV_SERIALIZE_LIST="{major}.{minor}.{patch}-{release}{rc}"$'\n'"{major}.{minor}.{patch}"$'\n'
    BV_SERIALIZE_COUNT=2
  fi

  return 0
}

# ─────────────────────────────────────────────
# Version Parser
# ─────────────────────────────────────────────

parse_version() {
  local version="$1"
  local parse_regex
  parse_regex=$(_bv_get_config "parse")

  if [[ -z "$parse_regex" ]]; then
    error "No parse regex defined in config"
    return 1
  fi

  # Build a mapping of capture group index → name
  # We need to account for both named (?P<name>...) and unnamed (...) groups
  local group_map=""  # space-separated: "index:name" or "index:" for unnamed
  local regex_copy="$parse_regex"
  local group_idx=0
  local i=0
  local len=${#regex_copy}

  while [[ $i -lt $len ]]; do
    local char="${regex_copy:$i:1}"
    local next="${regex_copy:$((i+1)):1}"

    if [[ "$char" == "(" ]]; then
      group_idx=$((group_idx + 1))
      # Check if this is a named group (?P<name>...)
      if [[ "${regex_copy:$((i+1)):3}" == "?P<" ]]; then
        # Extract name
        local rest="${regex_copy:$((i+4))}"
        local name="${rest%%>*}"
        group_map="${group_map} ${group_idx}:${name}"
      elif [[ "$next" == "?" ]]; then
        # Non-capturing group (?:...) - doesn't count as a capture group
        group_idx=$((group_idx - 1))
      fi
    fi
    i=$((i + 1))
  done

  # Convert Python named groups (?P<name>...) to bash capture groups (...)
  # Also convert \d to [0-9] for Bash 3.2 compatibility (no PCRE support)
  local bash_regex
  bash_regex=$(echo "$parse_regex" | sed -E 's/\(\?P<[^>]+>/(/g; s/\\d/[0-9]/g')

  if [[ "$version" =~ $bash_regex ]]; then
    for entry in $group_map; do
      local idx="${entry%%:*}"
      local name="${entry#*:}"
      if [[ -n "$name" ]]; then
        _bv_set_vp "$name" "${BASH_REMATCH[$idx]:-}"
      fi
    done
  else
    error "Version '$version' does not match parse regex"
    return 1
  fi

  return 0
}

# ─────────────────────────────────────────────
# Version Serializer
# ─────────────────────────────────────────────

# Serialize version parts using a prefix (BV_VP or BV_NVP)
_serialize_version_with_prefix() {
  local prefix="$1"

  local pattern
  while IFS= read -r pattern; do
    [[ -z "$pattern" ]] && continue

    local result="$pattern"
    local all_parts_present=true

    # Find all {part} placeholders in this pattern
    local pattern_copy="$pattern"
    while [[ "$pattern_copy" =~ \{([^}]+)\} ]]; do
      local part_name="${BASH_REMATCH[1]}"
      local part_value
      eval "part_value=\"\${${prefix}_${part_name}:-}\""
      local optional_value
      optional_value=$(_bv_get_part "$part_name" "optional_value")

      # If part is absent (empty or equals optional_value), this pattern fails
      if [[ -z "$part_value" ]] || [[ -n "$optional_value" && "$part_value" == "$optional_value" ]]; then
        all_parts_present=false
        break
      fi

      # Replace placeholder
      result=$(echo "$result" | sed "s/{${part_name}}/${part_value}/g")
      pattern_copy="${pattern_copy#*"${BASH_REMATCH[0]}"}"
    done

    if [[ "$all_parts_present" == true ]]; then
      echo "$result"
      return 0
    fi
  done <<< "$BV_SERIALIZE_LIST"

  error "No serialization pattern matched the version parts"
  return 1
}

serialize_version() {
  _serialize_version_with_prefix "BV_VP"
}

serialize_new_version() {
  _serialize_version_with_prefix "BV_NVP"
}

# ─────────────────────────────────────────────
# Version Calculator
# ─────────────────────────────────────────────

calculate_next_version() {
  local bump_type="$1"

  # Copy current parts to new parts
  for name in $BV_PART_LIST; do
    _bv_set_nvp "$name" "$(_bv_get_vp "$name")"
  done
  # Also copy standard parts
  for name in major minor patch release rc; do
    _bv_set_nvp "$name" "$(_bv_get_vp "$name")"
  done

  local release_optional
  release_optional=$(_bv_get_part "release" "optional_value")
  local rc_first
  rc_first=$(_bv_get_part "rc" "first_value")
  rc_first="${rc_first:-0}"

  local has_release_part=false
  if [[ -n "$(_bv_get_part "release" "values")" ]] || [[ -n "$(_bv_get_part "release" "optional_value")" ]]; then
    has_release_part=true
  fi

  case "$bump_type" in
    major)
      _bv_set_nvp "major" "$(( $(_bv_get_vp "major") + 1 ))"
      _bv_set_nvp "minor" "0"
      _bv_set_nvp "patch" "0"
      if [[ "$has_release_part" == true ]]; then
        _bv_set_nvp "release" "rc"
        _bv_set_nvp "rc" "$rc_first"
      fi
      ;;
    minor)
      _bv_set_nvp "minor" "$(( $(_bv_get_vp "minor") + 1 ))"
      _bv_set_nvp "patch" "0"
      if [[ "$has_release_part" == true ]]; then
        _bv_set_nvp "release" "rc"
        _bv_set_nvp "rc" "$rc_first"
      fi
      ;;
    patch)
      _bv_set_nvp "patch" "$(( $(_bv_get_vp "patch") + 1 ))"
      if [[ "$has_release_part" == true ]]; then
        _bv_set_nvp "release" "rc"
        _bv_set_nvp "rc" "$rc_first"
      fi
      ;;
    rc)
      local current_release
      current_release=$(_bv_get_vp "release")
      if [[ "$current_release" == "rc" ]]; then
        _bv_set_nvp "rc" "$(( $(_bv_get_vp "rc") + 1 ))"
      else
        _bv_set_nvp "release" "rc"
        _bv_set_nvp "rc" "$rc_first"
      fi
      ;;
    release)
      if [[ -n "$release_optional" ]]; then
        _bv_set_nvp "release" "$release_optional"
      else
        _bv_set_nvp "release" ""
      fi
      local rc_optional
      rc_optional=$(_bv_get_part "rc" "optional_value")
      _bv_set_nvp "rc" "${rc_optional:-}"
      ;;
    *)
      error "Unknown bump type: $bump_type"
      return 1
      ;;
  esac

  serialize_new_version
}

# ─────────────────────────────────────────────
# File Verification (pre-flight check)
# ─────────────────────────────────────────────

_bv_verify_files() {
  local current_version="$1"
  local config_file="${2:-.bumpversion.cfg}"
  local has_errors=false

  local idx=0
  for file in $BV_FILE_LIST; do
    [[ -z "$file" ]] && continue

    if [[ ! -f "$file" ]]; then
      warning "File not found: $file"
      idx=$((idx + 1))
      continue
    fi

    local search
    search=$(_bv_get_file_prop "$idx" "search")
    search="${search:-{current_version\}}"
    search=$(echo "$search" | sed "s/{current_version}/${current_version}/g")

    if ! grep -qF "$search" "$file"; then
      # Fallback: try plain version string
      if ! grep -qF "$current_version" "$file"; then
        error "Search pattern not found in $file: $search"
        has_errors=true
      fi
    fi

    idx=$((idx + 1))
  done

  if [[ "$has_errors" == true ]]; then
    error "Pre-flight check failed. No files were modified."
    return 1
  fi

  return 0
}

# ─────────────────────────────────────────────
# File Updater
# ─────────────────────────────────────────────

update_version_files() {
  local current_version="$1"
  local new_version="$2"
  local config_file="${3:-.bumpversion.cfg}"

  local idx=0
  for file in $BV_FILE_LIST; do
    [[ -z "$file" ]] && continue

    if [[ ! -f "$file" ]]; then
      warning "File not found, skipping: $file"
      idx=$((idx + 1))
      continue
    fi

    local search replace
    search=$(_bv_get_file_prop "$idx" "search")
    replace=$(_bv_get_file_prop "$idx" "replace")

    # Default patterns
    search="${search:-{current_version\}}"
    replace="${replace:-{new_version\}}"

    # Interpolate placeholders
    search=$(echo "$search" | sed "s/{current_version}/${current_version}/g; s/{new_version}/${new_version}/g")
    replace=$(echo "$replace" | sed "s/{current_version}/${current_version}/g; s/{new_version}/${new_version}/g")

    if grep -qF "$search" "$file"; then
      # Use a different delimiter for sed to avoid issues with / in versions
      local search_escaped replace_escaped
      search_escaped=$(printf '%s\n' "$search" | sed 's/[&/\]/\\&/g; s/[][(){}.*+?^$|\\]/\\&/g')
      replace_escaped=$(printf '%s\n' "$replace" | sed 's/[&/\]/\\&/g')
      sed_inplace "s/${search_escaped}/${replace_escaped}/g" "$file"
      info "Updated $file"
    else
      # If no custom search pattern, try simple version replacement
      if grep -qF "$current_version" "$file"; then
        local cv_esc nv_esc
        cv_esc=$(printf '%s\n' "$current_version" | sed 's/[&/\]/\\&/g; s/[][(){}.*+?^$|\\]/\\&/g')
        nv_esc=$(printf '%s\n' "$new_version" | sed 's/[&/\]/\\&/g')
        sed_inplace "s/${cv_esc}/${nv_esc}/g" "$file"
        info "Updated $file"
      else
        warning "Search pattern not found in $file: $search"
      fi
    fi

    idx=$((idx + 1))
  done

  # Update .bumpversion.cfg itself
  if [[ -f "$config_file" ]]; then
    local cv_escaped nv_escaped
    cv_escaped=$(printf '%s\n' "$current_version" | sed 's/[&/\]/\\&/g; s/[][(){}.*+?^$|\\]/\\&/g')
    nv_escaped=$(printf '%s\n' "$new_version" | sed 's/[&/\]/\\&/g')
    sed_inplace "s/^current_version = ${cv_escaped}$/current_version = ${nv_escaped}/" "$config_file"
    info "Updated $config_file"
  fi
}

# ─────────────────────────────────────────────
# Tag Checker
# ─────────────────────────────────────────────

check_tag_exists() {
  local tag_name="$1"

  if git tag -l "$tag_name" | grep -q "^${tag_name}$"; then
    return 0
  fi

  if git ls-remote --tags origin "$tag_name" 2>/dev/null | grep -q "$tag_name"; then
    return 0
  fi

  return 1
}

handle_tag_conflict() {
  local tag_name="$1"
  local new_version="$2"

  warning "Tag '$tag_name' already exists!"
  echo ""
  echo "Options:"
  echo "  1) Delete existing tag (local + remote) and proceed"
  echo "  2) Suggest next RC version"
  echo "  3) Abort"
  echo ""

  while true; do
    printf "Choose [1-3]: "
    read -r choice

    case "$choice" in
      1)
        info "Deleting tag '$tag_name'..."
        git tag -d "$tag_name" 2>/dev/null || true
        git push origin ":refs/tags/$tag_name" 2>/dev/null || true
        success "Tag deleted"
        return 0
        ;;
      2)
        local suggested
        suggested=$(calculate_next_version "rc")
        info "Suggested version: $suggested"
        echo "$suggested"
        return 2
        ;;
      3)
        info "Aborted"
        return 1
        ;;
      *)
        warning "Invalid choice. Try again."
        ;;
    esac
  done
}

# ─────────────────────────────────────────────
# Git Operations
# ─────────────────────────────────────────────

bump_commit_and_tag() {
  local current_version="$1"
  local new_version="$2"
  local config_file="${3:-.bumpversion.cfg}"

  local do_commit do_tag tag_template msg_template
  do_commit=$(_bv_get_config "commit")
  do_tag=$(_bv_get_config "tag")
  tag_template=$(_bv_get_config "tag_name")
  msg_template=$(_bv_get_config "commit_message")

  do_commit="${do_commit:-True}"
  do_tag="${do_tag:-True}"
  tag_template="${tag_template:-v{new_version\}}"
  msg_template="${msg_template:-Bump version: {current_version\} → {new_version\}}"

  # Interpolate templates
  local commit_msg
  commit_msg=$(echo "$msg_template" | sed "s/{current_version}/${current_version}/g; s/{new_version}/${new_version}/g")
  local tag_name
  tag_name=$(echo "$tag_template" | sed "s/{current_version}/${current_version}/g; s/{new_version}/${new_version}/g")

  # Track whether we created a bump commit (so we can safely revert it)
  local bump_commit_created=false
  local bump_commit_sha=""

  if [[ "$(_bv_to_lower "$do_commit")" == "true" ]]; then
    for file in $BV_FILE_LIST; do
      [[ -n "$file" && -f "$file" ]] && git add "$file"
    done
    git add "$config_file"

    git commit -m "$commit_msg"
    bump_commit_created=true
    bump_commit_sha=$(git rev-parse HEAD)
    success "Committed: $commit_msg"
  fi

  if [[ "$(_bv_to_lower "$do_tag")" == "true" ]]; then
    if check_tag_exists "$tag_name"; then
      local conflict_result=0
      handle_tag_conflict "$tag_name" "$new_version" || conflict_result=$?
      if [[ $conflict_result -eq 1 ]] || [[ $conflict_result -eq 2 ]]; then
        # Revert the bump commit if we created one
        _bv_revert_bump_commit "$bump_commit_created" "$bump_commit_sha" "$current_version" "$config_file"
        if [[ $conflict_result -eq 2 ]]; then
          warning "Please re-run with the suggested version"
        fi
        return 1
      fi
    fi

    git tag -a "$tag_name" -m "$commit_msg"
    success "Tagged: $tag_name"
  fi

  echo ""
  if confirm "Push commit and tag to remote?"; then
    local push_failed=false
    if ! git push 2>&1; then
      push_failed=true
    fi
    if ! git push --tags 2>&1; then
      push_failed=true
    fi

    if [[ "$push_failed" == true ]]; then
      error "Push failed! Your commit and tag are local only."
      info "Fix the issue and push manually:"
      echo "  git push --follow-tags"
      return 1
    else
      success "Pushed to remote"
    fi
  else
    info "To push later, run:"
    echo "  git push --follow-tags"
  fi

  return 0
}

# Safely revert a bump commit we just created
# Only reverts if we confirm the HEAD commit is the one we made
_bv_revert_bump_commit() {
  local was_created="$1"
  local expected_sha="$2"

  if [[ "$was_created" != true ]]; then
    return 0
  fi

  # Safety check: only revert if HEAD is still the commit we created
  local current_head
  current_head=$(git rev-parse HEAD)
  if [[ "$current_head" != "$expected_sha" ]]; then
    warning "HEAD has changed since bump commit was created. Not reverting."
    warning "You may need to manually revert commit $expected_sha"
    return 1
  fi

  info "Reverting bump commit..."
  # Use --hard to undo the commit and restore all files to pre-bump state
  # Safe because we verified HEAD is exactly the bump commit we just created
  git reset --hard HEAD~1 >/dev/null 2>&1
  success "Bump commit reverted, working directory restored"
}

# ─────────────────────────────────────────────
# Main Bump Operation
# ─────────────────────────────────────────────

bump_version() {
  local bump_type="$1"
  local config_file="${2:-.bumpversion.cfg}"

  parse_bumpversion_config "$config_file" || return 1

  local current_version
  current_version=$(_bv_get_config "current_version")
  if [[ -z "$current_version" ]]; then
    error "No current_version found in config"
    return 1
  fi

  parse_version "$current_version" || return 1

  # Block rc bump on stable versions
  if [[ "$bump_type" == "rc" ]]; then
    local current_release release_optional
    current_release=$(_bv_get_vp "release")
    release_optional=$(_bv_get_part "release" "optional_value")
    if [[ -z "$current_release" || "$current_release" == "$release_optional" ]]; then
      error "Current version $current_version is a stable release — cannot promote to rc."
      info "Use one of: patch, minor, major, or custom"
      echo "  hanif bv patch    # $current_version → next patch rc"
      echo "  hanif bv minor    # $current_version → next minor rc"
      echo "  hanif bv major    # $current_version → next major rc"
      return 1
    fi
  fi

  # Block release bump on non-rc versions
  if [[ "$bump_type" == "release" ]]; then
    local current_release release_optional
    current_release=$(_bv_get_vp "release")
    release_optional=$(_bv_get_part "release" "optional_value")
    if [[ -z "$current_release" || "$current_release" == "$release_optional" ]]; then
      error "Current version $current_version is already a stable release."
      return 1
    fi
  fi

  local new_version
  new_version=$(calculate_next_version "$bump_type") || return 1

  info "Bumping version: $current_version → $new_version"
  echo ""

  # Verify all files before updating any
  _bv_verify_files "$current_version" "$config_file" || return 1

  update_version_files "$current_version" "$new_version" "$config_file"

  if is_git_repo; then
    bump_commit_and_tag "$current_version" "$new_version" "$config_file"
  else
    success "Version bumped to $new_version (not a git repo, skipping commit/tag)"
  fi

  return 0
}

# ─────────────────────────────────────────────
# Interactive Bump
# ─────────────────────────────────────────────

interactive_bump() {
  local config_file="${1:-.bumpversion.cfg}"

  parse_bumpversion_config "$config_file" || return 1

  local current_version
  current_version=$(_bv_get_config "current_version")
  if [[ -z "$current_version" ]]; then
    error "No current_version found in config"
    return 1
  fi

  parse_version "$current_version" || return 1

  echo ""
  info "Current version: $current_version"
  echo ""

  # Determine if current version is an RC
  local current_release release_optional is_rc
  current_release=$(_bv_get_vp "release")
  release_optional=$(_bv_get_part "release" "optional_value")
  is_rc=false
  if [[ -n "$current_release" && "$current_release" != "$release_optional" ]]; then
    is_rc=true
  fi

  # Calculate previews for each bump type
  local option_count=0
  local option_types=""
  local option_previews=""

  # Helper: add an option to the menu
  _add_option() {
    local type_name="$1" preview="$2" label="$3"
    option_count=$((option_count + 1))
    option_types="${option_types}${type_name} "
    option_previews="${option_previews}${preview} "
    printf "  %d) %-9s (%s → %s)\n" "$option_count" "$label" "$current_version" "$preview"
  }

  # RC option (only if currently IS an rc — increment rc number)
  if [[ "$is_rc" == true ]]; then
    local rc_preview
    if rc_preview=$(calculate_next_version "rc" 2>/dev/null); then
      parse_version "$current_version" >/dev/null 2>&1
      _add_option "rc" "$rc_preview" "rc"
    fi
  fi

  # Patch option
  local patch_preview
  if patch_preview=$(calculate_next_version "patch" 2>/dev/null); then
    parse_version "$current_version" >/dev/null 2>&1
    _add_option "patch" "$patch_preview" "patch"
  fi

  # Minor option
  local minor_preview
  if minor_preview=$(calculate_next_version "minor" 2>/dev/null); then
    parse_version "$current_version" >/dev/null 2>&1
    _add_option "minor" "$minor_preview" "minor"
  fi

  # Major option
  local major_preview
  if major_preview=$(calculate_next_version "major" 2>/dev/null); then
    parse_version "$current_version" >/dev/null 2>&1
    _add_option "major" "$major_preview" "major"
  fi

  # Release option (only if currently IS an rc — promote to clean version)
  if [[ "$is_rc" == true ]]; then
    local release_preview
    if release_preview=$(calculate_next_version "release" 2>/dev/null); then
      parse_version "$current_version" >/dev/null 2>&1
      _add_option "release" "$release_preview" "release"
    fi
  fi

  # Custom option (always available)
  option_count=$((option_count + 1))
  option_types="${option_types}custom "
  option_previews="${option_previews}custom "
  printf "  %d) %-9s (enter version manually)\n" "$option_count" "custom"

  echo ""

  # Convert space-separated lists to arrays for indexing
  local types_arr=($option_types)
  local previews_arr=($option_previews)

  while true; do
    printf "Enter choice [1-${option_count}]: "
    read -r choice

    if echo "$choice" | grep -Eq "^[0-9]+$" && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "$option_count" ]]; then
      local selected_type="${types_arr[$((choice - 1))]}"
      local new_version

      if [[ "$selected_type" == "custom" ]]; then
        printf "Enter new version: "
        read -r new_version
        if [[ -z "$new_version" ]]; then
          warning "No version entered. Aborted."
          return 1
        fi
        echo ""
        info "Bumping: $current_version → $new_version (custom)"
      else
        local selected_preview="${previews_arr[$((choice - 1))]}"
        echo ""
        info "Bumping: $current_version → $selected_preview ($selected_type)"

        # Re-parse and calculate
        parse_version "$current_version" || return 1
        new_version=$(calculate_next_version "$selected_type") || return 1
      fi

      echo ""

      # Verify all files before updating any
      _bv_verify_files "$current_version" "$config_file" || return 1

      update_version_files "$current_version" "$new_version" "$config_file"

      if is_git_repo; then
        bump_commit_and_tag "$current_version" "$new_version" "$config_file"
      else
        success "Version bumped to $new_version (not a git repo, skipping commit/tag)"
      fi

      return 0
    else
      warning "Invalid selection. Try again."
    fi
  done
}

# ─────────────────────────────────────────────
# Init
# ─────────────────────────────────────────────

bumpversion_init() {
  local config_file=".bumpversion.cfg"

  if [[ -f "$config_file" ]]; then
    warning "$config_file already exists"
    if ! confirm "Overwrite?"; then
      info "Aborted"
      return 0
    fi
  fi

  local detected_version=""
  local detected_files=""
  local detected_count=0

  if [[ -f "package.json" ]]; then
    detected_version=$(grep -o '"version":[[:space:]]*"[^"]*"' package.json | head -1 | sed 's/.*"version":[[:space:]]*"//; s/"//')
    detected_files="${detected_files} package.json"
    detected_count=$((detected_count + 1))
    info "Detected Node.js project (package.json)"
  fi

  if [[ -f "pyproject.toml" ]]; then
    local pyver
    pyver=$(grep -E '^version[[:space:]]*=' pyproject.toml | head -1 | sed 's/.*=[[:space:]]*"//; s/".*//')
    if [[ -n "$pyver" ]]; then
      detected_version="${detected_version:-$pyver}"
      detected_files="${detected_files} pyproject.toml"
      detected_count=$((detected_count + 1))
      info "Detected Python project (pyproject.toml)"
    fi
  fi

  if [[ -f "setup.py" ]]; then
    local spver
    spver=$(grep -E "version[[:space:]]*=" setup.py | head -1 | sed "s/.*version[[:space:]]*=[[:space:]]*['\"]//; s/['\"].*//" )
    if [[ -n "$spver" ]]; then
      detected_version="${detected_version:-$spver}"
      detected_files="${detected_files} setup.py"
      detected_count=$((detected_count + 1))
      info "Detected Python project (setup.py)"
    fi
  fi

  if [[ -f "setup.cfg" ]]; then
    local scver
    scver=$(grep -E '^version[[:space:]]*=' setup.cfg | head -1 | sed 's/.*=[[:space:]]*//')
    if [[ -n "$scver" ]]; then
      detected_version="${detected_version:-$scver}"
      detected_files="${detected_files} setup.cfg"
      detected_count=$((detected_count + 1))
      info "Detected Python project (setup.cfg)"
    fi
  fi

  if [[ -f "Cargo.toml" ]]; then
    local cver
    cver=$(grep -E '^version[[:space:]]*=' Cargo.toml | head -1 | sed 's/.*=[[:space:]]*"//; s/".*//')
    if [[ -n "$cver" ]]; then
      detected_version="${detected_version:-$cver}"
      detected_files="${detected_files} Cargo.toml"
      detected_count=$((detected_count + 1))
      info "Detected Rust project (Cargo.toml)"
    fi
  fi

  if [[ -f "build.gradle" ]]; then
    local gver
    gver=$(grep -E "^version[[:space:]]*=" build.gradle | head -1 | sed "s/.*=[[:space:]]*['\"]//; s/['\"].*//" )
    if [[ -n "$gver" ]]; then
      detected_version="${detected_version:-$gver}"
      detected_files="${detected_files} build.gradle"
      detected_count=$((detected_count + 1))
      info "Detected Gradle project (build.gradle)"
    fi
  fi

  if [[ -f "pom.xml" ]]; then
    local pver
    pver=$(grep -m1 '<version>' pom.xml | sed 's/.*<version>//; s/<\/version>.*//')
    if [[ -n "$pver" ]]; then
      detected_version="${detected_version:-$pver}"
      detected_files="${detected_files} pom.xml"
      detected_count=$((detected_count + 1))
      info "Detected Maven project (pom.xml)"
    fi
  fi

  # Use detected version or prompt for one
  if [[ -z "$detected_version" ]]; then
    printf "Enter current version (e.g., 0.1.0): "
    read -r detected_version
    if [[ -z "$detected_version" ]]; then
      detected_version="0.1.0"
      info "Using default: $detected_version"
    fi
  else
    echo ""
    info "Using detected version: $detected_version"
  fi

  # Ask which files to track
  echo ""
  if [[ $detected_count -gt 0 ]]; then
    info "Detected files with version info:"
    for f in $detected_files; do
      [[ -n "$f" ]] && echo "  - $f"
    done
    echo ""
    if ! confirm "Track these files for version replacement?"; then
      detected_files=""
      detected_count=0
    fi
  fi

  # Ask for additional files
  if confirm "Add additional files to track?"; then
    while true; do
      printf "File path (empty to finish): "
      read -r extra_file
      [[ -z "$extra_file" ]] && break
      detected_files="${detected_files} ${extra_file}"
      detected_count=$((detected_count + 1))
      if [[ -f "$extra_file" ]]; then
        info "Added: $extra_file"
      else
        warning "File does not exist yet: $extra_file (will be tracked anyway)"
      fi
    done
  fi

  # Generate config
  cat > "$config_file" << EOF
# Managed by Hanif CLI (hanif bv)
# Docs: hanif bv --help
#
# Workflow: patch/minor/major → creates RC → rc to iterate → release to promote
# Example: hanif bv patch → 1.0.1-rc0 → hanif bv rc → 1.0.1-rc1 → hanif bv release → 1.0.1
#
# commit: auto-commit version changes (True/False)
# tag: auto-create git tag (True/False)
# tag_name: tag template ({new_version} is replaced)
# parse: regex to decompose version into parts
# serialize: patterns to format version (first match wins)
# commit_message: template for commit ({current_version}, {new_version} replaced)

[bumpversion]
current_version = ${detected_version}
commit = True
tag = True
tag_name = v{new_version}
parse = (?P<major>\d+)\.(?P<minor>\d+)\.(?P<patch>\d+)(-(?P<release>rc)(?P<rc>\d+))?
serialize =
  {major}.{minor}.{patch}-{release}{rc}
  {major}.{minor}.{patch}
commit_message = Bump version: {current_version} → {new_version}

[bumpversion:part:release]
optional_value = ga
values =
  rc
  ga

[bumpversion:part:rc]
first_value = 0
EOF

  # Add file sections
  for file in $detected_files; do
    [[ -z "$file" ]] && continue
    echo "" >> "$config_file"
    echo "[bumpversion:file:${file}]" >> "$config_file"
  done

  echo ""
  success "Created $config_file"
  info "Current version: $detected_version"
  info "Tracked files: ${detected_files:-none}"
  echo ""
  info "Next steps:"
  echo "  hanif bv          # Interactive bump"
  echo "  hanif bv patch    # Bump patch version"
  echo "  hanif bv --help   # Full documentation"
}

# ─────────────────────────────────────────────
# Migrate
# ─────────────────────────────────────────────

bumpversion_migrate() {
  echo ""
  echo "Migrate from:"
  echo "  1) bump2version (.bumpversion.cfg)"
  echo "  2) tbump (tbump.toml)"
  echo "  3) Other (manual)"
  echo ""

  printf "Choose [1-3]: "
  read -r choice

  case "$choice" in
    1)
      migrate_from_bump2version
      ;;
    2)
      migrate_from_tbump
      ;;
    3)
      info "Run 'hanif bv init' to create a new config"
      ;;
    *)
      warning "Invalid choice"
      return 1
      ;;
  esac
}

migrate_from_bump2version() {
  local config_file=".bumpversion.cfg"

  if [[ ! -f "$config_file" ]]; then
    error "No .bumpversion.cfg found"
    return 1
  fi

  info "Validating existing .bumpversion.cfg..."

  if parse_bumpversion_config "$config_file"; then
    success "Config is valid and compatible!"
    info "Current version: $(_bv_get_config "current_version")"
    info "Files tracked: ${BV_FILE_LIST:-none}"
    echo ""

    if [[ $BV_SERIALIZE_COUNT -eq 0 ]]; then
      warning "No serialize patterns found. Adding defaults..."
      echo "serialize =" >> "$config_file"
      echo "  {major}.{minor}.{patch}-{release}{rc}" >> "$config_file"
      echo "  {major}.{minor}.{patch}" >> "$config_file"
    fi

    local release_opt
    release_opt=$(_bv_get_part "release" "optional_value")
    if [[ -z "$release_opt" ]]; then
      info "No release/rc part definitions found."
      if confirm "Add RC release support?"; then
        cat >> "$config_file" << 'EOF'

[bumpversion:part:release]
optional_value = ga
values =
  rc
  ga

[bumpversion:part:rc]
first_value = 0
EOF
        success "Added RC release support"
      fi
    fi

    success "Migration complete! Your existing config works as-is."
  else
    error "Config parsing failed. Please fix the config or run 'hanif bv init'"
    return 1
  fi
}

migrate_from_tbump() {
  local config_file="tbump.toml"

  if [[ ! -f "$config_file" ]]; then
    error "No tbump.toml found"
    return 1
  fi

  info "Reading tbump.toml..."

  local version
  version=$(grep -E '^current[[:space:]]*=' "$config_file" | head -1 | sed 's/.*=[[:space:]]*"//; s/".*//')

  if [[ -z "$version" ]]; then
    error "Could not extract version from tbump.toml"
    return 1
  fi

  info "Found version: $version"

  local files=""
  while IFS= read -r line; do
    local src
    src=$(echo "$line" | sed 's/.*src[[:space:]]*=[[:space:]]*"//; s/".*//')
    [[ -n "$src" ]] && files="${files} ${src}"
  done < <(grep 'src[[:space:]]*=' "$config_file")

  cat > ".bumpversion.cfg" << EOF
# Managed by Hanif CLI (hanif bv)
# Docs: hanif bv --help
#
# Workflow: patch/minor/major → creates RC → rc to iterate → release to promote
# Example: hanif bv patch → 1.0.1-rc0 → hanif bv rc → 1.0.1-rc1 → hanif bv release → 1.0.1

[bumpversion]
current_version = ${version}
commit = True
tag = True
tag_name = v{new_version}
parse = (?P<major>\d+)\.(?P<minor>\d+)\.(?P<patch>\d+)(-(?P<release>rc)(?P<rc>\d+))?
serialize =
  {major}.{minor}.{patch}-{release}{rc}
  {major}.{minor}.{patch}
commit_message = Bump version: {current_version} → {new_version}

[bumpversion:part:release]
optional_value = ga
values =
  rc
  ga

[bumpversion:part:rc]
first_value = 0
EOF

  for f in $files; do
    [[ -z "$f" ]] && continue
    echo "" >> ".bumpversion.cfg"
    echo "[bumpversion:file:${f}]" >> ".bumpversion.cfg"
  done

  success "Generated .bumpversion.cfg from tbump.toml"

  if confirm "Delete tbump.toml?"; then
    rm "$config_file"
    success "Deleted tbump.toml"
  fi
}
