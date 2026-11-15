"""Builds the miner and NPC sprite sheets from the EchoMine sheet.

Each frame is aligned so the back boot stands on the same anchor point,
which keeps the stationary hero's feet fixed during every animation.
"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image

SRC = Path(sys.argv[1])
OUT = Path(sys.argv[2])
OUT.mkdir(parents=True, exist_ok=True)

sheet = np.array(Image.open(SRC).convert("RGBA")).astype(np.float32)
H, W = sheet.shape[:2]
cw, ch = W // 4, H // 2


def clean(cell):
    a = cell[:, :, 3]
    rgb = cell[:, :, :3]
    # Remove the reddish/greenish matting halo left by background removal.
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    halo = (a < 200) & (((r > g * 1.6) & (r > b * 1.6)) | ((g > r * 1.5) & (g > b * 1.2)))
    a = np.where(halo, 0, a)
    a = np.where(a < 110, 0, np.where(a > 170, 255, a))
    out = cell.copy()
    out[:, :, 3] = a
    return out


frames = []
for r in range(2):
    for c in range(4):
        cell = clean(sheet[r * ch:(r + 1) * ch, c * cw:(c + 1) * cw])
        a = cell[:, :, 3] > 128
        ys, xs = np.nonzero(a)
        bottom = ys.max()
        # Back boot: leftmost cluster of opaque pixels in the lowest rows,
        # ignoring the cyan swoosh of the strike frame.
        rows = cell[bottom - 14:bottom + 1]
        rgb = rows[:, :, :3]
        cyan = (rgb[..., 2] > 150) & (rgb[..., 1] > 150) & (rgb[..., 0] < 120)
        mask = (rows[:, :, 3] > 128) & ~cyan
        cols = np.nonzero(mask.any(0))[0]
        # split clusters
        groups, start = [], cols[0]
        for i in range(1, len(cols)):
            if cols[i] - cols[i - 1] > 4:
                groups.append((start, cols[i - 1]))
                start = cols[i]
        groups.append((start, cols[-1]))
        g0 = groups[0]
        anchor = ((g0[0] + g0[1]) / 2.0, float(bottom))
        frames.append((cell, anchor, (xs.min(), ys.min(), xs.max(), ys.max())))

left = max(f[1][0] - f[2][0] for f in frames) + 6
right = max(f[2][2] - f[1][0] for f in frames) + 6
top = max(f[1][1] - f[2][1] for f in frames) + 6
fw, fh = int(left + right), int(top + 8)
SCALE = 0.5
ofw, ofh = int(round(fw * SCALE)), int(round(fh * SCALE))


def render(recolor=None):
    out = Image.new("RGBA", (ofw * 4, ofh * 2), (0, 0, 0, 0))
    for i, (cell, (ax, ay), _) in enumerate(frames):
        canvas = np.zeros((fh, fw, 4), np.float32)
        ox, oy = int(round(left - ax)), int(round(top - ay))
        h, w = cell.shape[:2]
        x0, y0 = max(0, ox), max(0, oy)
        sx0, sy0 = x0 - ox, y0 - oy
        x1, y1 = min(fw, ox + w), min(fh, oy + h)
        canvas[y0:y1, x0:x1] = cell[sy0:sy0 + (y1 - y0), sx0:sx0 + (x1 - x0)]
        if recolor:
            canvas = recolor(canvas)
        # premultiply, resize, unpremultiply
        a = canvas[:, :, 3:4] / 255.0
        pm = np.concatenate([canvas[:, :, :3] * a, a * 255.0], 2)
        img = Image.fromarray(np.clip(pm, 0, 255).astype(np.uint8), "RGBA")
        img = img.resize((ofw, ofh), Image.LANCZOS)
        arr = np.array(img).astype(np.float32)
        al = arr[:, :, 3:4]
        rgb = np.where(al > 0, arr[:, :, :3] * 255.0 / np.maximum(al, 1), 0)
        al = np.where(al < 40, 0, al)
        arr = np.concatenate([np.clip(rgb, 0, 255), al], 2)
        out.paste(Image.fromarray(arr.astype(np.uint8), "RGBA"), ((i % 4) * ofw, (i // 4) * ofh))
    return out


def hue_shift(src_pred, target):
    def f(c):
        rgb = c[:, :, :3]
        r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        m = src_pred(r, g, b) & (c[:, :, 3] > 0)
        lum = (0.3 * r + 0.59 * g + 0.11 * b) / 160.0
        t = np.array(target, np.float32)
        new = np.clip(lum[..., None] * t[None, None, :], 0, 255)
        c = c.copy()
        c[:, :, :3] = np.where(m[..., None], new, rgb)
        return c
    return f


scarf = lambda r, g, b: (r > 140) & (g < r * 0.5) & (b < r * 0.35)
cloth = lambda r, g, b: (b > r * 1.15) & (b > g) & (b < 190)

render().save(OUT / "miner_sheet.png")
# Mechanic: green scarf, brown overalls.
mech = lambda c: hue_shift(cloth, (150, 110, 80))(hue_shift(scarf, (90, 200, 120))(c))
render(mech).save(OUT / "npc_mechanic_sheet.png")
# Brother: blue scarf, darker grey work clothes.
bro = lambda c: hue_shift(cloth, (120, 125, 135))(hue_shift(scarf, (80, 150, 235))(c))
render(bro).save(OUT / "npc_brother_sheet.png")
# Worker: yellow scarf.
wk = lambda c: hue_shift(cloth, (110, 120, 95))(hue_shift(scarf, (235, 200, 70))(c))
render(wk).save(OUT / "npc_worker_sheet.png")
print("frame", ofw, ofh, "anchor", round(left * SCALE, 1), round(top * SCALE, 1))
