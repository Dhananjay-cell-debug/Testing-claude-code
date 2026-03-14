"""
LifeLens App Icon Generator
Creative Direction: A premium "life intelligence" aesthetic.
  - Deep space navy background with soft radial glow
  - A stylized eye/lens at center — concentric soft rings (like a camera iris)
  - Lime-green (#C5F135) inner glow fading to teal then deep purple
  - Fine hexagonal grid pattern (barely visible) in background
  - Clean rounded-square shape for standard, perfect circle for round
"""

from PIL import Image, ImageDraw, ImageFilter
import math, os

# ── Palette ──────────────────────────────────────────────────────────
BG_OUTER   = (8,  8,  22)   # deepest navy
BG_INNER   = (18, 18, 48)   # slightly lighter navy
LIME       = (197, 241, 53)  # #C5F135
LIME_DIM   = (120, 160, 20)
TEAL       = (0,  196, 140)  # #00C48C
PURPLE     = (180, 174, 255) # #B4AEFF
WHITE_SOFT = (230, 235, 255)

def lerp_color(c1, c2, t):
    return tuple(int(c1[i] + (c2[i]-c1[i])*t) for i in range(3))

def set_alpha(color, a):
    return (color[0], color[1], color[2], a)

def draw_icon(size, rounded=True, corner_radius_ratio=0.22):
    S = size
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = S//2, S//2
    R = corner_radius_ratio

    # ── 1. Background shape (rounded square or full circle) ────────────
    mask = Image.new('L', (S, S), 0)
    mdraw = ImageDraw.Draw(mask)
    if rounded:
        cr = int(S * R)
        mdraw.rounded_rectangle([0, 0, S-1, S-1], radius=cr, fill=255)
    else:
        mdraw.ellipse([0, 0, S-1, S-1], fill=255)

    # ── 2. Radial background gradient ──────────────────────────────────
    bg = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    for y in range(S):
        for x in range(S):
            dx = (x - cx) / cx
            dy = (y - cy) / cy
            d = math.sqrt(dx*dx + dy*dy)
            t = min(d, 1.0)
            c = lerp_color(BG_INNER, BG_OUTER, t**1.5)
            bg.putpixel((x, y), (*c, 255))

    # ── 3. Subtle hex grid in background ───────────────────────────────
    grid_layer = Image.new('RGBA', (S, S), (0,0,0,0))
    gd = ImageDraw.Draw(grid_layer)
    cell = S * 0.13
    h = cell * math.sqrt(3) / 2
    cols = int(S / cell) + 4
    rows = int(S / h) + 4
    for row in range(-2, rows):
        for col in range(-2, cols):
            x0 = col * cell * 1.5 - cell
            y0 = row * h * 2 - h
            if col % 2 == 1:
                y0 += h
            pts = []
            for i in range(6):
                angle = math.pi / 180 * (60 * i - 30)
                pts.append((x0 + cell * 0.5 * math.cos(angle),
                             y0 + cell * 0.5 * math.sin(angle)))
            gd.polygon(pts, fill=(255,255,255,0), outline=(180,180,255,8))
    grid_layer = grid_layer.filter(ImageFilter.GaussianBlur(0.5))

    # ── 4. Outer soft glow ring (purple/teal aura) ─────────────────────
    glow1 = Image.new('RGBA', (S, S), (0,0,0,0))
    for r in range(int(S*0.48), int(S*0.32), -1):
        t = (r - S*0.32) / (S*0.16)
        alpha = int(18 * (1 - t) * (1 - t))
        col = lerp_color(TEAL, PURPLE, t)
        for angle_deg in range(0, 360, 2):
            angle = math.radians(angle_deg)
            px = int(cx + r * math.cos(angle))
            py = int(cy + r * math.sin(angle))
            if 0 <= px < S and 0 <= py < S:
                existing = glow1.getpixel((px, py))
                a = min(255, existing[3] + alpha)
                glow1.putpixel((px, py), (*col, a))
    glow1 = glow1.filter(ImageFilter.GaussianBlur(S * 0.03))

    # ── 5. Iris rings (concentric circles) ─────────────────────────────
    rings = Image.new('RGBA', (S, S), (0,0,0,0))
    rd = ImageDraw.Draw(rings)
    ring_defs = [
        (0.42, 1, (80, 90, 110, 90)),    # outermost — subtle grey
        (0.36, 2, (*PURPLE, 100)),
        (0.28, 3, (*TEAL,   140)),
        (0.20, 2, (*LIME,   180)),        # bright lime ring
        (0.12, 3, (*LIME,   220)),        # brighter inner lime
    ]
    for (ratio, width, color) in ring_defs:
        r = int(S * ratio)
        w = max(1, int(width * S / 96))
        rd.ellipse(
            [cx - r - w, cy - r - w, cx + r + w, cy + r + w],
            outline=color, width=w
        )
    rings = rings.filter(ImageFilter.GaussianBlur(max(1, S*0.008)))

    # ── 6. Lens spokes (iris-like radial lines) ─────────────────────────
    spokes = Image.new('RGBA', (S, S), (0,0,0,0))
    sd = ImageDraw.Draw(spokes)
    inner_r = int(S * 0.065)
    outer_r = int(S * 0.35)
    for i in range(12):
        angle = math.radians(i * 30)
        t = i / 12
        col = lerp_color(LIME_DIM, TEAL, t)
        alpha = 60
        x1 = cx + int(inner_r * math.cos(angle))
        y1 = cy + int(inner_r * math.sin(angle))
        x2 = cx + int(outer_r * math.cos(angle))
        y2 = cy + int(outer_r * math.sin(angle))
        sd.line([x1, y1, x2, y2], fill=(*col, alpha), width=max(1, S//96))
    spokes = spokes.filter(ImageFilter.GaussianBlur(max(1, S*0.012)))

    # ── 7. Lime core glow (the "pupil") ────────────────────────────────
    core = Image.new('RGBA', (S, S), (0,0,0,0))
    for r in range(int(S*0.10), 0, -1):
        t = r / (S * 0.10)
        alpha = int(255 * (1 - t) * (1 - t))
        col = lerp_color(WHITE_SOFT, LIME, t)
        draw_c = ImageDraw.Draw(core)
        draw_c.ellipse(
            [cx-r, cy-r, cx+r, cy+r],
            fill=(*col, alpha)
        )
    core = core.filter(ImageFilter.GaussianBlur(max(1, S * 0.025)))

    # Add a tiny bright center dot
    dot_r = max(2, int(S * 0.025))
    dot_draw = ImageDraw.Draw(core)
    dot_draw.ellipse([cx-dot_r, cy-dot_r, cx+dot_r, cy+dot_r],
                     fill=(*WHITE_SOFT, 255))

    # ── 8. Compose all layers ───────────────────────────────────────────
    img = Image.alpha_composite(bg, grid_layer)
    img = Image.alpha_composite(img, glow1)
    img = Image.alpha_composite(img, rings)
    img = Image.alpha_composite(img, spokes)
    img = Image.alpha_composite(img, core)

    # Apply shape mask
    result = Image.new('RGBA', (S, S), (0,0,0,0))
    result.paste(img, mask=mask)
    return result

# ── Output paths and sizes ────────────────────────────────────────────
BASE = "c:/DHANANJAY/claude code/claude app/trial/Testing-claude-code/life_lens/android/app/src/main/res"
SIZES = {
    'mipmap-mdpi':    48,
    'mipmap-hdpi':    72,
    'mipmap-xhdpi':   96,
    'mipmap-xxhdpi':  144,
    'mipmap-xxxhdpi': 192,
}

print("Generating LifeLens icons...")
for folder, size in SIZES.items():
    out_dir = os.path.join(BASE, folder)
    os.makedirs(out_dir, exist_ok=True)

    # Standard (rounded square)
    icon = draw_icon(size, rounded=True)
    path = os.path.join(out_dir, 'ic_launcher.png')
    icon.save(path, 'PNG')
    print(f"  OK {folder}/ic_launcher.png  ({size}×{size})")

    # Round
    icon_round = draw_icon(size, rounded=False)
    path_r = os.path.join(out_dir, 'ic_launcher_round.png')
    icon_round.save(path_r, 'PNG')
    print(f"  OK {folder}/ic_launcher_round.png  ({size}×{size})")

# Also save a 512×512 preview
preview = draw_icon(512, rounded=True)
preview_path = "c:/DHANANJAY/claude code/claude app/trial/Testing-claude-code/life_lens/icon_preview_512.png"
preview.save(preview_path, 'PNG')
print(f"\n  OK Preview saved: icon_preview_512.png")
print("\nAll icons generated successfully!")
