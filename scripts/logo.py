#!/usr/bin/env python3
"""Draw the Opz Browser logo ("Pebble O") into the branding directory.

The logo is a blue rounded tile with a white, pebble-shaped "O". A light rim
along the bottom-right edge and on the upper-left wall of the hole gives it
some depth. The source drawing lives in vpock (file "Opz Browser", page
"Logo 1"); the geometry below is the same, in a 512 x 512 space.

Pure Python (zlib only), no image libraries needed:

    scripts/logo.py <branding-dir>          PNG, ICO, ICNS and SVG files
    scripts/logo.py <branding-dir> --car    also rebuild Assets.car (macOS + Xcode)
"""

import json
import math
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path

WHITE = (0xFF, 0xFF, 0xFF)
THEMES = {
    # --opz-accent from Opz Browser tokens.css, rim is a light tint of it.
    "default": {"tile": (0x25, 0x63, 0xEB), "rim": (0xBF, 0xDB, 0xFE)},
    # Violet for the private-browsing variant.
    "private": {"tile": (0x6D, 0x28, 0xD9), "rim": (0xDD, 0xD6, 0xFE)},
}
SS = 4  # supersampling per axis

# --- Geometry (512 x 512) ---------------------------------------------------

TILE_RADIUS = 115
RIM = 18  # how far the rim shows, along both axes
OUTER = ((256, 100), [((360, 98), (422, 168), (418, 262)),
                      ((414, 360), (350, 416), (250, 412)),
                      ((150, 408), (94, 350), (96, 254)),
                      ((98, 160), (160, 102), (256, 100))])
HOLE = ((286, 176), [((326, 176), (348, 206), (346, 240)),
                     ((344, 278), (316, 300), (280, 298)),
                     ((244, 296), (222, 268), (224, 236)),
                     ((226, 200), (252, 176), (286, 176))])


def bezier_polygon(shape, steps=64):
    start, segments = shape
    points, p0 = [], start
    for c1, c2, p3 in segments:
        for i in range(steps):
            t = i / steps
            u = 1 - t
            points.append(tuple(
                u**3 * p0[k] + 3 * u * u * t * c1[k] + 3 * u * t * t * c2[k] + t**3 * p3[k]
                for k in (0, 1)))
        p0 = p3
    return points


def rounded_rect(x, y, w, h, r, steps=24):
    points = []
    for cx, cy, a0 in ((x + w - r, y + r, -90), (x + w - r, y + h - r, 0),
                       (x + r, y + h - r, 90), (x + r, y + r, 180)):
        for i in range(steps + 1):
            a = math.radians(a0 + 90 * i / steps)
            points.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return points


def shifted(points, d):
    return [(x + d, y + d) for x, y in points]


def svg_path(shape, d=0):
    start, segments = shape
    f = lambda p: f"{p[0] + d} {p[1] + d}"
    return f"M {f(start)} " + " ".join(f"C {f(a)} {f(b)} {f(c)}" for a, b, c in segments) + " Z"


# --- Rasterizer ---------------------------------------------------------------

def spans(poly, y, limit):
    """Sample-index intervals [a, b) inside poly on row y (even-odd rule)."""
    xs = []
    n = len(poly)
    for i in range(n):
        x0, y0 = poly[i]
        x1, y1 = poly[(i + 1) % n]
        if (y0 <= y < y1) or (y1 <= y < y0):
            xs.append(x0 + (y - y0) * (x1 - x0) / (y1 - y0))
    xs.sort()
    out = []
    for a, b in zip(xs[0::2], xs[1::2]):
        ia = max(0, math.ceil(a * SS - 0.5))
        ib = min(limit, math.ceil(b * SS - 0.5))
        if ib > ia:
            out.append((ia, ib))
    return out


def subtract(a, b):
    out = []
    for s, e in a:
        for bs, be in b:
            if be <= s or bs >= e:
                continue
            if bs > s:
                out.append((s, bs))
            s = max(s, be)
            if s >= e:
                break
        if s < e:
            out.append((s, e))
    return out


def render(width, height, size, theme, ox=None, oy=None, tile=True, inset=1.0):
    """Draw the logo as a size x size icon inside a width x height RGBA image.

    inset < 1 shrinks the tile inside the icon square (macOS icon grid).
    """
    colors = THEMES[theme]
    ox = (width - size) / 2 if ox is None else ox
    oy = (height - size) / 2 if oy is None else oy
    s = size * inset / 512
    ox += size * (1 - inset) / 2
    oy += size * (1 - inset) / 2
    tf = lambda pts: [(x * s + ox, y * s + oy) for x, y in pts]
    outer = bezier_polygon(OUTER)
    hole = bezier_polygon(HOLE)
    polys = {
        "tile": tf(rounded_rect(0, 0, 512, 512, TILE_RADIUS)),
        "outer": tf(outer),
        "hole": tf(hole),
        "outer_shift": tf(shifted(outer, -RIM)),
        "hole_shift": tf(shifted(hole, RIM)),
    }
    limit = width * SS
    paints = {v: bytes([v]) * limit for v in (1, 2, 3)}
    palette = {1: colors["tile"], 2: WHITE, 3: colors["rim"]}
    rows = []
    for py in range(height):
        counts = {1: [0] * width, 2: [0] * width, 3: [0] * width}
        for sy in range(SS):
            y = py + (sy + 0.5) / SS
            sp = {k: spans(p, y, limit) for k, p in polys.items()}
            if not sp["tile"] and not sp["outer"]:
                continue
            label = bytearray(limit)

            def paint(intervals, v):
                for a, b in intervals:
                    label[a:b] = paints[v][: b - a]

            if tile:
                paint(sp["tile"], 1)
            paint(subtract(sp["outer"], sp["hole"]), 2)
            paint(subtract(subtract(sp["outer"], sp["outer_shift"]), sp["hole"]), 3)
            paint(subtract(sp["hole"], sp["hole_shift"]), 3)
            for px in range(width):
                seg = label[px * SS:(px + 1) * SS]
                if seg.count(0) == SS:
                    continue
                for v in (1, 2, 3):
                    counts[v][px] += seg.count(v)
        row = []
        for px in range(width):
            c = {v: counts[v][px] for v in (1, 2, 3)}
            total = sum(c.values())
            if not total:
                row += [0, 0, 0, 0]
                continue
            rgb = [sum(c[v] * palette[v][k] for v in c) // total for k in range(3)]
            row += rgb + [255 * total // (SS * SS)]
        rows.append(row)
    return png(width, height, rows)


def png(width, height, rgba_rows):
    def chunk(kind, data):
        c = struct.pack(">I", len(data)) + kind + data
        return c + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + bytes(row) for row in rgba_rows)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


# --- Containers -------------------------------------------------------------

def ico(images):
    """images: list of (size, png bytes). PNG-compressed ICO (Vista and later)."""
    header = struct.pack("<HHH", 0, 1, len(images))
    offset = 6 + 16 * len(images)
    entries, blobs = b"", b""
    for size, data in images:
        b = size if size < 256 else 0
        entries += struct.pack("<BBBBHHII", b, b, 0, 0, 1, 32, len(data), offset)
        offset += len(data)
        blobs += data
    return header + entries + blobs


# macOS icon grid: the tile is 824 of 1024 px, centered.
MAC_INSET = 824 / 1024
ICNS_TYPES = [(b"icp4", 16), (b"icp5", 32), (b"icp6", 64), (b"ic07", 128), (b"ic08", 256),
              (b"ic09", 512), (b"ic10", 1024), (b"ic11", 32), (b"ic12", 64), (b"ic13", 256),
              (b"ic14", 512)]


def icns(theme, cache):
    body = b""
    for kind, px in ICNS_TYPES:
        data = cache(px)
        body += kind + struct.pack(">I", len(data) + 8) + data
    return b"icns" + struct.pack(">I", len(body) + 8) + body


APPICONSET = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2),
              (512, 1), (512, 2)]


def build_car(out, cache):
    """Compile AppIcon (and Icon, which Firefox also looks up) into Assets.car."""
    if sys.platform != "darwin" or not shutil.which("xcrun"):
        sys.exit("--car needs macOS with Xcode (actool)")
    with tempfile.TemporaryDirectory() as tmp:
        catalog = Path(tmp) / "Assets.xcassets"
        for name in ("AppIcon", "Icon"):
            iconset = catalog / f"{name}.appiconset"
            iconset.mkdir(parents=True)
            images = []
            for pt, scale in APPICONSET:
                fname = f"icon_{pt}x{pt}{'@2x' if scale == 2 else ''}.png"
                (iconset / fname).write_bytes(cache(pt * scale))
                images.append({"idiom": "mac", "size": f"{pt}x{pt}", "scale": f"{scale}x",
                               "filename": fname})
            (iconset / "Contents.json").write_text(json.dumps(
                {"images": images, "info": {"version": 1, "author": "xcode"}}, indent=2))
        (catalog / "Contents.json").write_text(json.dumps({"info": {"version": 1, "author": "xcode"}}))
        build = Path(tmp) / "build"
        build.mkdir()
        subprocess.run(["xcrun", "actool", "--compile", str(build), "--platform", "macosx",
                        "--minimum-deployment-target", "10.15", "--app-icon", "AppIcon",
                        "--include-all-app-icons",
                        "--output-partial-info-plist", str(Path(tmp) / "partial.plist"),
                        "--errors", "--warnings", str(catalog)],
                       check=True, stdout=subprocess.DEVNULL)
        shutil.copy(build / "Assets.car", out / "Assets.car")
    print("wrote", out / "Assets.car")


# --- SVG ----------------------------------------------------------------------

SVG = """<!-- Opz Browser logo "Pebble O" (scripts/logo.py). -->
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <defs>
    <mask id="rim"><path fill="#fff" d="{outer}"/><path d="{outer_shift}"/></mask>
    <mask id="hole"><path fill="#fff" d="{hole}"/></mask>
  </defs>
  <rect width="512" height="512" rx="{radius}" fill="{tile}"/>
  <path fill="#fff" d="{outer}"/>
  <path fill="{rim}" mask="url(#rim)" d="{outer}"/>
  <path fill="{rim}" d="{hole}"/>
  <path fill="{tile}" mask="url(#hole)" d="{hole_shift}"/>
</svg>
"""

# Shown 44px high in the About dialog (content/aboutDialog.css), filled with
# the theme's text color.
WORDMARK = """<!-- Opz Browser wordmark (scripts/logo.py). -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 470 99" fill="context-fill">
  <text x="0" y="76" font-family="-apple-system, 'SF Pro Display', 'Segoe UI', Inter, sans-serif" font-size="80" textLength="468" lengthAdjust="spacingAndGlyphs"><tspan font-weight="700">Opz</tspan> <tspan font-weight="500">Browser</tspan></text>
</svg>
"""


def hexcolor(rgb):
    return "#%02x%02x%02x" % rgb


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    out = Path(sys.argv[1])
    renders = {}

    def icon(px, theme="default", mac=False):
        key = (px, theme, mac)
        if key not in renders:
            renders[key] = render(px, px, px, theme, inset=MAC_INSET if mac else 1.0)
        return renders[key]

    def write(name, data):
        (out / name).write_bytes(data)
        print("wrote", out / name)

    # Linux / generic app icons and the About dialog.
    for s in (16, 22, 24, 32, 48, 64, 128, 256):
        write(f"default{s}.png", icon(s))
    write("content/about-logo.png", icon(192))
    write("content/about-logo@2x.png", icon(384))
    write("content/about-logo-private.png", icon(192, "private"))
    write("content/about-logo-private@2x.png", icon(384, "private"))
    write("content/about.png", render(300, 236, 200, "default"))

    # Windows: app / private-mode icons and Start-menu tiles. The tiles show the
    # mark alone; the *.VisualElementsManifest.xml files give the tile color.
    write("firefox.ico", ico([(s, icon(s)) for s in (16, 32, 48, 256)]))
    write("firefox64.ico", ico([(s, icon(s)) for s in (16, 32, 48, 64)]))
    write("pbmode.ico", ico([(s, icon(s, "private")) for s in (256, 48, 32, 16)]))
    for s in (70, 150):
        write(f"VisualElements_{s}.png", render(s, s, s, "default", tile=False))
        write(f"PrivateBrowsing_{s}.png", render(s, s, s, "private", tile=False))

    # macOS: legacy .icns and, on request, the asset catalog used by macOS 26.
    write("firefox.icns", icns("default", lambda px: icon(px, mac=True)))
    if "--car" in sys.argv[2:]:
        build_car(out, lambda px: icon(px, mac=True))

    outer, hole = svg_path(OUTER), svg_path(HOLE)
    c = THEMES["default"]
    (out / "content/about-logo.svg").write_text(SVG.format(
        outer=outer, hole=hole, outer_shift=svg_path(OUTER, -RIM), hole_shift=svg_path(HOLE, RIM),
        radius=TILE_RADIUS, tile=hexcolor(c["tile"]), rim=hexcolor(c["rim"])))
    (out / "content/about-wordmark.svg").write_text(WORDMARK)
    (out / "content/firefox-wordmark.svg").write_text(WORDMARK)
    print("wrote svg logo + wordmarks")


if __name__ == "__main__":
    main()
