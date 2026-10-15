#!/usr/bin/env bash
# Regenerates the PWA icons in public/. Needs ImageMagick 6 (`convert`). The PNGs are committed,
# so this only needs to run when the icon design changes.
set -euo pipefail
cd "$(dirname "$0")/../public"
mkdir -p icons

PURPLE='#7D26CD'
FONT='DejaVu-Sans-Bold'

# Rounded tile with transparent corners, for `purpose: any`.
tile() {
  local s=$1 out=$2 r=$(( $1 * 22 / 100 ))
  convert -size "${s}x${s}" xc:none -fill "$PURPLE" \
    -draw "roundrectangle 0,0 $((s - 1)),$((s - 1)) $r,$r" \
    -fill white -font "$FONT" -pointsize $(( s * 46 / 100 )) -gravity center -annotate +0+0 '/p' -depth 8 "$out"
}

# Full-bleed square. The platform applies its own mask, so the glyph has to fit the central safe
# zone (a circle 80% of the width) to survive circular masks.
bleed() {
  local s=$1 pct=$2 out=$3
  convert -size "${s}x${s}" xc:"$PURPLE" \
    -fill white -font "$FONT" -pointsize $(( s * pct / 100 )) -gravity center -annotate +0+0 '/p' -depth 8 "$out"
}

tile 192 icons/pwa-192x192.png
tile 512 icons/pwa-512x512.png
bleed 512 34 icons/maskable-512x512.png
bleed 180 42 apple-touch-icon.png
