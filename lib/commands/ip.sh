#!/usr/bin/env bash
#
# ip command — show local + public IP info.

register_command --name "ip" --group "Productivity" \
  --handler "ip_command" \
  --description "Show local + public IP address"

ip_command() {
  case "${1:-}" in
    help|--help|-h)
      show_ip_help
      return 0
      ;;
  esac

  # shellcheck source=../functions/ip-functions.sh
  source "${FUNCTIONS_DIR}/ip-functions.sh"
  hanif_ip "$@"
}

show_ip_help() {
  print_banner "Local & Public IP"
  cat <<'EOF'

DESCRIPTION
  Show your machine's primary local (LAN) IPv4 address and your
  public (WAN) IPv4 address, along with the active interface.
  Public lookup uses https://api.ipify.org and respects offline
  mode (HANIF_OFFLINE=1).

USAGE
  hanif ip                 Show local + public IP (table)
  hanif ip local           Print local IP only
  hanif ip public          Print public IP only
  hanif ip copy [which]    Copy IP to clipboard (which: local|public, default: public)
  hanif ip help            Show this help

EXAMPLES
  hanif ip
  hanif ip local
  hanif ip copy local

ENVIRONMENT
  HANIF_OFFLINE=1          Skip the public IP lookup

EOF
}
