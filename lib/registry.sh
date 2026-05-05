#!/usr/bin/env bash
#
# Hanif CLI - Command Registry
#
# Lightweight, dependency-free command registry that lets new commands be added
# by dropping a single file into ``lib/commands/`` and calling
# ``register_command`` once at the top of that file.
#
# Each command file is expected to:
#   1. Sourcing ``lib/registry.sh`` is NOT required — ``bin/hanif`` does this.
#   2. Call ``register_command`` once per command (or alias group) it provides.
#   3. Define the handler function it referenced.
#
# Example (in ``lib/commands/foo.sh``):
#
#   register_command \
#       --name "foo" \
#       --aliases "f" \
#       --group "Other" \
#       --description "Do the foo thing" \
#       --handler "foo_command"
#
#   foo_command() { ... }
#
# Bash 3.2 compatible (no associative arrays).
# ---------------------------------------------------------------------------

# Guard against multiple sourcing.
if [[ -n "${HANIF_REGISTRY_LOADED:-}" ]]; then
  return 0
fi
readonly HANIF_REGISTRY_LOADED=1

# Parallel arrays make up the registry. Index N across all arrays describes one
# registered command.
HANIF_REG_NAMES=()        # primary command names, e.g. "sync"
HANIF_REG_ALIASES=()      # space-separated aliases, e.g. "newfeature nf"
HANIF_REG_HANDLERS=()     # function name to invoke
HANIF_REG_GROUPS=()       # display group, e.g. "Git", "Other"
HANIF_REG_DESCS=()        # short description for help output

# register_command — register a command with the dispatcher.
#
# Usage:
#   register_command --name <name> [--aliases "a b"] --handler <fn> \
#                    [--group <group>] [--description <text>]
#
# All flags must use the ``--flag value`` form (no equals sign). Order is
# unimportant. ``--name`` and ``--handler`` are required.
register_command() {
  local name="" aliases="" handler="" group="Other" description=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)        name="$2";        shift 2 ;;
      --aliases)     aliases="$2";     shift 2 ;;
      --handler)     handler="$2";     shift 2 ;;
      --group)       group="$2";       shift 2 ;;
      --description) description="$2"; shift 2 ;;
      *)
        echo "register_command: unknown option: $1" >&2
        return 1
        ;;
    esac
  done

  if [[ -z "$name" || -z "$handler" ]]; then
    echo "register_command: --name and --handler are required" >&2
    return 1
  fi

  HANIF_REG_NAMES+=("$name")
  HANIF_REG_ALIASES+=("$aliases")
  HANIF_REG_HANDLERS+=("$handler")
  HANIF_REG_GROUPS+=("$group")
  HANIF_REG_DESCS+=("$description")
}

# _registry_index_for — print the registry index for a name or alias, or
# return non-zero if not found.
_registry_index_for() {
  local query="$1"
  local i=0
  local total=${#HANIF_REG_NAMES[@]}

  while [[ $i -lt $total ]]; do
    if [[ "${HANIF_REG_NAMES[$i]}" == "$query" ]]; then
      echo "$i"
      return 0
    fi
    # Match aliases (space-separated word match).
    local alias
    for alias in ${HANIF_REG_ALIASES[$i]}; do
      if [[ "$alias" == "$query" ]]; then
        echo "$i"
        return 0
      fi
    done
    i=$((i + 1))
  done

  return 1
}

# dispatch_command — look up <name> in the registry and invoke its handler with
# the remaining arguments. Returns 127 if not found.
dispatch_command() {
  local query="${1:-}"
  shift || true

  if [[ -z "$query" ]]; then
    return 2
  fi

  local idx
  if ! idx=$(_registry_index_for "$query"); then
    return 127
  fi

  "${HANIF_REG_HANDLERS[$idx]}" "$@"
}

# registry_has — quiet boolean check used by callers (e.g. help).
registry_has() {
  _registry_index_for "$1" >/dev/null 2>&1
}

# registry_groups — print the list of unique groups in registration order.
registry_groups() {
  local seen=" "
  local i=0
  local total=${#HANIF_REG_GROUPS[@]}
  while [[ $i -lt $total ]]; do
    local g="${HANIF_REG_GROUPS[$i]}"
    if [[ "$seen" != *" $g "* ]]; then
      echo "$g"
      seen="$seen$g "
    fi
    i=$((i + 1))
  done
}

# registry_print_group — print a formatted listing of all commands belonging to
# a group. Output is suitable for the help screen.
registry_print_group() {
  local group="$1"
  local i=0
  local total=${#HANIF_REG_NAMES[@]}
  while [[ $i -lt $total ]]; do
    if [[ "${HANIF_REG_GROUPS[$i]}" == "$group" ]]; then
      local name="${HANIF_REG_NAMES[$i]}"
      local aliases="${HANIF_REG_ALIASES[$i]}"
      local desc="${HANIF_REG_DESCS[$i]}"
      local label="$name"
      # Show first alias inline (e.g. "nf, newfeature") to preserve the
      # original help layout.
      if [[ -n "$aliases" ]]; then
        local first_alias="${aliases%% *}"
        label="$name, $first_alias"
      fi
      printf '  %-22s %s\n' "$label" "$desc"
    fi
    i=$((i + 1))
  done
}

# registry_count — number of registered commands.
registry_count() {
  echo "${#HANIF_REG_NAMES[@]}"
}
