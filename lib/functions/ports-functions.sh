#!/usr/bin/env bash
#
# ports-functions.sh — implementation of `hanif ports`.

_HANIF_PORTS_PORT_RE='^[0-9]+$'
_HANIF_PORTS_PID_RE='^[0-9]+$'

# Validate a port number string. Returns 0 if valid, 1 with error otherwise.
_hanif_ports_validate_port() {
  local port="$1"
  if [[ ! "$port" =~ $_HANIF_PORTS_PORT_RE ]] || (( port < 1 || port > 65535 )); then
    error "Invalid port: $port (must be 1-65535)"
    return 1
  fi
}

# Return rows of "port<TAB>pid<TAB>command" for listening sockets, optionally
# filtered to a single port. Backend is lsof if available, ss as a fallback.
_hanif_ports_collect() {
  local filter="${1:-}"
  if command_exists lsof; then
    local out
    if [[ -n "$filter" ]]; then
      out=$(lsof -nP -iTCP:"$filter" -sTCP:LISTEN 2>/dev/null || true)
    else
      out=$(lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null || true)
    fi
    # lsof columns: COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
    # NAME contains "host:port".
    echo "$out" | awk 'NR>1 {
      n = $NF
      sub(/.*:/, "", n)
      if (n ~ /^[0-9]+$/) {
        printf "%s\t%s\t%s\n", n, $2, $1
      }
    }' | sort -u
    return 0
  fi
  if command_exists ss; then
    local out
    if [[ -n "$filter" ]]; then
      out=$(ss -ltnp "sport = :$filter" 2>/dev/null || true)
    else
      out=$(ss -ltnp 2>/dev/null || true)
    fi
    # ss columns: State Recv-Q Send-Q Local Foreign Process
    echo "$out" | awk 'NR>1 {
      la = $4
      sub(/.*:/, "", la)
      proc = ""
      for (i=5; i<=NF; i++) proc = proc " " $i
      pid = ""
      cmd = ""
      if (match(proc, /pid=[0-9]+/)) {
        pid = substr(proc, RSTART+4, RLENGTH-4)
      }
      if (match(proc, /\("[^"]+"/)) {
        cmd = substr(proc, RSTART+2, RLENGTH-2)
        gsub(/"/, "", cmd)
      }
      if (la ~ /^[0-9]+$/) {
        printf "%s\t%s\t%s\n", la, (pid==""?"-":pid), (cmd==""?"-":cmd)
      }
    }' | sort -u
    return 0
  fi
  return 1
}

hanif_ports() {
  local sub="${1:-}"
  case "$sub" in
    kill)
      shift || true
      local port="${1:-}"
      local force=0
      shift || true
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --force|-f) force=1; shift ;;
          *) error "Unknown flag: $1"; return 1 ;;
        esac
      done
      if [[ -z "$port" ]]; then
        error "Usage: hanif ports kill <PORT> [--force]"
        return 1
      fi
      _hanif_ports_validate_port "$port" || return 1

      local rows
      rows=$(_hanif_ports_collect "$port") || {
        error "No listening-port lookup tool found (lsof or ss)"
        return 1
      }
      if [[ -z "$rows" ]]; then
        warning "Nothing listening on port $port"
        return 1
      fi

      info "Processes listening on port $port:"
      {
        printf '%s\t%s\t%s\n' PORT PID COMMAND
        echo "$rows"
      } | tail -n +2 | render_table "PORT|PID|COMMAND"

      # Collect unique PIDs to kill.
      local -a pids=()
      local pid
      while IFS=$'\t' read -r _ pid _; do
        if [[ -n "$pid" && "$pid" =~ $_HANIF_PORTS_PID_RE ]]; then
          # de-dup
          local seen=0 p
          for p in "${pids[@]:-}"; do
            [[ "$p" == "$pid" ]] && { seen=1; break; }
          done
          (( seen )) || pids+=("$pid")
        fi
      done <<< "$rows"

      if [[ ${#pids[@]} -eq 0 ]]; then
        error "No PIDs available to kill (insufficient permission?). Try with sudo."
        return 1
      fi

      local sig="TERM"
      (( force )) && sig="KILL"
      if ! confirm "Send SIG${sig} to PID(s) ${pids[*]}?"; then
        info "Aborted"
        return 1
      fi

      local rc=0
      for pid in "${pids[@]}"; do
        if kill -s "$sig" "$pid" 2>/dev/null; then
          success "Sent SIG${sig} to PID $pid"
        else
          error "Failed to signal PID $pid (try with sudo)"
          rc=1
        fi
      done
      return $rc
      ;;
    help|--help|-h)
      show_ports_help
      return 0
      ;;
    "")
      local rows
      rows=$(_hanif_ports_collect) || {
        error "No listening-port lookup tool found (lsof or ss)"
        hint "Install lsof: brew install lsof / sudo apt install lsof"
        return 1
      }
      if [[ -z "$rows" ]]; then
        info "No TCP ports are currently listening"
        return 0
      fi
      printf '%s\n' "$rows" | sort -n | render_table "PORT|PID|COMMAND"
      ;;
    *)
      # Bare port number → filter.
      _hanif_ports_validate_port "$sub" || return 1
      local rows
      rows=$(_hanif_ports_collect "$sub") || {
        error "No listening-port lookup tool found (lsof or ss)"
        return 1
      }
      if [[ -z "$rows" ]]; then
        info "Nothing listening on port $sub"
        return 0
      fi
      printf '%s\n' "$rows" | render_table "PORT|PID|COMMAND"
      ;;
  esac
}
