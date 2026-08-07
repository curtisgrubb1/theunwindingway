#!/usr/bin/env python3
"""
The Way — mark generator

Two marks, one source, so the site and the app can never drift.

  THE SEAL      Hexagram 24 (Return) inside an open circle.
                The single yang line coming back at the bottom after five lines
                of darkness — the turning point — held in an ensō that stays
                open, because what is true keeps inviting further.
                Used at small sizes: app icon, favicons, touch icons.

  THE COMPASS   The double bagua. Earlier Heaven outside, Later Heaven inside,
                both broken by the same opening. Built the way a luopan is
                built: concentric rings, each carrying its own system.
                Used large, where it can be read: launch screen, site header.

Requires Pillow (`pip install Pillow`). Only needed to regenerate — the outputs
are committed.

    python3 tools/make-marks.py
"""

import math
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(HERE)
REPO = os.path.dirname(APP)

INK = (14, 14, 12)
CREAM = (233, 223, 203)
GOLD = (196, 149, 106)

SS = 4                    # supersample, for clean edges at any output size
GAP_DEG = 46              # the opening, centred at the top
ARC_START = -90 + GAP_DEG / 2
ARC_SWEEP = 360 - GAP_DEG

# Trigrams, in the app's own convention: index 0 is the bottom line.
TRI = {'heaven': '111', 'earth': '000', 'water': '010', 'fire': '101',
       'thunder': '100', 'mountain': '001', 'wind': '011', 'lake': '110'}

# Clockwise from the top, South at top per Chinese convention.
# Earlier Heaven (Fu Xi): every trigram faces its exact inverse.
EARLIER = [('heaven', 0), ('wind', 45), ('water', 90), ('mountain', 135),
           ('earth', 180), ('thunder', 225), ('fire', 270), ('lake', 315)]
# Later Heaven (King Wen): the directional and seasonal arrangement.
LATER = [('fire', 0), ('earth', 45), ('lake', 90), ('heaven', 135),
         ('water', 180), ('mountain', 225), ('thunder', 270), ('wind', 315)]


def enso(d, cx, cy, r, w_max, color, taper=0.30):
    """An open circle drawn as a brush stroke — full weight through the belly,
    thinning toward both ends. Rendered as overlapping dots so the width can
    vary continuously, which an arc primitive cannot do."""
    steps = 1600
    for i in range(steps):
        t = i / (steps - 1)
        a = math.radians(ARC_START + ARC_SWEEP * t)
        # thin at both ends, full in the middle
        ease = math.sin(math.pi * t) ** 0.55
        w = w_max * (taper + (1 - taper) * ease)
        x, y = cx + r * math.cos(a), cy + r * math.sin(a)
        d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=color)


def hexagram24(d, cx, cy, width, solid=GOLD, broken=CREAM):
    """Five yin lines above one yang — Return. Geometry from the original mark."""
    unit = width / 44.80
    bar_h = 3.10 * unit
    seg_w = 16.58 * unit
    gap = 11.24 * unit
    rows = [11.82, 19.27, 26.72, 34.17, 41.62, 49.08]
    total_h = (49.08 + 3.10 - 11.82) * unit
    top = cy - total_h / 2
    left = cx - width / 2
    for idx, ry in enumerate(rows):
        y = top + (ry - 11.82) * unit
        if idx == 5:
            d.rectangle([left, y, left + width, y + bar_h], fill=solid)
        else:
            d.rectangle([left, y, left + seg_w, y + bar_h], fill=broken)
            d.rectangle([left + seg_w + gap, y, left + width, y + bar_h], fill=broken)


def trigram_ring(d, cx, cy, radii, half, th, gap, color, arrangement, offset=0.0):
    def bar(bx, by, ux, uy, vx, vy, a, b):
        pts = []
        for s, t in ((a, -1), (b, -1), (b, 1), (a, 1)):
            pts.append((bx + vx * s + ux * th / 2 * t, by + vy * s + uy * th / 2 * t))
        d.polygon(pts, fill=color)

    for name, deg in arrangement:
        a = math.radians(deg + offset)
        ux, uy = math.sin(a), -math.cos(a)     # outward
        vx, vy = math.cos(a), math.sin(a)      # tangent
        for i, ch in enumerate(TRI[name]):
            r = radii[i]
            bx, by = cx + ux * r, cy + uy * r
            if ch == '1':
                bar(bx, by, ux, uy, vx, vy, -half, half)
            else:
                bar(bx, by, ux, uy, vx, vy, -half, -gap / 2)
                bar(bx, by, ux, uy, vx, vy, gap / 2, half)


def seal(size, scale=1.0, bg=INK, alpha=False):
    """Hexagram 24 inside the open circle."""
    n = size * SS
    mode = 'RGBA' if alpha else 'RGB'
    base = (0, 0, 0, 0) if alpha else bg
    img = Image.new(mode, (n, n), base)
    d = ImageDraw.Draw(img)
    c = n / 2
    enso(d, c, c, n * 0.372 * scale, n * 0.052 * scale, GOLD)
    hexagram24(d, c, c, n * 0.400 * scale)
    return img.resize((size, size), Image.LANCZOS)


def compass(size, bg=INK, alpha=False):
    """The double bagua, interleaved on a single band.

    Both arrangements sit at the same radius, Later Heaven offset by 22.5° into
    the gaps of Earlier Heaven — sixteen trigrams in one ring. This works only
    because the two arrangements are completely disjoint: no trigram holds the
    same position in both, so nothing collides and both can be read.

    Concentric rings were the other option, the way a luopan is built, but the
    inner ring has a third of the circumference and the same eight trigrams to
    carry, so they merge into a blur. One band keeps every trigram legible."""
    n = size * SS
    mode = 'RGBA' if alpha else 'RGB'
    base = (0, 0, 0, 0) if alpha else bg
    img = Image.new(mode, (n, n), base)
    d = ImageDraw.Draw(img)
    c = n / 2
    enso(d, c, c, n * 0.440, n * 0.030, GOLD)
    radii = [n * 0.262, n * 0.307, n * 0.352]
    trigram_ring(d, c, c, radii, n * 0.056, n * 0.0175, n * 0.030, CREAM, EARLIER)
    trigram_ring(d, c, c, radii, n * 0.056, n * 0.0175, n * 0.030, GOLD, LATER, offset=22.5)
    return img.resize((size, size), Image.LANCZOS)


def seal_svg():
    """Vector seal, for favicon.svg. Uniform stroke with round caps — the taper
    is invisible at 16px and an even stroke scales more predictably."""
    S = 64.0
    c = S / 2
    r = S * 0.372
    a1 = math.radians(ARC_START)
    a2 = math.radians(ARC_START + ARC_SWEEP)
    x1, y1 = c + r * math.cos(a1), c + r * math.sin(a1)
    x2, y2 = c + r * math.cos(a2), c + r * math.sin(a2)

    width = S * 0.400
    unit = width / 44.80
    bar_h = 3.10 * unit
    seg_w = 16.58 * unit
    gap = 11.24 * unit
    rows = [11.82, 19.27, 26.72, 34.17, 41.62, 49.08]
    total_h = (49.08 + 3.10 - 11.82) * unit
    top = c - total_h / 2
    left = c - width / 2

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">',
        f'<rect width="64" height="64" fill="#0E0E0C"/>',
        f'<path d="M {x1:.2f} {y1:.2f} A {r:.2f} {r:.2f} 0 1 1 {x2:.2f} {y2:.2f}" '
        f'fill="none" stroke="#C4956A" stroke-width="{S*0.038:.2f}" stroke-linecap="round"/>',
    ]
    for idx, ry in enumerate(rows):
        y = top + (ry - 11.82) * unit
        if idx == 5:
            parts.append(f'<rect x="{left:.2f}" y="{y:.2f}" width="{width:.2f}" '
                         f'height="{bar_h:.2f}" fill="#C4956A"/>')
        else:
            parts.append(f'<rect x="{left:.2f}" y="{y:.2f}" width="{seg_w:.2f}" '
                         f'height="{bar_h:.2f}" fill="#E9DFCB"/>')
            parts.append(f'<rect x="{left+seg_w+gap:.2f}" y="{y:.2f}" width="{seg_w:.2f}" '
                         f'height="{bar_h:.2f}" fill="#E9DFCB"/>')
    parts.append('</svg>')
    return '\n'.join(parts)


def write(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, 'PNG')
    print('  ' + os.path.relpath(path, REPO))


print('\nThe Way — generating marks\n')

# App Store icon: 1024, no alpha, square corners. Apple applies the rounding.
write(seal(1024), os.path.join(APP, 'ios-assets', 'AppIcon-1024.png'))

# Launch screen and site header.
write(compass(2048), os.path.join(APP, 'ios-assets', 'launch-compass-2048.png'))
write(compass(1600, alpha=True), os.path.join(REPO, 'compass.png'))

# Site icons.
for name, size in [('favicon-16.png', 16), ('favicon-32.png', 32),
                   ('favicon-96.png', 96), ('apple-touch-icon.png', 180),
                   ('icon-512.png', 512)]:
    write(seal(size), os.path.join(REPO, name))

write(seal(192), os.path.join(REPO, 'icons', 'icon-192.png'))
write(seal(512), os.path.join(REPO, 'icons', 'icon-512.png'))

# Maskable icons get a safe zone: Android may crop to a circle of 80%.
write(seal(192, scale=0.72), os.path.join(REPO, 'icons', 'icon-192-maskable.png'))
write(seal(512, scale=0.72), os.path.join(REPO, 'icons', 'icon-512-maskable.png'))

with open(os.path.join(REPO, 'favicon.svg'), 'w') as f:
    f.write(seal_svg() + '\n')
print('  favicon.svg')

print('\ndone\n')
