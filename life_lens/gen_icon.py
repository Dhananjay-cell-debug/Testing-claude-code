"""
LifeLens Icon v3 — "The Life Scan"

Creative direction:
  ONE clear idea — a bold eye/lens shape with a heartbeat ECG pulse running
  through it. The eye = 'lens'. The pulse = 'life'. Together = LifeLens.

  - Deep near-black background (#070B14)
  - Large almond eye shape in electric lime (#ADFF2F)
  - ECG heartbeat line running through the eye's center
  - Bright white dot at the spike peak (the focused moment)
  - Subtle lime glow behind everything
  - NO complexity — one symbol, one color, maximum contrast
"""

from PIL import Image, ImageDraw, ImageFilter
import math, os

# ── Palette ────────────────────────────────────────────────────────────
BG         = (7,  11, 20)      # #070B14  near-black navy
BG_EYE     = (10, 15, 28)      # eye interior — slightly lighter
LIME       = (173, 255, 47)    # #ADFF2F  electric lime
LIME_GLOW  = (173, 255, 47)
WHITE      = (255, 255, 255)
CYAN       = (0,  224, 255)    # subtle iris ring

def lerp(a, b, t):
    return a + (b - a) * t

def lerp_color(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


def eye_polygon(cx, cy, w, h, n=120):
    """
    Returns (top_pts, bottom_pts, all_pts) for an almond/eye shape.
    Top arc goes right → top → left.
    Bottom arc goes left → bottom → right.
    """
    top = []
    for i in range(n // 2 + 1):
        t = i / (n // 2)
        x = cx + (w / 2) * math.cos(math.pi * t)
        y = cy - (h / 2) * math.sin(math.pi * t)
        top.append((x, y))

    bottom = []
    for i in range(1, n // 2 + 1):
        t = i / (n // 2)
        x = cx - (w / 2) * math.cos(math.pi * t)
        y = cy + (h / 2) * math.sin(math.pi * t)
        bottom.append((x, y))

    all_pts = top + bottom
    return top, bottom, all_pts


def build_icon(S, rounded=True):
    cx = cy = S / 2

    # ── 1. Shape mask ──────────────────────────────────────────────────
    mask = Image.new('L', (S, S), 0)
    mdraw = ImageDraw.Draw(mask)
    if rounded:
        cr = int(S * 0.22)
        mdraw.rounded_rectangle([0, 0, S - 1, S - 1], radius=cr, fill=255)
    else:
        mdraw.ellipse([0, 0, S - 1, S - 1], fill=255)

    # ── 2. Background (very subtle vignette) ──────────────────────────
    bg_layer = Image.new('RGBA', (S, S), (*BG, 255))
    bg_draw = ImageDraw.Draw(bg_layer)
    # Lighter center glow (barely visible)
    for r in range(int(S * 0.55), 0, -4):
        t = r / (S * 0.55)
        c = lerp_color((16, 22, 40), BG, t ** 1.2)
        bg_draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(*c, 255))

    # ── 3. Eye shape ───────────────────────────────────────────────────
    eye_w = S * 0.72
    eye_h = S * 0.37

    _, _, pts = eye_polygon(cx, cy, eye_w, eye_h)

    # Lime glow behind the eye outline
    glow_layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow_layer)
    for expand in range(1, 14):
        _, _, big_pts = eye_polygon(cx, cy, eye_w + expand * 2.5, eye_h + expand * 1.2)
        alpha = max(0, 55 - expand * 4)
        gd.polygon(big_pts, fill=(*LIME_GLOW, alpha))
    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(max(1, S * 0.022)))

    # Eye fill (dark interior) and outline
    eye_layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ed = ImageDraw.Draw(eye_layer)
    stroke_w = max(2, int(S * 0.030))
    ed.polygon(pts, fill=(*BG_EYE, 255), outline=(*LIME, 255), width=stroke_w)

    # ── 4. ECG / heartbeat line ────────────────────────────────────────
    margin_x = eye_w * 0.09
    left_x  = cx - eye_w / 2 + margin_x
    right_x = cx + eye_w / 2 - margin_x
    span    = right_x - left_x
    base_y  = cy  # horizontal centerline of eye

    # Heights — spike must stay inside the eye
    # Eye top at horizontal-center is cy - eye_h/2
    spike_h = eye_h * 0.44   # ~88% up toward top of eye
    drop_h  = eye_h * 0.34   # ~68% down toward bottom of eye

    # ECG points: classic heartbeat shape
    ecg_pts = [
        (left_x,                  base_y),
        (left_x + span * 0.18,    base_y),
        (left_x + span * 0.28,    base_y - eye_h * 0.11),  # small P-wave bump
        (left_x + span * 0.34,    base_y),
        (left_x + span * 0.43,    base_y - spike_h),        # QRS spike up
        (left_x + span * 0.48,    base_y + drop_h),         # sharp S-wave drop
        (left_x + span * 0.55,    base_y),
        (left_x + span * 0.63,    base_y - eye_h * 0.09),  # small T-wave bump
        (left_x + span * 0.72,    base_y),
        (right_x,                 base_y),
    ]

    # ECG glow (blurred copy behind)
    ecg_glow_layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ecg_gd = ImageDraw.Draw(ecg_glow_layer)
    ecg_gd.line(ecg_pts, fill=(*LIME, 160), width=max(2, int(S * 0.045)))
    ecg_glow_layer = ecg_glow_layer.filter(ImageFilter.GaussianBlur(max(1, S * 0.020)))

    # ECG crisp line
    ecg_layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ecg_draw = ImageDraw.Draw(ecg_layer)
    line_w = max(1, int(S * 0.022))
    ecg_draw.line(ecg_pts, fill=(*LIME, 255), width=line_w)

    # ── 5. Spike dot (focal point) ─────────────────────────────────────
    spike_x = left_x + span * 0.43
    spike_y = base_y - spike_h

    dot_layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    dd = ImageDraw.Draw(dot_layer)

    dot_r = max(2, int(S * 0.036))
    # Outer lime glow ring
    dd.ellipse(
        [spike_x - dot_r * 2.0, spike_y - dot_r * 2.0,
         spike_x + dot_r * 2.0, spike_y + dot_r * 2.0],
        fill=(*LIME, 50)
    )
    # Inner lime ring
    dd.ellipse(
        [spike_x - dot_r * 1.4, spike_y - dot_r * 1.4,
         spike_x + dot_r * 1.4, spike_y + dot_r * 1.4],
        fill=(*LIME, 120)
    )
    # White core
    dd.ellipse(
        [spike_x - dot_r, spike_y - dot_r,
         spike_x + dot_r, spike_y + dot_r],
        fill=(*WHITE, 255)
    )

    # ── 6. Compose all layers ──────────────────────────────────────────
    result = bg_layer
    result = Image.alpha_composite(result, glow_layer)
    result = Image.alpha_composite(result, eye_layer)
    result = Image.alpha_composite(result, ecg_glow_layer)
    result = Image.alpha_composite(result, ecg_layer)
    result = Image.alpha_composite(result, dot_layer)

    # Apply shape mask
    final = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    final.paste(result, mask=mask)
    return final


# ── Output ────────────────────────────────────────────────────────────
BASE = "c:/DHANANJAY/claude code/claude app/trial/Testing-claude-code/life_lens/android/app/src/main/res"
SIZES = {
    'mipmap-mdpi':    48,
    'mipmap-hdpi':    72,
    'mipmap-xhdpi':   96,
    'mipmap-xxhdpi':  144,
    'mipmap-xxxhdpi': 192,
}

print("Generating LifeLens icons v3 - The Life Scan...")
for folder, size in SIZES.items():
    out_dir = os.path.join(BASE, folder)
    os.makedirs(out_dir, exist_ok=True)

    icon = build_icon(size, rounded=True)
    icon.save(os.path.join(out_dir, 'ic_launcher.png'), 'PNG')
    print(f"  OK {folder}/ic_launcher.png ({size}x{size})")

    icon_round = build_icon(size, rounded=False)
    icon_round.save(os.path.join(out_dir, 'ic_launcher_round.png'), 'PNG')
    print(f"  OK {folder}/ic_launcher_round.png ({size}x{size})")

# 512 preview
preview = build_icon(512, rounded=True)
preview.save("c:/DHANANJAY/claude code/claude app/trial/Testing-claude-code/life_lens/icon_preview_512.png", 'PNG')
print("\n  OK icon_preview_512.png (512x512)")
print("\nAll icons generated.")
