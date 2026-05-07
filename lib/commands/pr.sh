#!/usr/bin/env bash
#
# pr command — open the current branch's pull request page.
#
# Detects the remote host (GitHub, GitLab, Azure DevOps, Bitbucket) from
# `git remote get-url origin` and computes either:
#   * the existing PR URL if the host exposes a deterministic compare URL, or
#   * the "create PR" / compare URL the user can click to open one.
#
# Subcommands:
#   hanif pr          # open in default browser
#   hanif pr url      # print URL only
#   hanif pr copy     # copy URL to clipboard

register_command --name "pr" --group "Productivity" \
  --handler "pr_command" \
  --description "Open the current branch's pull request page"

pr_command() {
  case "${1:-}" in
    help|--help|-h)
      show_pr_help
      return 0
      ;;
  esac

  # shellcheck source=../functions/pr-functions.sh
  source "${FUNCTIONS_DIR}/pr-functions.sh"
  hanif_pr "$@"
}

show_pr_help() {
  print_banner "Open Pull Request URL"
  cat <<'EOF'

DESCRIPTION
  Compute the pull-request / compare URL for the current branch on
  the remote you push to (origin), and open it in your browser.
  Supports GitHub, GitLab, Azure DevOps, and Bitbucket Cloud.

USAGE
  hanif pr                 Open the PR/compare page in your browser
  hanif pr url             Print the URL only (no browser)
  hanif pr copy            Copy the URL to your clipboard
  hanif pr help            Show this help

OPTIONS
  --remote <name>          Use a different remote (default: origin)
  --base <branch>          Compare against a specific base branch
                           (default: auto-detect main / master)

EXAMPLES
  hanif pr
  hanif pr url
  hanif pr copy
  hanif pr --base develop

REMOTE DETECTION
  • github.com           → /<owner>/<repo>/compare/<base>...<head>?expand=1
  • gitlab.com / self    → /<owner>/<repo>/-/compare/<base>...<head>
  • dev.azure.com        → /<org>/<project>/_git/<repo>/pullrequestcreate?
                           sourceRef=<head>&targetRef=<base>
  • bitbucket.org        → /<owner>/<repo>/pull-requests/new?
                           source=<head>&dest=<base>

ENVIRONMENT
  HANIF_NO_BROWSER=1     Print the URL instead of opening a browser
                         (useful in CI / SSH sessions)

EOF
}
