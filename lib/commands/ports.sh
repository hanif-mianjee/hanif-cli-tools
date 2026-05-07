#!/usr/bin/env bash
#
# ports command — inspect / kill processes listening on TCP ports.

register_command --name "ports" --group "Productivity" \
  --handler "ports_command" \
  --description "Inspect or kill processes listening on TCP ports"

ports_command() {
  case "${1:-}" in
    help|--help|-h)
      show_ports_help
      return 0
      ;;
  esac

  # shellcheck source=../functions/ports-functions.sh
  source "${FUNCTIONS_DIR}/ports-functions.sh"
  hanif_ports "$@"
}

show_ports_help() {
  print_banner "Listening Ports"
  cat <<'EOF'

DESCRIPTION
  Show which processes are listening on TCP ports, or kill the
  process holding a specific port. Uses lsof when available, falls
  back to ss (Linux). The "kill" subcommand asks for confirmation
  before sending a signal, and uses SIGTERM (15) by default.

USAGE
  hanif ports                    List all listening TCP ports
  hanif ports <PORT>             Show what's on a single port
  hanif ports kill <PORT>        SIGTERM the process on a port (asks first)
  hanif ports kill <PORT> --force  SIGKILL instead of SIGTERM
  hanif ports help               Show this help

EXAMPLES
  hanif ports
  hanif ports 3000
  hanif ports kill 3000
  hanif ports kill 5432 --force

NOTES
  • PORT must be an integer in 1-65535.
  • You may need sudo to see / kill processes you don't own.

EOF
}
