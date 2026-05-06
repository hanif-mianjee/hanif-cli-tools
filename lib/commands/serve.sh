#!/usr/bin/env bash
#
# serve command — start a one-shot static HTTP server in the current dir.

register_command --name "serve" --group "Productivity" \
  --handler "serve_command" \
  --description "One-shot static HTTP server in the current directory"

serve_command() {
  case "${1:-}" in
    help|--help|-h)
      show_serve_help
      return 0
      ;;
  esac

  # shellcheck source=../functions/serve-functions.sh
  source "${FUNCTIONS_DIR}/serve-functions.sh"
  hanif_serve "$@"
}

show_serve_help() {
  print_banner "Static HTTP Server"
  cat <<'EOF'

DESCRIPTION
  Start a one-shot static HTTP server serving files from a
  directory. Picks the first available backend:
    1. python3 -m http.server  (built-in, no install needed)
    2. python  -m SimpleHTTPServer
    3. npx serve  (only if already cached)
    4. busybox httpd

USAGE
  hanif serve [PORT] [DIR]
  hanif serve help

ARGS
  PORT     TCP port to listen on (default: 8000, must be 1024-65535)
  DIR      Directory to serve (default: current directory)

EXAMPLES
  hanif serve                 # 8000 in cwd
  hanif serve 3000            # port 3000 in cwd
  hanif serve 3000 ./dist     # port 3000 in ./dist
  hanif serve 8080 docs/

NOTES
  • Press Ctrl+C to stop.
  • The server binds to 0.0.0.0 so other machines on your LAN can
    reach it via the LAN URL printed at start-up.
  • The server exposes file contents — do not run it in directories
    holding secrets or private keys.

EOF
}
