#!/usr/bin/env bash
#
# ip-functions.sh — implementation of `hanif ip`.

# Strict regex for an IPv4 address.
_HANIF_IP_RE='^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'

# Detect the primary local IPv4 address. Echos the address or empty.
_hanif_ip_local() {
  local ip=""
  if [[ "$(uname -s)" == "Darwin" ]]; then
    # Try the active interface in priority order.
    local iface
    for iface in en0 en1 en2 en3 en4; do
      if command_exists ipconfig; then
        ip=$(ipconfig getifaddr "$iface" 2>/dev/null || true)
        [[ -n "$ip" ]] && { echo "$ip"; return 0; }
      fi
    done
    if command_exists ifconfig; then
      ip=$(ifconfig 2>/dev/null \
        | awk '/^[a-z0-9]+:/{iface=$1} /inet /{print iface,$2}' \
        | awk '$2!="127.0.0.1"{print $2; exit}')
      [[ -n "$ip" ]] && { echo "$ip"; return 0; }
    fi
  else
    # Linux / WSL.
    if command_exists hostname; then
      ip=$(hostname -I 2>/dev/null | awk '{print $1}')
      [[ -n "$ip" ]] && { echo "$ip"; return 0; }
    fi
    if command_exists ip; then
      ip=$(command ip -4 -o addr show scope global 2>/dev/null \
        | awk '{print $4}' | awk -F/ '{print $1}' | head -n1)
      [[ -n "$ip" ]] && { echo "$ip"; return 0; }
    fi
    if command_exists ifconfig; then
      ip=$(ifconfig 2>/dev/null | awk '/inet /{print $2}' \
        | grep -v '^127\.' | head -n1)
      [[ -n "$ip" ]] && { echo "$ip"; return 0; }
    fi
  fi
  return 1
}

# Detect the active interface name. Best-effort, may be empty.
_hanif_ip_iface() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    if command_exists route; then
      route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}'
      return 0
    fi
  else
    if command_exists ip; then
      command ip route 2>/dev/null | awk '/^default/{print $5; exit}'
      return 0
    fi
  fi
}

# Public IP via api.ipify.org. Honors HANIF_OFFLINE.
_hanif_ip_public() {
  if [[ -n "${HANIF_OFFLINE:-}" ]]; then
    return 1
  fi
  if ! command_exists curl; then
    return 1
  fi
  local ip
  ip=$(curl -fsS --max-time 4 https://api.ipify.org 2>/dev/null || true)
  if [[ -n "$ip" && "$ip" =~ $_HANIF_IP_RE ]]; then
    echo "$ip"
    return 0
  fi
  return 1
}

hanif_ip() {
  local sub="${1:-}"
  case "$sub" in
    local)
      local local_ip
      if local_ip=$(_hanif_ip_local); then
        echo "$local_ip"
        return 0
      fi
      error "Could not determine local IP"
      return 1
      ;;
    public)
      local public_ip
      if public_ip=$(_hanif_ip_public); then
        echo "$public_ip"
        return 0
      fi
      error "Could not determine public IP"
      hint "Check your internet connection or unset HANIF_OFFLINE"
      return 1
      ;;
    copy)
      local which="${2:-public}"
      local addr=""
      case "$which" in
        local)  addr=$(_hanif_ip_local 2>/dev/null || true) ;;
        public) addr=$(_hanif_ip_public 2>/dev/null || true) ;;
        *) error "Unknown 'ip copy' target: $which (use local|public)"; return 1 ;;
      esac
      if [[ -z "$addr" ]]; then
        error "Could not determine $which IP"
        return 1
      fi
      if printf '%s' "$addr" | hanif_clip_copy; then
        success "Copied $which IP to clipboard: $addr"
      else
        warning "No clipboard tool available — IP: $addr"
        return 1
      fi
      ;;
    ""|show)
      local local_ip public_ip iface
      local_ip=$(_hanif_ip_local 2>/dev/null || true)
      public_ip=$(_hanif_ip_public 2>/dev/null || true)
      iface=$(_hanif_ip_iface 2>/dev/null || true)

      kv "Local IP"   "${local_ip:-(unknown)}"
      kv "Public IP"  "${public_ip:-(unavailable)}"
      [[ -n "$iface" ]] && kv "Interface"  "$iface"
      ;;
    *)
      error "Unknown ip subcommand: $sub"
      return 1
      ;;
  esac
}
