#!/usr/bin/env bash
#
# pre-commit command — install, manage, and run a `.git/hooks/pre-commit`
# script tailored to the project's detected stack(s).
#
# The command is fully interactive by default. It auto-detects which
# project stacks are in play (Node / Python / Rust / Go / Java / Ruby /
# PHP), shows a curated menu of common safety checks (universal +
# per-stack), lets the user add their own free-form shell commands, and
# writes the result as `.git/hooks/pre-commit`. The hook is delimited by
# marker comments so re-running this command updates the managed block
# in place without clobbering anything the user added manually.
#
# Subcommands:
#   (none) / setup     — interactive setup (the default flow)
#   list / ls / show   — show what's currently installed
#   remove / uninstall — remove the managed hook (or strip the managed block)
#   run / test         — execute the hook now (using the current staged set)
#   help / --help / -h — full help
#
# Heavy logic is lazy-loaded from lib/functions/pre-commit-functions.sh.

register_command --name "pre-commit" --aliases "pc" --group "Git" \
  --handler "pre_commit_command" \
  --description "Install / manage a .git/hooks/pre-commit script"

pre_commit_command() {
  local subcommand="${1:-}"

  case "$subcommand" in
    help|--help|-h)
      show_pre_commit_help
      return 0
      ;;
  esac

  # shellcheck source=../functions/pre-commit-functions.sh
  source "${FUNCTIONS_DIR}/pre-commit-functions.sh"

  case "$subcommand" in
    ""|setup|install|init)
      shift 2>/dev/null || true
      hanif_pre_commit_setup "$@"
      ;;
    list|ls|show|status)
      shift
      hanif_pre_commit_list "$@"
      ;;
    remove|uninstall|rm|delete)
      shift
      hanif_pre_commit_remove "$@"
      ;;
    run|test|exec)
      shift
      hanif_pre_commit_run "$@"
      ;;
    *)
      error "Unknown pre-commit subcommand: $subcommand"
      echo ""
      show_pre_commit_usage
      return 1
      ;;
  esac
}

show_pre_commit_usage() {
  cat <<'EOF'
Pre-Commit Hook Commands:

Usage: hanif pre-commit [subcommand]

Subcommands:
  (none) / setup     Interactive setup — detect stack, pick checks, install
  list               Show what's currently installed
  remove             Remove the managed hook (or strip just the managed block)
  run                Execute the hook now against the current staged set
  help               Show detailed help

Examples:
  hanif pre-commit              # walk through interactive setup
  hanif pc list                 # quick alias
  hanif pre-commit run          # dry-run the hook against staged files
  hanif pre-commit remove       # uninstall

EOF
}

show_pre_commit_help() {
  print_banner "Pre-Commit Hook Manager"
  cat <<'EOF'

DESCRIPTION
  Install and manage a per-repo `.git/hooks/pre-commit` script. Hanif
  auto-detects the project stack (Node, Python, Rust, Go, Java, Ruby,
  PHP — or none), shows a curated menu of common checks, lets you add
  your own commands, and writes a clean, readable hook to
  `.git/hooks/pre-commit`. Pure shell, no Husky, no Python, no Node —
  works in any repo regardless of language.

  Re-running this command updates the managed block in place. Anything
  you add outside the marker comments is preserved.

USAGE
  hanif pre-commit [subcommand]
  hanif pc        [subcommand]

SUBCOMMANDS
  (none) / setup     Interactive flow. Walks you through stack
                     detection → check picker → optional config
                     prompts → custom commands → review → install.
  list               Print whether a managed hook is installed,
                     when it was generated, and which checks it runs.
  remove             Uninstall. If the hook is purely managed, the
                     file is removed. If you've added content outside
                     the markers, only the managed block is stripped.
                     A timestamped backup is always written.
  run                Execute the hook now against the currently
                     staged set. Same exit code as if `git commit`
                     had triggered it. Useful for trying out a new
                     configuration without making a commit.
  help               Show this help.

CATALOG OF CHECKS

  Universal
    protect-branches         Block commits to specific branches (default: main, master)
    no-merge-markers         Reject staged content containing <<<<<<<, =======, >>>>>>>
    no-large-files           Reject staged files larger than N MB (default: 5)
    no-secrets               Scan for AWS keys, private-key headers, and
                             common token env-var assignments
    no-env-files             Reject staging .env files (allowlist:
                             .env.example, .env.sample by default)
    no-trailing-whitespace   Reject staged lines ending in whitespace
    no-debug                 Reject debugger / console.log / breakpoint() /
                             dd() / binding.pry / dbg!() depending on stack

  Node.js  (detected via package.json)
    node-lint                Run `npm/yarn/pnpm/bun run lint` (lockfile-aware)
    node-format              Prettier --check on staged .js/.ts/.jsx/.tsx
    node-test                Run the project's test script
    node-typecheck           tsc --noEmit

  Python  (pyproject.toml, setup.py, setup.cfg, requirements.txt)
    py-ruff                  ruff check on staged .py
    py-format                ruff format --check (falls back to black --check)
    py-mypy                  mypy on staged .py
    py-pytest                pytest

  Rust  (Cargo.toml)
    rust-fmt                 cargo fmt --all -- --check
    rust-clippy              cargo clippy -- -D warnings
    rust-test                cargo test

  Go  (go.mod)
    go-fmt                   gofmt -l (any output = fail)
    go-vet                   go vet ./...
    go-test                  go test ./...

  Java  (pom.xml, build.gradle, build.gradle.kts)
    java-maven               mvn -q verify
    java-gradle              ./gradlew check

  Ruby  (Gemfile)
    ruby-rspec               bundle exec rspec

  PHP  (composer.json)
    php-composer-test        composer test

  Custom
    Add any number of free-form shell commands. Each is embedded
    as its own labelled check block in the generated hook.

INTERACTIVE FLOW
  1. Hanif detects which project stacks are present.
  2. You see a numbered menu of all applicable checks (universal +
     per-stack) and pick a subset via comma/space-separated numbers.
     Shortcuts: `all`, `none`, `universal`, `recommended` (or just
     press Enter to accept `recommended`).
  3. If you picked `protect-branches`, `no-large-files`, or
     `no-env-files`, follow-up prompts let you tune their config.
  4. Optional: enter one or more custom shell commands.
  5. Review the selection, confirm, and Hanif writes the hook.

GENERATED HOOK
  Lives at `.git/hooks/pre-commit` and is `chmod 755`. Structure:

    #!/usr/bin/env bash
    # >>> hanif pre-commit: managed >>>
    # ... header (timestamp, stacks, selected check IDs) ...
    # ... one labelled block per selected check ...
    # <<< hanif pre-commit: managed <<<

  Each check is a small function. The hook accumulates failures
  across all checks (no fail-fast) so you see every problem at once.
  Missing tools (e.g. `cargo` not installed) are skipped with a faint
  hint instead of failing.

ENVIRONMENT (mostly for testing & automation)
  HANIF_PRE_COMMIT_ROOT             Treat this directory as the repo root.
  HANIF_PRE_COMMIT_YES=1            Auto-accept all interactive confirms.
  HANIF_PRE_COMMIT_CHECKS="<ids>"   Pre-select the comma/space-separated
                                    list of check IDs (skips the picker).
  HANIF_PRE_COMMIT_CUSTOM="<cmds>"  Newline-separated custom commands
                                    (skips the custom-command prompt).
  HANIF_PRE_COMMIT_PROTECTED_BRANCHES   Default `main master`.
  HANIF_PRE_COMMIT_MAX_FILE_MB          Default `5`.
  HANIF_PRE_COMMIT_ENV_ALLOWLIST    Default `.env.example .env.sample`.

  At commit time, the generated hook honours:
  HANIF_PRECOMMIT_SKIP=<ids>   Skip the listed checks for this commit.

SAFETY
  • Existing hooks that are NOT marker-managed are backed up to
    `.git/hooks/pre-commit.bak.<UTC-timestamp>` before being replaced.
  • Existing hooks that ARE marker-managed have only the managed
    block replaced; user-added content (outside the markers) is kept.
  • The repo must be a non-bare git repository.
  • If `git config core.hooksPath` is set to a location outside
    `.git/hooks`, Hanif warns but still writes to `.git/hooks` (the
    standard, git-native location). Unset `core.hooksPath` to let
    your new hook run automatically on commit.

EXAMPLES
  hanif pre-commit                  # walk through interactive setup
  hanif pc                          # same — short alias
  hanif pre-commit list             # what's installed?
  hanif pre-commit run              # dry-run the hook
  hanif pre-commit remove           # uninstall (with backup)

  # Non-interactive (CI / automation):
  HANIF_PRE_COMMIT_YES=1 \
  HANIF_PRE_COMMIT_CHECKS=protect-branches,no-merge-markers,no-secrets \
    hanif pre-commit

  # Skip a noisy check just this once at commit time:
  HANIF_PRECOMMIT_SKIP=node-test git commit -m "wip"

EOF
}
