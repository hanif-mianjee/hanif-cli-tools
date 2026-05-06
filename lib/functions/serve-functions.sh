#!/usr/bin/env bash
#
# serve-functions.sh — implementation of `hanif serve`.

_HANIF_SERVE_PORT_RE='^[0-9]+$'

hanif_serve() {
  local port="8000"
  local dir="."

  if [[ $# -ge 1 ]]; then
    port="$1"
  fi
  if [[ $# -ge 2 ]]; then
    dir="$2"
  fi

  if [[ ! "$port" =~ $_HANIF_SERVE_PORT_RE ]] || (( port < 1 || port > 65535 )); then
    error "Invalid port: $port (must be 1-65535)"
    return 1
  fi
  if (( port < 1024 )) && [[ "$(id -u 2>/dev/null || echo 1000)" != "0" ]]; then
    warning "Port $port is privileged (<1024); you may need sudo"
  fi
  if [[ ! -d "$dir" ]]; then
    error "Not a directory: $dir"
    return 1
  fi

  local abs
  abs=$(cd "$dir" && pwd) || { error "Cannot enter directory: $dir"; return 1; }

  # Show the URLs first.
  step "Serving" "$abs"
  kv "Local"  "http://localhost:${port}/"
  # Best-effort LAN URL using ip-functions if available.
  local lan_ip
  if [[ -f "${FUNCTIONS_DIR}/ip-functions.sh" ]]; then
    # shellcheck source=ip-functions.sh
    source "${FUNCTIONS_DIR}/ip-functions.sh"
    lan_ip=$(_hanif_ip_local 2>/dev/null || true)
    if [[ -n "$lan_ip" ]]; then
      kv "LAN"   "http://${lan_ip}:${port}/"
    fi
  fi
  hint "Press Ctrl+C to stop"
  echo ""

  # Pick a backend.
  local -a cmd=()
  if command_exists python3; then
    cmd=(python3 -m http.server "$port" --bind 0.0.0.0 --directory "$abs")
  elif command_exists python; then
    # Python 2 fallback. SimpleHTTPServer doesn't accept --directory; cd first.
    (
      cd "$abs" || exit 1
      exec python -m SimpleHTTPServer "$port"
    )
    return $?
  elif command_exists busybox; then
    cmd=(busybox httpd -f -p "0.0.0.0:${port}" -h "$abs")
  elif command_exists npx; then
    # Only use npx if `serve` is already installed/cached (no network install).
    if npx --no-install serve --version >/dev/null 2>&1; then
      cmd=(npx --no-install serve -l "tcp://0.0.0.0:${port}" "$abs")
    else
      error "No HTTP server backend found (python3, python, busybox httpd, or npx serve)"
      hint "Install one: brew install python3 / sudo apt install python3"
      return 1
    fi
  else
    error "No HTTP server backend found (python3, python, busybox httpd, or npx serve)"
    hint "Install one: brew install python3 / sudo apt install python3"
    return 1
  fi

  "${cmd[@]}"
}
