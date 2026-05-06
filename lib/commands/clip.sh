#!/usr/bin/env bash
#
# clip command — cross-platform clipboard helper.
#
# Wraps the host's native clipboard tool (pbcopy, xclip, xsel, wl-copy,
# clip.exe) behind a uniform interface so other Hanif commands and the
# user's own pipelines don't have to care which one is installed.
#
# Usage:
#   hanif clip                  # copy stdin to the clipboard
#   echo foo | hanif clip       # same
#   hanif clip < file.txt       # copy a file
#   hanif clip paste            # print clipboard contents to stdout
#   hanif clip detect           # show which backend is in use

register_command --name "clip" --group "Productivity" \
  --handler "clip_command" \
  --description "Cross-platform clipboard (copy/paste)"

clip_command() {
  local sub="${1:-}"
  case "$sub" in
    help|--help|-h)
      show_clip_help
      return 0
      ;;
    paste|p)
      if ! hanif_clip_paste; then
        error "No clipboard paste tool found (tried pbpaste/wl-paste/xclip/xsel/powershell.exe)"
        hint "Install one: brew install pbcopy / sudo apt install xclip / sudo apt install wl-clipboard"
        return 1
      fi
      return 0
      ;;
    detect)
      local copy_tool paste_tool
      copy_tool=$(_hanif_clip_copy_tool 2>/dev/null || echo "(none)")
      paste_tool=$(_hanif_clip_paste_tool 2>/dev/null || echo "(none)")
      kv "Copy"  "$copy_tool"
      kv "Paste" "$paste_tool"
      return 0
      ;;
    "")
      # Copy stdin to clipboard.
      if [[ -t 0 ]]; then
        error "Nothing to copy: pipe data into 'hanif clip' or use 'hanif clip < file'"
        echo ""
        show_clip_help
        return 1
      fi
      if ! hanif_clip_copy; then
        error "No clipboard copy tool found (tried pbcopy/xclip/xsel/wl-copy/clip.exe)"
        hint "Install one: brew install pbcopy / sudo apt install xclip / sudo apt install wl-clipboard"
        return 1
      fi
      success "Copied to clipboard"
      return 0
      ;;
    *)
      error "Unknown clip subcommand: $sub"
      echo ""
      show_clip_help
      return 1
      ;;
  esac
}

show_clip_help() {
  print_banner "Cross-Platform Clipboard"
  cat <<'EOF'

DESCRIPTION
  Copy stdin to the system clipboard, or paste the clipboard's
  contents to stdout. Auto-detects the right backend for your OS:
  pbcopy/pbpaste (macOS), wl-copy/wl-paste (Wayland), xclip,
  xsel (X11), or clip.exe (WSL/Windows).

USAGE
  hanif clip               Copy stdin to the clipboard
  hanif clip paste         Print clipboard contents to stdout
  hanif clip detect        Show the detected backend
  hanif clip help          Show this help

EXAMPLES
  echo "hello" | hanif clip
  hanif clip < notes.md
  cat ~/.ssh/id_ed25519.pub | hanif clip
  hanif clip paste > /tmp/clipboard.txt

ENVIRONMENT
  HANIF_CLIP_COPY    Force a specific copy backend (testing/override)
  HANIF_CLIP_PASTE   Force a specific paste backend (testing/override)

EOF
}
