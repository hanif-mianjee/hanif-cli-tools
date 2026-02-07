#!/usr/bin/env bash

# SVG conversion functions for Hanif CLI

# Find the best available SVG converter
# Sets SVG_CONVERTER to: rsvg, inkscape, magick, or empty
find_svg_converter() {
  if command_exists rsvg-convert; then
    SVG_CONVERTER="rsvg"
    return 0
  elif command_exists inkscape; then
    SVG_CONVERTER="inkscape"
    return 0
  elif command_exists magick; then
    SVG_CONVERTER="magick"
    return 0
  fi

  SVG_CONVERTER=""
  return 1
}

# Print install instructions when no converter is found
svg_converter_not_found() {
  error "No suitable SVG converter found!"
  echo ""
  echo "Install one of these (recommended order):"
  echo "  1. librsvg (best): brew install librsvg"
  echo "  2. Inkscape:       brew install --cask inkscape"
  echo "  3. ImageMagick:    brew install imagemagick ghostscript"
}

# Convert a single SVG to PNG at a given size
# Usage: svg_to_png <input.svg> <size> <output.png>
svg_to_png() {
  local input="$1"
  local size="$2"
  local output="$3"

  case "$SVG_CONVERTER" in
    rsvg)
      rsvg-convert -w "$size" -h "$size" "$input" -o "$output"
      ;;
    inkscape)
      inkscape "$input" -w "$size" -h "$size" -o "$output" 2>/dev/null
      ;;
    magick)
      magick "$input" -background none -resize "${size}x${size}" "$output" 2>/dev/null
      if [[ ! -f "$output" ]] || [[ ! -s "$output" ]]; then
        error "ImageMagick conversion failed for size ${size}"
        return 1
      fi
      ;;
    *)
      error "No SVG converter set. Run find_svg_converter first."
      return 1
      ;;
  esac
}

# Convert SVG to multiple PNG sizes
# Usage: svg_to_pngs <input.svg> <output_dir> <prefix> <sizes...>
# Example: svg_to_pngs icon.svg ./out icon 16 32 48 128
svg_to_pngs() {
  local input="$1"
  local output_dir="$2"
  local prefix="$3"
  shift 3
  local sizes=("$@")

  if [[ ! -f "$input" ]]; then
    error "File not found: $input"
    return 1
  fi

  if ! find_svg_converter; then
    svg_converter_not_found
    return 1
  fi

  info "Using $SVG_CONVERTER for conversion..."

  # Create output directory if needed
  mkdir -p "$output_dir"

  local failed=0
  local created=()

  for size in "${sizes[@]}"; do
    local output="${output_dir}/${prefix}${size}.png"
    if svg_to_png "$input" "$size" "$output"; then
      created+=("$output")
    else
      failed=1
    fi
  done

  if [[ $failed -eq 0 ]]; then
    success "Created ${#created[@]} icons:"
    for f in "${created[@]}"; do
      echo "  $f"
    done
  else
    warning "Some conversions failed"
    return 1
  fi
}
