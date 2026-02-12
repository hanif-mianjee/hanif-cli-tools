#!/usr/bin/env bash

# Bumpversion command handler for Hanif CLI

# Source bumpversion functions
# shellcheck source=../functions/bumpversion-functions.sh
source "${FUNCTIONS_DIR}/bumpversion-functions.sh"

# Bumpversion command dispatcher
bumpversion_command() {
  local subcommand="${1:-}"
  shift 2>/dev/null || true

  case "$subcommand" in
    init)
      bumpversion_init "$@"
      ;;
    migrate)
      bumpversion_migrate "$@"
      ;;
    patch|minor|major|rc|release)
      bump_version "$subcommand" "$@"
      ;;
    ""|bump)
      interactive_bump "$@"
      ;;
    help|--help|-h)
      show_bumpversion_help
      ;;
    *)
      error "Unknown subcommand: $subcommand"
      echo ""
      show_bumpversion_usage
      return 1
      ;;
  esac
}

# Show bumpversion usage (short form)
show_bumpversion_usage() {
  cat << 'EOF'
Bumpversion Command:

Usage: hanif bumpversion <subcommand>
       hanif bv <subcommand>

Subcommands:
  (none) / bump   Interactive bump with preview
  patch            Bump patch version
  minor            Bump minor version
  major            Bump major version
  rc               Bump release candidate
  release          Promote RC to release
  init             Initialize .bumpversion.cfg
  migrate          Migrate from another tool

For detailed help: hanif bv --help

EOF
}

# Show detailed bumpversion help
show_bumpversion_help() {
  cat << 'EOF'
┌─────────────────────────────────────────────┐
│           Version Bumping Tool              │
└─────────────────────────────────────────────┘

DESCRIPTION
  A bump2version-compatible version bumping tool built natively
  into Hanif CLI. Manages semantic versioning with release
  candidate support, updates version strings across files, and
  handles git commits and tags.

USAGE
  hanif bumpversion [subcommand]
  hanif bv [subcommand]

SUBCOMMANDS
  (none) / bump    Interactive bump with preview menu
  patch            Bump patch version    (1.0.0 → 1.0.1-rc0)
  minor            Bump minor version    (1.0.0 → 1.1.0-rc0)
  major            Bump major version    (1.0.0 → 2.0.0-rc0)
  rc               Bump RC number        (1.0.1-rc0 → 1.0.1-rc1)
  release          Promote to release    (1.0.1-rc1 → 1.0.1)
  init             Initialize config for this project
  migrate          Migrate from bump2version, tbump, etc.
  help             Show this help

CONFIG (.bumpversion.cfg)
  [bumpversion]
    current_version    Current version string
    commit             Auto-commit on bump (True/False)
    tag                Auto-tag on bump (True/False)
    tag_name           Tag template (default: v{new_version})
    parse              Regex to parse version parts
    serialize          Patterns to format version string
    commit_message     Commit message template

  [bumpversion:part:<name>]
    first_value        Initial value for this part
    optional_value     Value that makes this part "absent"
    values             Ordered list of allowed values

  [bumpversion:file:<path>]
    search             Pattern to find (default: {current_version})
    replace            Replacement (default: {new_version})

WORKFLOW
  1. Initialize:     hanif bv init
  2. Develop:        (make changes, commit)
  3. Bump RC:        hanif bv patch     → 1.0.1-rc0
  4. Test & iterate: hanif bv rc        → 1.0.1-rc1
  5. Release:        hanif bv release   → 1.0.1
  6. Repeat from 2

EXAMPLES
  # Set up in a new project
  hanif bv init

  # Interactive bump (shows menu with previews)
  hanif bv

  # Direct version bumps
  hanif bv patch        # 1.0.0 → 1.0.1-rc0
  hanif bv minor        # 1.0.0 → 1.1.0-rc0
  hanif bv major        # 1.0.0 → 2.0.0-rc0
  hanif bv rc           # 1.0.1-rc0 → 1.0.1-rc1
  hanif bv release      # 1.0.1-rc1 → 1.0.1

  # Migrate from bump2version
  hanif bv migrate

TIPS
  • All bumps (patch/minor/major) produce RC versions by default
  • Use 'release' to promote an RC to a clean version
  • Interactive mode shows previews and includes a custom version option
  • The 'rc' command only works on RC versions (not stable releases)
  • Set commit = False or tag = False in config to disable auto-commit/tag
  • Config format is backward-compatible with bump2version
  • Tag conflicts are detected and can be resolved interactively
  • Missing config prompts to run 'hanif bv init' automatically

EOF
}
