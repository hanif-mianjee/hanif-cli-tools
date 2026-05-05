#!/usr/bin/env bash
#
# env command — manage exported environment variables persistently.
#
# Persists variables in a Hanif-managed file (``~/.hanif/env.sh`` for
# bash/zsh, ``~/.hanif/env.fish`` for fish) and wires the user's shell
# profile (``~/.zshrc``, ``~/.bashrc``/``~/.bash_profile``, or
# ``~/.config/fish/conf.d/hanif.fish``) to source it once on shell
# start. Touching the user's profile always asks first.

register_command --name "env" --aliases "e" --group "Other" \
  --handler "env_command" \
  --description "Manage persistent environment variables"

env_command() {
  # shellcheck source=../functions/env-functions.sh
  source "${FUNCTIONS_DIR}/env-functions.sh"

  local subcommand="${1:-}"
  shift 2>/dev/null || true

  case "$subcommand" in
    set|add)
      hanif_env_set "$@"
      ;;
    unset|rm|remove|del|delete)
      hanif_env_unset "$@"
      ;;
    list|ls|"")
      hanif_env_list "$@"
      ;;
    get|show)
      hanif_env_get "$@"
      ;;
    source|src)
      hanif_env_source_hint "$@"
      ;;
    edit)
      hanif_env_edit "$@"
      ;;
    path|paths|where)
      hanif_env_paths "$@"
      ;;
    help|--help|-h)
      show_env_help
      ;;
    *)
      error "Unknown env subcommand: $subcommand"
      echo ""
      show_env_usage
      return 1
      ;;
  esac
}

show_env_usage() {
  cat <<'EOF'
Env Commands:

Usage: hanif env <subcommand> [options]

Subcommands:
  set KEY=VALUE        Persist an environment variable (asks before write)
  set KEY VALUE        Same as above (space-separated form)
  unset KEY            Remove a persisted variable (asks for confirmation)
  list                 Show all persisted variables (tabular view)
  get KEY              Show persisted + currently-exported value for KEY
  source               Print the command to load vars into the current shell
  edit                 Open the managed env file in $EDITOR
  path                 Show the managed file & detected shell profile
  help                 Show detailed help

Examples:
  hanif env set API_KEY=sk-abc123
  hanif env set DATABASE_URL "postgres://localhost/db"
  hanif env list
  hanif env unset API_KEY

EOF
}

show_env_help() {
  print_banner "Persistent Environment Variables"
  cat <<'EOF'

DESCRIPTION
  Persist exported environment variables across shell sessions.
  Hanif writes vars to a managed file (~/.hanif/env.sh, or
  ~/.hanif/env.fish for fish) and wires your shell profile to
  source it on startup — your own profile is touched at most
  once (one idempotent line) and only after you confirm.

USAGE
  hanif env <subcommand> [options]

SUBCOMMANDS
  set KEY=VALUE          Persist a variable. Asks before writing
                         and warns when overwriting an existing value.
  set KEY VALUE          Same, space-separated form.
  unset KEY              Remove a persisted variable (asks first).
  list, ls               Tabular view of all persisted variables.
  get KEY                Show persisted value, currently-exported
                         value, and which file holds it.
  source                 Print the exact command to load the file
                         into your CURRENT shell (we cannot touch
                         the parent shell from a sub-process).
  edit                   Open the managed env file in $EDITOR.
  path, where            Show the managed file path and detected
                         shell profile.
  help                   Show this help.

PROFILE DETECTION
  • zsh   →  ~/.zshrc
  • bash  →  ~/.bash_profile (macOS) or ~/.bashrc (Linux)
  • fish  →  ~/.config/fish/conf.d/hanif.fish

  Override with HANIF_ENV_PROFILE=/path/to/profile

  Override the managed file with HANIF_ENV_FILE=/path/to/file.sh

EXAMPLES
  hanif env set API_KEY=sk-abc123
  hanif env set DATABASE_URL "postgres://user:pass@host/db"
  hanif env set EDITOR vim

  hanif env list
  hanif env get API_KEY
  hanif env unset API_KEY

  # Load into current shell (run yourself; sub-processes can't):
  source ~/.hanif/env.sh

SAFETY
  • KEY must match ^[A-Za-z_][A-Za-z0-9_]*$ — anything else is rejected.
  • VALUE is shell-quoted with printf '%q' before being written;
    nothing user-supplied is ever eval'd.
  • Profile edits are idempotent — Hanif appends a single block
    delimited by "# >>> hanif env >>>" / "# <<< hanif env <<<".
  • A timestamped backup of the managed file is created before
    every write (kept as <file>.bak).

EOF
}
