"""Prepares backgrounds and interactive sprites from the approved references.

Inputs: EchoMine cleaned location images, the three reference images and
boss.png. Outputs land in assets/. Run from the project root:
    python3 tools/make_art.py <echomine_assets_dir> <references_dir>
"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

EA = Path(sys.argv[1])
REF = Path(sys.argv[2])
OUT = Path("assets")
for d in ("bg", "sprites", "art"):
    (OUT / d).mkdir(parents=True, exist_ok=True)

W, H = 1672, 941


def load_bg(name):
    im = Image.open(EA / name).convert("RGB")
    if im.size != (W, H):
        canvas = Image.new("RGB", (W, H))
        canvas.paste(im, (0, 0))
        # duplicate last column to fill the missing pixel column
        canvas.paste(im.crop((im.width - 1, 0, im.width, im.height)), (im.width, 0))
        im = canvas
    return np.array(im).astype(np.float32)


def save(arr, path):
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(path)


def poly_mask(points, size=(W, H), feather=0):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).polygon(points, fill=255)
    if feather:
        m = m.filter(ImageFilter.GaussianBlur(feather))
    return np.array(m).astype(np.float32) / 255.0


def blend(dst, src, mask):
    return dst * (1 - mask[..., None]) + src * mask[..., None]


# ---------------------------------------------------------------- palette
WOOD = (176, 108, 56)
WOOD_D = (110, 62, 32)
WOOD_L = (222, 150, 82)
OUTL = (36, 22, 18)
IRON = (118, 122, 132)
IRON_D = (70, 72, 82)
BRASS = (214, 160, 64)
BRASS_D = (140, 96, 36)


def wood_plank(w, h, vertical=True, seed=1):
    rng = np.random.default_rng(seed)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], fill=OUTL)
    d.rectangle([2, 2, w - 3, h - 3], fill=WOOD)
    if vertical:
        d.rectangle([2, 2, 4, h - 3], fill=WOOD_L)
        d.rectangle([w - 6, 2, w - 3, h - 3], fill=WOOD_D)
        for _ in range(h // 9):
            x = int(rng.integers(6, max(7, w - 7)))
            y = int(rng.integers(3, h - 12))
            d.line([x, y, x, y + int(rng.integers(5, 14))], fill=WOOD_D)
    else:
        d.rectangle([2, 2, w - 3, 4], fill=WOOD_L)
        d.rectangle([2, h - 6, w - 3, h - 3], fill=WOOD_D)
        for _ in range(w // 9):
            y = int(rng.integers(6, max(7, h - 7)))
            x = int(rng.integers(3, w - 12))
            d.line([x, y, x + int(rng.integers(5, 14)), y], fill=WOOD_D)
    return img


def plate(img, x, y, s=10):
    d = ImageDraw.Draw(img)
    d.rectangle([x, y, x + s, y + s], fill=OUTL)
    d.rectangle([x + 1, y + 1, x + s - 1, y + s - 1], fill=IRON)
    d.rectangle([x + 1, y + s - 3, x + s - 1, y + s - 1], fill=IRON_D)
    for px, py in ((x + 3, y + 3), (x + s - 3, y + 3), (x + 3, y + s - 3), (x + s - 3, y + s - 3)):
        d.point((px, py), fill=(40, 40, 46))


# ================================================================ crystal
def crystal_sprite():
    bg3 = np.array(Image.open(EA / "location2.png").convert("RGB")).astype(np.float32)
    box = (582, 672, 790, 836)
    sub = bg3[box[1]:box[3], box[0]:box[2]]
    r, g, b = sub[..., 0], sub[..., 1], sub[..., 2]
    pink = (r > 120) & (b > 90) & (g < r * 0.75) & (r > g + 50)
    # main crystal polygon (excludes the small shard and base rocks)
    poly = [(580, 672), (606, 676), (700, 740), (774, 812), (776, 830), (650, 830), (640, 806), (580, 688)]
    pm = poly_mask([(x - box[0], y - box[1]) for x, y in poly], size=(box[2] - box[0], box[3] - box[1])) > 0.5
    reddish = (r > g + 18) & (r > 70)
    m = reddish & pm
    m = np.array(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(3))) > 0
    m &= pm
    rgba = np.concatenate([sub, (m * 255.0)[..., None]], 2)
    img = Image.fromarray(rgba.astype(np.uint8), "RGBA")
    # Align the long axis horizontally.
    ys, xs = np.nonzero(m)
    cx, cy = xs.mean(), ys.mean()
    cov = np.cov(np.stack([xs - cx, ys - cy]))
    evals, evecs = np.linalg.eigh(cov)
    v = evecs[:, np.argmax(evals)]
    ang = np.degrees(np.arctan2(v[1], v[0]))
    big = Image.new("RGBA", (400, 400), (0, 0, 0, 0))
    big.paste(img, (int(200 - cx), int(200 - cy)), img)
    rot = big.rotate(ang, resample=Image.BICUBIC)
    arr = np.array(rot)
    arr[..., 3] = np.where(arr[..., 3] > 120, 255, 0)
    rot = Image.fromarray(arr)
    bb = rot.getbbox()
    rot = rot.crop(bb)
    # Pad so the sprite is centred on the crystal's centroid.
    a = np.array(rot)[..., 3] > 0
    ys, xs = np.nonzero(a)
    ccx, ccy = xs.mean(), ys.mean()
    hw = int(max(ccx, rot.width - ccx)) + 2
    hh = int(max(ccy, rot.height - ccy)) + 2
    final = Image.new("RGBA", (hw * 2, hh * 2), (0, 0, 0, 0))
    final.paste(rot, (int(hw - ccx), int(hh - ccy)), rot)
    final.save(OUT / "sprites/crystal.png")
    print("crystal", final.size, "angle", round(ang, 1))
    return poly


def stand_sprite():
    img = Image.new("RGBA", (64, 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # two brass arms meeting at a pivot, on a riveted base
    d.polygon([(10, 38), (28, 6), (36, 6), (54, 38)], fill=OUTL)
    d.polygon([(14, 36), (30, 9), (34, 9), (50, 36)], fill=BRASS_D)
    d.polygon([(18, 36), (31, 12), (33, 12), (46, 36)], fill=BRASS)
    d.rectangle([4, 32, 60, 39], fill=OUTL)
    d.rectangle([5, 33, 59, 38], fill=BRASS_D)
    d.rectangle([5, 33, 59, 34], fill=BRASS)
    d.ellipse([25, 0, 39, 14], fill=OUTL)
    d.ellipse([27, 2, 37, 12], fill=IRON)
    d.ellipse([30, 5, 34, 9], fill=(40, 40, 46))
    img.save(OUT / "sprites/stand.png")


def pole_sprite():
    h = 120
    img = Image.new("RGBA", (40, h), (0, 0, 0, 0))
    plank = wood_plank(12, h - 8, True, seed=4)
    img.paste(plank, (14, 8), plank)
    arm = wood_plank(36, 9, False, seed=5)
    img.paste(arm, (2, 10), arm)
    plate(img, 15, 30, 9)
    plate(img, 15, 80, 9)
    img.save(OUT / "sprites/pole.png")


def clamp_sprite():
    img = Image.new("RGBA", (54, 30), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 4, 53, 25], fill=OUTL)
    d.rectangle([2, 6, 51, 23], fill=IRON)
    d.rectangle([2, 19, 51, 23], fill=IRON_D)
    for x in (6, 47):
        d.ellipse([x - 2, 9, x + 2, 13], fill=(50, 50, 58))
    d.rectangle([20, 0, 33, 29], fill=OUTL)
    d.rectangle([22, 2, 31, 27], fill=(150, 40, 40))
    d.rectangle([24, 9, 29, 16], fill=(255, 90, 70))
    img.save(OUT / "sprites/clamp.png")


def beam_sprite():
    img = Image.new("RGBA", (64, 400), (0, 0, 0, 0))
    plank = wood_plank(44, 360, True, seed=9)
    img.paste(plank, (10, 30), plank)
    # broken lower end
    d = ImageDraw.Draw(img)
    d.polygon([(10, 380), (20, 372), (28, 388), (38, 370), (54, 384), (54, 400), (10, 400)], fill=(0, 0, 0, 0))
    d.line([(10, 380), (20, 372), (28, 388), (38, 370), (54, 384)], fill=OUTL, width=2)
    plate(img, 20, 40, 14)
    plate(img, 20, 200, 14)
    # chain hook
    for y in range(0, 32, 8):
        d.ellipse([27, y, 37, y + 9], outline=(60, 60, 66), width=2)
    img.save(OUT / "sprites/hanging_beam.png")


def node_sprite():
    img = Image.new("RGBA", (46, 56), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 45, 55], fill=OUTL)
    d.rectangle([2, 2, 43, 53], fill=IRON_D)
    d.rectangle([4, 4, 41, 51], fill=IRON)
    d.ellipse([10, 12, 35, 37], fill=OUTL)
    d.ellipse([13, 15, 32, 34], fill=(40, 70, 80))
    d.ellipse([18, 20, 27, 29], fill=(90, 160, 170))
    d.rectangle([8, 42, 37, 47], fill=(60, 60, 66))
    img.save(OUT / "sprites/power_node.png")


# ================================================================ level 1
def level1():
    bg = load_bg("location0.png")
    orig = bg.copy()
    # Fissure in the ledge between the boulders, opened by the collapse.
    fiss = [(656, 300), (707, 300), (712, 312), (752, 372), (704, 372), (664, 318)]
    m = poly_mask(fiss, feather=0)
    yy, xx = np.mgrid[0:H, 0:W]
    depth = np.clip((yy - 300) / 72.0, 0, 1)
    dark = np.stack([14 + 18 * depth, 10 + 10 * depth, 22 + 22 * depth], -1)
    bg = blend(bg, dark, m)
    edge = poly_mask(fiss) - np.array(Image.fromarray((poly_mask(fiss) * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(5))).astype(np.float32) / 255.0
    bg = blend(bg, np.full_like(bg, (32, 40, 34)), np.clip(edge, 0, 1) * 0.9)
    # Let the lower part of the fissure open onto the interior below.
    lower = poly_mask([(698, 360), (752, 360), (760, 380), (700, 380)], feather=4)
    bg = blend(bg, orig, lower * 0.6)

    # Elevator cabin: cut out, fill the shaft behind it.
    cab = (788, 528, 889, 690)
    cabin = orig[cab[1]:cab[3], cab[0]:cab[2]].copy()
    alpha = np.full(cabin.shape[:2], 255.0)
    # remove very dark shaft pixels at the cabin border so it reads as an object
    lum = cabin.mean(2)
    yy2, xx2 = np.mgrid[0:cabin.shape[0], 0:cabin.shape[1]]
    border = (xx2 < 4) | (xx2 > cabin.shape[1] - 5) | (yy2 < 12)
    alpha[(lum < 45) & border] = 0
    alpha[:10, :] = np.where(lum[:10, :] > 90, 255, 0)
    Image.fromarray(np.concatenate([cabin, alpha[..., None]], 2).astype(np.uint8), "RGBA").save(OUT / "sprites/l1_cabin.png")
    tile = orig[380:460, cab[0]:cab[2]]
    reps = int(np.ceil((cab[3] - cab[1]) / tile.shape[0])) + 1
    fill_src = np.concatenate([tile] * reps, 0)[:cab[3] - cab[1]]
    bg[cab[1]:cab[3], cab[0]:cab[2]] = fill_src
    # Gear disc for rotation.
    gx, gy, gr = 848, 346, 27
    g = orig[gy - gr:gy + gr, gx - gr:gx + gr].copy()
    yy3, xx3 = np.mgrid[0:2 * gr, 0:2 * gr]
    ga = (((xx3 - gr + 0.5) ** 2 + (yy3 - gr + 0.5) ** 2) <= gr * gr) * 255.0
    Image.fromarray(np.concatenate([g, ga[..., None]], 2).astype(np.uint8), "RGBA").save(OUT / "sprites/l1_gear.png")
    save(bg, OUT / "bg/level1.png")


def make_wall(path, w, h, seed=7):
    rng = np.random.default_rng(seed)
    pts = []
    y = 6
    while y < h:
        rowh = int(rng.integers(34, 52))
        x = int(rng.integers(-10, 10))
        while x < w + 20:
            cw = int(rng.integers(36, 56))
            pts.append((x + cw / 2 + rng.uniform(-5, 5), y + rowh / 2 + rng.uniform(-4, 4)))
            x += cw
        y += rowh
    pts = np.array(pts)
    yy, xx = np.mgrid[0:h, 0:w]
    d = (xx[..., None] - pts[:, 0]) ** 2 + (yy[..., None] - pts[:, 1]) ** 2
    order = np.argsort(d, axis=2)
    d1 = np.take_along_axis(d, order[..., :1], 2)[..., 0] ** 0.5
    d2 = np.take_along_axis(d, order[..., 1:2], 2)[..., 0] ** 0.5
    cell = order[..., 0]
    edge = d2 - d1
    base = np.array([116, 120, 160], np.float32)
    jitter = rng.uniform(-14, 14, len(pts))
    col = base[None, None, :] + jitter[cell][..., None]
    # bevel: lighter towards upper-left of each stone
    cx, cy = pts[cell, 0], pts[cell, 1]
    shade = np.clip(((cx - xx) + (cy - yy)) / 40.0, -1, 1)
    col = col + shade[..., None] * 26
    col = np.where((edge < 3.2)[..., None], np.array([30, 28, 44], np.float32), col)
    col = np.where(((edge >= 3.2) & (edge < 5.0) & (shade > 0))[..., None], col + 30, col)
    # rim: lighter right side like the reference, dark outline
    alpha = np.full((h, w), 255.0)
    rim = (xx > w - 10)
    col = np.where(rim[..., None], col * 0.85 + np.array([40, 30, 10]) * 0.15, col)
    col[:, :2] = (24, 22, 34)
    col[:, -2:] = (24, 22, 34)
    col[:2, :] = (24, 22, 34)
    # metal cap
    col[2:30, :] = (96, 100, 118)
    col[26:30, :] = (60, 62, 76)
    col[2:5, :] = (150, 154, 170)
    for x in range(12, w - 8, 26):
        col[12:16, x:x + 4] = (40, 40, 50)
    # quantise for a pixel-art look
    col = (np.round(col / 6) * 6)
    Image.fromarray(np.concatenate([np.clip(col, 0, 255), alpha[..., None]], 2).astype(np.uint8), "RGBA").save(path)


# ================================================================ level 2
def level2():
    bg = load_bg("location1.png")
    ref = np.array(Image.open(REF / "3.webp").convert("RGB")).astype(np.float32)
    # Breakable wall: an intact stone plug in the palette of the reference.
    make_wall(OUT / "sprites/l2_wall.png", 128, 372)
    # Pulley disc
    px, py, pr = 1522, 102, 24
    p = bg[py - pr:py + pr, px - pr:px + pr].copy()
    yy3, xx3 = np.mgrid[0:2 * pr, 0:2 * pr]
    pa = (((xx3 - pr + 0.5) ** 2 + (yy3 - pr + 0.5) ** 2) <= pr * pr) * 255.0
    Image.fromarray(np.concatenate([p, pa[..., None]], 2).astype(np.uint8), "RGBA").save(OUT / "sprites/l2_pulley.png")
    save(bg, OUT / "bg/level2.png")


# ================================================================ level 3
def level3(crystal_poly):
    bg = load_bg("location2.png")
    orig = bg.copy()
    # Remove the baked crystal (it becomes the interactive reflector).
    r, g, b = orig[..., 0], orig[..., 1], orig[..., 2]
    reddish = (r > g + 18) & (r > 70)
    region = poly_mask(crystal_poly) > 0.5
    m = (reddish & region).astype(np.uint8) * 255
    m = np.array(Image.fromarray(m).filter(ImageFilter.MaxFilter(9))).astype(np.float32) / 255.0
    m *= poly_mask([(560, 660), (800, 660), (800, 834), (560, 834)])
    bright = (r > 140) & (b > 90) & (g < r * 0.62)
    m2 = (bright & (poly_mask([(556, 690), (660, 690), (660, 834), (556, 834)]) > 0.5)).astype(np.uint8) * 255
    m2 = np.array(Image.fromarray(m2).filter(ImageFilter.MaxFilter(7))).astype(np.float32) / 255.0
    m = np.maximum(m, m2)
    src = np.roll(orig, -210, axis=1)
    soft = np.array(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5))).astype(np.float32) / 255.0
    bg = blend(bg, src, np.maximum(soft, m))
    # Cage: cut and fill with the tower section directly below it.
    cb = (1160, 436, 1378, 640)
    cage = orig[cb[1]:cb[3], cb[0]:cb[2]].copy()
    r, g, b = cage[..., 0], cage[..., 1], cage[..., 2]
    cm = poly_mask([(1166 - cb[0], 470 - cb[1]), (1290 - cb[0], 438 - cb[1]), (1372 - cb[0], 452 - cb[1]), (1376 - cb[0], 592 - cb[1]), (1222 - cb[0], 636 - cb[1]), (1160 - cb[0], 628 - cb[1])], size=(cb[2] - cb[0], cb[3] - cb[1]))
    Image.fromarray(np.concatenate([cage, (cm * 255)[..., None]], 2).astype(np.uint8), "RGBA").save(OUT / "sprites/l3_cage.png")
    hgt = cb[3] - cb[1]
    below = orig[640:640 + hgt, cb[0]:cb[2]] if 640 + hgt <= H else None
    if below is not None:
        fillm = cm[..., None]
        bg[cb[1]:cb[3], cb[0]:cb[2]] = bg[cb[1]:cb[3], cb[0]:cb[2]] * (1 - fillm) + below * fillm
    save(bg, OUT / "bg/level3.png")
    # Foreground ground strip for the worm's buried tail.
    fg = np.concatenate([orig, np.zeros((H, W, 1), np.float32)], 2)
    fgm = poly_mask([(1180, 818), (1400, 802), (1672, 800), (1672, 941), (1180, 941)], feather=1)
    fg[..., 3] = fgm * 255
    Image.fromarray(fg.astype(np.uint8), "RGBA").crop((1150, 780, 1672, 941)).save(OUT / "sprites/l3_ground_fg.png")


def worm():
    boss = Image.open(EA / "boss.png").convert("RGBA")
    a = np.array(boss)
    # Head: everything left of the neck cut.
    head_m = poly_mask([(150, 150), (560, 90), (700, 140), (720, 300), (640, 470), (560, 560), (150, 560)], size=boss.size)
    head = a.copy()
    head[..., 3] = (a[..., 3] * head_m).astype(np.uint8)
    body_m = 1 - head_m
    # Drop the lower-left coil, keep the arc and the right descent.
    body_m *= 1 - poly_mask([(0, 560), (1010, 560), (1080, 640), (1000, 1024), (0, 1024)], size=boss.size)
    body = a.copy()
    body[..., 3] = (a[..., 3] * body_m).astype(np.uint8)
    Image.fromarray(head).crop(Image.fromarray(head).getbbox()).save(OUT / "sprites/worm_head.png")
    Image.fromarray(body).crop(Image.fromarray(body).getbbox()).save(OUT / "sprites/worm_body.png")
    print("head bbox", Image.fromarray(head).getbbox(), "body bbox", Image.fromarray(body).getbbox())


poly = crystal_sprite()
stand_sprite()
pole_sprite()
clamp_sprite()
beam_sprite()
node_sprite()
level1()
level2()
level3(poly)
worm()
for i in (1, 2, 3):
    Image.open(REF / f"{i}.webp").convert("RGB").save(OUT / f"art/reference{i}.png")
print("done")
