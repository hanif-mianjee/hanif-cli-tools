#!/usr/bin/env bash

# SVG command handler for Hanif CLI

# Source SVG functions
# shellcheck source=../functions/svg-functions.sh
source "${FUNCTIONS_DIR}/svg-functions.sh"

# SVG subcommand dispatcher
svg_command() {
  if [[ $# -eq 0 ]]; then
    show_svg_usage
    exit 1
  fi

  local subcommand="$1"
  shift

  case "$subcommand" in
    convert|c)
      if [[ $# -lt 2 ]]; then
        error "Usage: hanif svg convert <input.svg> <sizes> [--prefix name] [--output-dir dir]"
        exit 1
      fi
      svg_convert_cmd "$@"
      ;;

    chrome|chrome-icons)
      if [[ $# -eq 0 ]]; then
        error "Usage: hanif svg chrome <input.svg> [--output-dir dir]"
        exit 1
      fi
      svg_chrome_cmd "$@"
      ;;

    help|--help|-h)
      show_svg_help
      ;;

    *)
      error "Unknown svg subcommand: $subcommand"
      echo ""
      show_svg_usage
      exit 1
      ;;
  esac
}

# Generic SVG to PNG conversion
svg_convert_cmd() {
  local input="$1"
  local sizes_str="$2"
  shift 2

  local prefix="icon"
  local output_dir="."

  # Parse optional flags
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prefix|-p)
        prefix="$2"
        shift 2
        ;;
      --output-dir|-o)
        output_dir="$2"
        shift 2
        ;;
      *)
        error "Unknown option: $1"
        exit 1
        ;;
    esac
  done

  # Parse comma-separated sizes
  IFS=',' read -ra sizes <<< "$sizes_str"

  # Validate sizes are numbers
  for s in "${sizes[@]}"; do
    if ! [[ "$s" =~ ^[0-9]+$ ]]; then
      error "Invalid size: $s (must be a number)"
      exit 1
    fi
  done

  svg_to_pngs "$input" "$output_dir" "$prefix" "${sizes[@]}"
}

# Chrome extension icon generation (preset sizes: 16, 32, 48, 128)
svg_chrome_cmd() {
  local input="$1"
  shift

  local output_dir="."

  # Parse optional flags
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --output-dir|-o)
        output_dir="$2"
        shift 2
        ;;
      *)
        error "Unknown option: $1"
        exit 1
        ;;
    esac
  done

  info "Generating Chrome extension icons..."
  svg_to_pngs "$input" "$output_dir" "icon" 16 32 48 128
}

# Show svg subcommand usage
show_svg_usage() {
  cat << 'EOF'
SVG Commands:

Usage: hanif svg <subcommand> [options]

Subcommands:
  convert, c     Convert SVG to PNG at custom sizes
  chrome         Generate Chrome extension icons (16,32,48,128)
  help           Show help

Examples:
  hanif svg convert icon.svg 64,128,256
  hanif svg convert logo.svg 100,200 --prefix logo --output-dir ./out
  hanif svg chrome icon.svg
  hanif svg chrome icon.svg --output-dir src/assets/icons

EOF
}

# Show detailed svg help
show_svg_help() {
  cat << 'EOF'
┌─────────────────────────────────────────────┐
│          SVG Conversion Commands            │
└─────────────────────────────────────────────┘

CONVERT (c)
  Convert any SVG to PNG at custom sizes

  hanif svg convert <input.svg> <sizes> [options]

  Sizes: comma-separated list of pixel dimensions
  Options:
    --prefix, -p <name>       Output filename prefix (default: icon)
    --output-dir, -o <dir>    Output directory (default: .)

  Examples:
    hanif svg convert logo.svg 64,128,256
      → icon64.png, icon128.png, icon256.png

    hanif svg convert logo.svg 100,200 --prefix logo --output-dir ./out
      → ./out/logo100.png, ./out/logo200.png

CHROME (chrome-icons)
  Generate standard Chrome extension icons

  hanif svg chrome <input.svg> [options]

  Generates: icon16.png, icon32.png, icon48.png, icon128.png
  Options:
    --output-dir, -o <dir>    Output directory (default: .)

  Example:
    hanif svg chrome src/icon.svg --output-dir src/assets/icons

SUPPORTED CONVERTERS (auto-detected)
  1. librsvg (best):   brew install librsvg
  2. Inkscape:         brew install --cask inkscape
  3. ImageMagick:      brew install imagemagick ghostscript

EOF
}
