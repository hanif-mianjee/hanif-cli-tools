#!/usr/bin/env bash
#
# git-setup command — one-shot setup for a new git profile.
#
# Hanif (and many devs) juggles several git identities (work, personal,
# freelance, experiments, …). Each identity wants its own name/email and
# its own SSH key, and you want git to pick the right one automatically
# based on where the repo lives on disk. This command walks the user
# through that setup once and wires everything up:
#
#   1. Pick a profile name (e.g. "work") and a directory all repos for
#      that profile will live under (default: ~/code/<profile>).
#   2. Generate an ed25519 SSH key dedicated to the profile.
#   3. Write a per-profile gitconfig file with user.name / user.email
#      and a core.sshCommand pinned to the new key.
#   4. Append an idempotent ``includeIf "gitdir:<dir>/"`` block to the
#      user's ~/.gitconfig so git auto-loads the per-profile config
#      whenever they're working inside that directory.
#   5. Print the public key plus copy-pasteable instructions for adding
#      it to GitHub / Azure DevOps.
#
# Subsequent profiles are a single command — that is the whole point.

register_command --name "gsetup" --aliases "git-setup" --group "Git" \
  --handler "git_setup_handler" \
  --description "Set up a new git profile (config + SSH key)"

git_setup_handler() {
  case "${1:-}" in
    help|--help|-h) show_git_setup_help; return 0 ;;
  esac
  # shellcheck source=../functions/git-setup-functions.sh
  source "${FUNCTIONS_DIR}/git-setup-functions.sh"
  hanif_git_setup "$@"
}

show_git_setup_help() {
  print_banner "Set Up a New Git Profile"
  cat <<'EOF'

DESCRIPTION
  One-shot setup for a new git identity (work, personal, freelance,
  experiments, …). Generates a dedicated SSH key, writes a per-profile
  gitconfig, and wires ~/.gitconfig with an `includeIf` block so git
  picks the right name/email AND the right SSH key automatically based
  on which directory your repo lives in. No per-repo configuration.

USAGE
  hanif gsetup [profile-name]
  hanif git-setup [profile-name]

ARGUMENTS
  profile-name      Optional. Short label for the profile (e.g. "work",
                    "personal"). Must match: ^[A-Za-z0-9_-]+$
                    If omitted, you'll be prompted.

INTERACTIVE PROMPTS
  • Profile name              (skipped if passed as argument)
  • Repos directory           (default: ~/code/<profile>)
  • Git user.name
  • Git user.email
  • Confirmation before any file is created or modified

WHAT IT WRITES
  ~/.ssh/id_ed25519_<profile>      Private key (chmod 600)
  ~/.ssh/id_ed25519_<profile>.pub  Public key  (chmod 644)
  ~/.gitconfig-<profile>           Per-profile gitconfig with
                                   user.name / user.email and
                                   core.sshCommand pinned to the key
  ~/.gitconfig                     Idempotent block appended:
                                     [includeIf "gitdir:<dir>/"]
                                       path = ~/.gitconfig-<profile>

  Marker comments delimit the block so re-running this command for the
  SAME profile updates in place instead of duplicating.

WHAT IT PRINTS
  The public key and copy-pasteable instructions for adding it to
  GitHub (https://github.com/settings/keys) and Azure DevOps
  (User Settings → SSH public keys).

SAFETY
  • Profile name validated against ^[A-Za-z0-9_-]+$ before any file is
    touched.
  • Existing SSH key for the same profile is detected and reused after
    confirmation (re-using means we never silently overwrite a key
    that's already trusted by GitHub / Azure DevOps).
  • Existing per-profile gitconfig is detected and overwrite is
    confirmed.
  • The `includeIf` block in ~/.gitconfig is delimited by
    `# >>> hanif gsetup: <profile> >>>` /
    `# <<< hanif gsetup: <profile> <<<` so it can be safely re-rendered.
  • Repos directory is created with `mkdir -p` only after confirmation.

OVERRIDES (mostly for testing)
  HANIF_GSETUP_HOME            Use this dir instead of $HOME for all
                               file paths (key, gitconfigs, includes).
  HANIF_GSETUP_SKIP_KEYGEN=1   Skip the real `ssh-keygen` invocation —
                               an empty placeholder key is created
                               instead. Used by the test suite.

EXAMPLES
  hanif gsetup work
  hanif gsetup personal
  hanif git-setup freelance

EOF
}
