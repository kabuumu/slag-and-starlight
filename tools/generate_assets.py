#!/usr/bin/env python3
"""
Procedural Retro Pixel-Art Asset Generator for "Slag & Starlight" (Khoros-IV).
Generates a locked 256-color industrial/rust palette and all textures,
8-directional sprite sheets, HUD weapon frames, and paper-doll/UI PNGs.

Requires: Python 3.11+, Pillow 9.4.0+, NumPy 1.24.2+
"""

from pathlib import Path
import math
import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent.parent
ASSETS_DIR = ROOT / "assets"
TEXTURES_DIR = ASSETS_DIR / "textures"
SPRITES_DIR = ASSETS_DIR / "sprites"
WEAPONS_DIR = ASSETS_DIR / "weapons"
UI_DIR = ASSETS_DIR / "ui"


def build_khoros_palette() -> np.ndarray:
    """Build a deterministic locked 256-color Khoros-IV rust/industrial palette (256, 3) uint8."""
    colors: list[tuple[int, int, int]] = []

    def add_ramp(c0: tuple[int, int, int], c1: tuple[int, int, int], steps: int) -> None:
        for i in range(steps):
            t = i / max(1, steps - 1)
            r = int(round(c0[0] + (c1[0] - c0[0]) * t))
            g = int(round(c0[1] + (c1[1] - c0[1]) * t))
            b = int(round(c0[2] + (c1[2] - c0[2]) * t))
            colors.append((max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b))))

    # 1. Void / Charcoal / Steel Greys (48)
    add_ramp((8, 6, 8), (64, 58, 62), 16)
    add_ramp((68, 70, 78), (150, 156, 166), 16)
    add_ramp((156, 164, 174), (236, 240, 244), 16)

    # 2. Khoros Rust & Iron Oxide (48)
    add_ramp((28, 12, 8), (112, 42, 20), 16)
    add_ramp((118, 48, 22), (194, 88, 36), 16)
    add_ramp((198, 96, 44), (242, 168, 108), 16)

    # 3. Arid Khoros Sand / Rock / Ochre (32)
    add_ramp((44, 30, 18), (138, 98, 62), 16)
    add_ramp((144, 106, 68), (226, 186, 134), 16)

    # 4. Hazard Yellow & Amber (32)
    add_ramp((64, 44, 6), (186, 134, 16), 16)
    add_ramp((196, 148, 24), (252, 224, 92), 16)

    # 5. CRT Phosphor Green & Industrial Olive (32)
    add_ramp((10, 28, 14), (42, 132, 54), 16)
    add_ramp((52, 156, 64), (156, 250, 142), 16)

    # 6. Starlight Cyan & Plasma Blue (32)
    add_ramp((10, 24, 42), (38, 110, 178), 16)
    add_ramp((54, 138, 208), (168, 236, 255), 16)

    # 7. Warning Crimson & Laser Red (32)
    add_ramp((36, 8, 10), (148, 22, 24), 16)
    add_ramp((164, 34, 30), (252, 118, 96), 16)

    assert len(colors) == 256, f"Expected 256 palette colors, got {len(colors)}"
    return np.array(colors, dtype=np.uint8)


PALETTE = build_khoros_palette()


def quantize_to_palette(img: Image.Image) -> Image.Image:
    """Quantize an RGB or RGBA image strictly to the locked 256-color Khoros palette."""
    has_alpha = img.mode == "RGBA"
    rgba = img.convert("RGBA")
    arr = np.array(rgba, dtype=np.int16)
    rgb = arr[:, :, :3].reshape(-1, 3)
    alpha = arr[:, :, 3]

    pal = PALETTE.astype(np.int16)
    # Squared Euclidean distance to 256 palette entries
    diff = rgb[:, None, :] - pal[None, :, :]
    dist = np.sum(diff * diff, axis=2)
    nearest_idx = np.argmin(dist, axis=1)
    q_rgb = PALETTE[nearest_idx].reshape(arr.shape[0], arr.shape[1], 3)

    if has_alpha:
        out = np.dstack([q_rgb, (alpha > 127).astype(np.uint8) * 255])
        return Image.fromarray(out, mode="RGBA")
    return Image.fromarray(q_rgb, mode="RGB")


def save_png(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    quantized = quantize_to_palette(img)
    quantized.save(path, format="PNG")


def periodic_noise(size: int, seed: int, scale: int = 8) -> np.ndarray:
    """Generate tileable value noise in [0, 1] of shape (size, size)."""
    rng = np.random.default_rng(seed)
    grid_n = max(2, size // scale)
    grid = rng.random((grid_n, grid_n))
    ys = np.arange(size) / scale
    xs = np.arange(size) / scale
    y0 = np.floor(ys).astype(int) % grid_n
    x0 = np.floor(xs).astype(int) % grid_n
    y1 = (y0 + 1) % grid_n
    x1 = (x0 + 1) % grid_n
    fy = (ys - np.floor(ys))[:, None]
    fx = (xs - np.floor(xs))[None, :]
    v00 = grid[np.ix_(y0, x0)]
    v10 = grid[np.ix_(y1, x0)]
    v01 = grid[np.ix_(y0, x1)]
    v11 = grid[np.ix_(y1, x1)]
    top = v00 * (1 - fx) + v01 * fx
    bot = v10 * (1 - fx) + v11 * fx
    return top * (1 - fy) + bot * fy


def generate_textures() -> None:
    # 1. wall_rust.png (64x64) - Riveted rusted steel panels
    size = 64
    n1 = periodic_noise(size, 101, 8)
    n2 = periodic_noise(size, 102, 4)
    img = Image.new("RGB", (size, size), (76, 56, 48))
    px = img.load()
    for y in range(size):
        for x in range(size):
            rust = n1[y, x] * 0.65 + n2[y, x] * 0.35
            base = (88, 76, 74) if rust < 0.52 else (136, 58, 30)
            if rust > 0.72:
                base = (174, 78, 34)
            # Panel seams every 32px
            if x % 32 == 0 or y % 32 == 0:
                base = (28, 22, 22)
            elif x % 32 == 1 or y % 32 == 1:
                base = (128, 124, 126)
            # Rivets near corners
            if (x % 32 in (4, 27)) and (y % 32 in (4, 27)):
                base = (196, 178, 166)
            px[x, y] = base
    save_png(img, TEXTURES_DIR / "wall_rust.png")

    # 2. floor_grate.png (64x64) - Dark industrial diamond/grid floor grate
    img = Image.new("RGB", (size, size), (24, 22, 24))
    px = img.load()
    n = periodic_noise(size, 202, 4)
    for y in range(size):
        for x in range(size):
            in_bar = (x % 8 < 2) or (y % 8 < 2)
            if in_bar:
                c = (94, 96, 102) if (x % 8 == 0 or y % 8 == 0) else (62, 60, 64)
                if n[y, x] > 0.7:
                    c = (128, 60, 32)
            else:
                c = (16, 14, 18) if n[y, x] < 0.6 else (32, 20, 16)
            px[x, y] = c
    save_png(img, TEXTURES_DIR / "floor_grate.png")

    # 3. ceiling_pipe.png (64x64) - Overhead pipes & dark steel ribs
    img = Image.new("RGB", (size, size), (34, 34, 38))
    px = img.load()
    for y in range(size):
        for x in range(size):
            band = y % 16
            if band in (3, 4, 5, 6, 7):
                shade = 1.0 - abs(band - 5) * 0.22
                c = (int(110 * shade), int(84 * shade), int(64 * shade))
                if x % 16 in (0, 1):
                    c = (150, 146, 140)
            elif x % 32 < 3:
                c = (56, 58, 64)
            else:
                c = (22, 22, 26)
            px[x, y] = c
    save_png(img, TEXTURES_DIR / "ceiling_pipe.png")

    # 4. door_blast.png (128x128) - Heavy reinforced blast door with hazard stripes
    dsize = 128
    img = Image.new("RGB", (dsize, dsize), (74, 78, 86))
    draw = ImageDraw.Draw(img)
    draw.rectangle([0, 0, 127, 127], outline=(24, 24, 28), width=4)
    draw.rectangle([8, 8, 119, 119], fill=(82, 86, 94), outline=(140, 146, 154), width=2)
    # Center seam
    draw.line([(63, 8), (63, 119)], fill=(20, 20, 24), width=3)
    draw.line([(66, 8), (66, 119)], fill=(140, 146, 154), width=1)
    # Hazard stripe band
    for y in range(96, 112):
        for x in range(12, 116):
            stripe = ((x + y) // 8) % 2 == 0
            img.putpixel((x, y), (218, 166, 28) if stripe else (24, 22, 22))
    # Warning light
    draw.rectangle([56, 20, 72, 30], fill=(196, 42, 32), outline=(28, 20, 20))
    save_png(img, TEXTURES_DIR / "door_blast.png")

    # 5. crate_supply.png (64x64) - Industrial supply crate
    img = Image.new("RGB", (size, size), (128, 88, 52))
    draw = ImageDraw.Draw(img)
    draw.rectangle([0, 0, 63, 63], outline=(42, 28, 18), width=4)
    draw.rectangle([6, 6, 57, 57], fill=(148, 106, 64), outline=(188, 146, 96), width=2)
    draw.line([(8, 8), (55, 55)], fill=(96, 64, 38), width=4)
    draw.line([(55, 8), (8, 55)], fill=(96, 64, 38), width=4)
    draw.rectangle([22, 24, 41, 39], fill=(212, 158, 28), outline=(42, 28, 18))
    save_png(img, TEXTURES_DIR / "crate_supply.png")

    # 6. vent_grate.png (64x64) - Slotted maintenance ventilation grate
    img = Image.new("RGB", (size, size), (72, 76, 82))
    draw = ImageDraw.Draw(img)
    draw.rectangle([0, 0, 63, 63], outline=(28, 30, 34), width=4)
    for y in range(8, 56, 6):
        draw.rectangle([8, y, 55, y + 3], fill=(14, 14, 18))
        draw.line([(8, y + 4), (55, y + 4)], fill=(128, 134, 142), width=1)
    save_png(img, TEXTURES_DIR / "vent_grate.png")

    # 7. rock_khoros.png (64x64) - Arid rust-red Khoros-IV regolith/rock
    n1 = periodic_noise(size, 303, 8)
    n2 = periodic_noise(size, 304, 4)
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            v = n1[y, x] * 0.7 + n2[y, x] * 0.3
            if v < 0.3:
                c = (68, 32, 20)
            elif v < 0.55:
                c = (128, 62, 34)
            elif v < 0.8:
                c = (168, 92, 52)
            else:
                c = (204, 134, 84)
            px[x, y] = c
    save_png(img, TEXTURES_DIR / "rock_khoros.png")

    # 8. catwalk_metal.png (64x64) - Perforated steel catwalk
    img = Image.new("RGB", (size, size), (82, 86, 94))
    px = img.load()
    for y in range(size):
        for x in range(size):
            if y < 4 or y >= 60:
                px[x, y] = (196, 148, 24) if (x // 6) % 2 == 0 else (28, 28, 32)
            elif (x % 6 in (2, 3)) and (y % 6 in (2, 3)):
                px[x, y] = (18, 18, 22)
            else:
                px[x, y] = (98, 104, 112)
    save_png(img, TEXTURES_DIR / "catwalk_metal.png")


def draw_8dir_sheet(
    filename: str,
    body_color: tuple[int, int, int],
    accent_color: tuple[int, int, int],
    visor_color: tuple[int, int, int],
    style: str = "humanoid",
) -> None:
    """
    Create a 256x512 (4 cols x 8 rows of 64x64) 8-directional sprite sheet.
    Rows: 0=Front, 1=Front-Left, 2=Left, 3=Back-Left, 4=Back, 5=Back-Right, 6=Right, 7=Front-Right.
    """
    fw, fh = 64, 64
    cols, rows = 4, 8
    sheet = Image.new("RGBA", (fw * cols, fh * rows), (0, 0, 0, 0))
    draw = ImageDraw.Draw(sheet)

    # Facing angle per row (0 = facing camera/+Z)
    angles = [0, 45, 90, 135, 180, -135, -90, -45]

    for r, ang in enumerate(angles):
        rad = math.radians(ang)
        facing_x = math.sin(rad)
        facing_front = math.cos(rad)  # > 0 means front visible, < 0 means back visible

        for c in range(cols):
            ox = c * fw
            oy = r * fh
            bob = -2 if c % 2 == 1 else 0
            stride = (c - 1.5) * 2

            if style == "tick":
                # Low crouched 4-legged slag-tick
                cx, cy = ox + 32, oy + 42 + bob
                draw.ellipse([cx - 14, cy - 8, cx + 14, cy + 8], fill=body_color + (255,), outline=(18, 14, 14, 255))
                # Legs
                for lx in (-12, -5, 5, 12):
                    draw.line([(cx + lx, cy + 4), (cx + lx + int(stride * 0.5), cy + 14)], fill=accent_color + (255,), width=2)
                if facing_front > -0.2:
                    ex = cx + int(facing_x * 8)
                    draw.rectangle([ex - 4, cy - 4, ex + 4, cy + 1], fill=visor_color + (255,))
            elif style == "drone":
                # Hovering mining drone sphere + thrusters
                cx, cy = ox + 32, oy + 28 + bob
                draw.ellipse([cx - 14, cy - 14, cx + 14, cy + 14], fill=body_color + (255,), outline=(24, 24, 28, 255))
                draw.rectangle([cx - 18, cy - 4, cx + 18, cy + 4], fill=accent_color + (255,))
                if facing_front > -0.2:
                    ex = cx + int(facing_x * 8)
                    draw.ellipse([ex - 5, cy - 5, ex + 5, cy + 5], fill=visor_color + (255,))
                # Thruster flame
                draw.polygon([(cx - 4, cy + 15), (cx + 4, cy + 15), (cx, cy + 23 + (c % 2) * 3)], fill=(242, 168, 108, 255))
            elif style == "turret":
                # Tripod sentry turret
                cx, cy = ox + 32, oy + 36
                draw.line([(cx, cy), (cx - 14, cy + 20)], fill=(64, 68, 74, 255), width=3)
                draw.line([(cx, cy), (cx + 14, cy + 20)], fill=(64, 68, 74, 255), width=3)
                draw.line([(cx, cy), (cx, cy + 22)], fill=(44, 48, 52, 255), width=3)
                draw.rectangle([cx - 12, cy - 14, cx + 12, cy + 4], fill=body_color + (255,), outline=(20, 20, 24, 255))
                bx = cx + int(facing_x * 14)
                draw.line([(cx, cy - 5), (bx, cy - 5)], fill=accent_color + (255,), width=4)
                if facing_front > -0.3:
                    ex = cx + int(facing_x * 6)
                    draw.rectangle([ex - 3, cy - 10, ex + 3, cy - 6], fill=visor_color + (255,))
            elif style == "mech":
                # Heavy excavation mech (Unit 734-B)
                cx, cy = ox + 32, oy + 32 + bob
                draw.rectangle([cx - 16, cy - 22, cx + 16, cy + 6], fill=body_color + (255,), outline=(18, 16, 18, 255))
                draw.rectangle([cx - 20, cy - 18, cx + 20, cy - 8], fill=accent_color + (255,))
                # Legs
                draw.rectangle([cx - 13, cy + 6, cx - 4, cy + 26 + int(stride)], fill=(68, 70, 78, 255))
                draw.rectangle([cx + 4, cy + 6, cx + 13, cy + 26 - int(stride)], fill=(68, 70, 78, 255))
                if facing_front > -0.2:
                    ex = cx + int(facing_x * 8)
                    draw.rectangle([ex - 6, cy - 16, ex + 6, cy - 11], fill=visor_color + (255,))
            else:
                # Standard humanoid (player, feral driller, kael)
                cx, cy = ox + 32, oy + 30 + bob
                # Legs
                draw.rectangle([cx - 8, cy + 6, cx - 2, cy + 24 + int(stride)], fill=(48, 50, 56, 255))
                draw.rectangle([cx + 2, cy + 6, cx + 8, cy + 24 - int(stride)], fill=(48, 50, 56, 255))
                # Torso
                draw.rectangle([cx - 10, cy - 10, cx + 10, cy + 8], fill=body_color + (255,), outline=(20, 18, 20, 255))
                # Shoulders/Pauldrons
                draw.rectangle([cx - 13, cy - 10, cx - 8, cy - 2], fill=accent_color + (255,))
                draw.rectangle([cx + 8, cy - 10, cx + 13, cy - 2], fill=accent_color + (255,))
                # Head
                draw.rectangle([cx - 6, cy - 22, cx + 6, cy - 10], fill=body_color + (255,), outline=(20, 18, 20, 255))
                if facing_front > -0.2:
                    ex = cx + int(facing_x * 4)
                    draw.rectangle([ex - 4, cy - 18, ex + 4, cy - 14], fill=visor_color + (255,))
                else:
                    # Backpack / oxygen tank on back
                    draw.rectangle([cx - 6, cy - 8, cx + 6, cy + 4], fill=accent_color + (255,))

    save_png(sheet, SPRITES_DIR / filename)


def generate_sprites() -> None:
    draw_8dir_sheet("player_placeholder.png", (94, 112, 130), (194, 88, 36), (118, 224, 248), "humanoid")
    draw_8dir_sheet("slag_tick.png", (156, 62, 32), (112, 42, 20), (242, 198, 64), "tick")
    draw_8dir_sheet("mining_drone.png", (124, 130, 140), (212, 158, 28), (240, 62, 46), "drone")
    draw_8dir_sheet("feral_driller.png", (138, 64, 38), (218, 166, 28), (252, 92, 68), "humanoid")
    draw_8dir_sheet("sentry_turret.png", (102, 108, 118), (186, 134, 16), (252, 74, 58), "turret")
    draw_8dir_sheet("unit_734b.png", (148, 64, 32), (218, 166, 28), (118, 236, 255), "mech")
    draw_8dir_sheet("kael_npc.png", (68, 112, 84), (176, 116, 64), (168, 236, 255), "humanoid")

    # spark_2d.png (4 frames x 1 row, 32x32 each -> 128x32)
    spark = Image.new("RGBA", (128, 32), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(spark)
    for f in range(4):
        cx, cy = f * 32 + 16, 16
        r = 12 - f * 2
        for a in range(0, 360, 45):
            rad = math.radians(a + f * 15)
            sdraw.line([(cx, cy), (cx + int(math.cos(rad) * r), cy + int(math.sin(rad) * r))], fill=(252, 224, 92, 255), width=2)
        sdraw.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=(242, 168, 108, 255))
    save_png(spark, SPRITES_DIR / "spark_2d.png")

    # pickup_item.png (64x64 glowing crate/canister)
    pick = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    pdraw = ImageDraw.Draw(pick)
    pdraw.rectangle([18, 20, 46, 48], fill=(118, 124, 134, 255), outline=(24, 24, 28, 255), width=2)
    pdraw.rectangle([22, 26, 42, 34], fill=(118, 236, 255, 255))
    pdraw.rectangle([24, 14, 40, 20], fill=(212, 158, 28, 255))
    save_png(pick, SPRITES_DIR / "pickup_item.png")


def generate_weapons() -> None:
    # 128x128 HUD weapon sprites anchored bottom-right
    # blaster_idle.png
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(52, 127), (78, 127), (84, 72), (62, 64)], fill=(76, 80, 88, 255), outline=(20, 20, 24, 255))
    d.polygon([(40, 68), (88, 46), (96, 62), (48, 84)], fill=(124, 130, 140, 255), outline=(20, 20, 24, 255))
    d.rectangle([58, 52, 74, 62], fill=(54, 138, 208, 255))
    d.rectangle([34, 72, 46, 82], fill=(194, 88, 36, 255))
    save_png(img, WEAPONS_DIR / "blaster_idle.png")

    # blaster_fire.png
    fire = img.copy()
    fd = ImageDraw.Draw(fire)
    fd.ellipse([18, 56, 46, 84], fill=(252, 224, 92, 255))
    fd.ellipse([24, 62, 40, 78], fill=(168, 236, 255, 255))
    save_png(fire, WEAPONS_DIR / "blaster_fire.png")

    # spanner_idle.png
    sp = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sp)
    sd.polygon([(74, 127), (92, 127), (64, 44), (48, 48)], fill=(156, 78, 40, 255), outline=(24, 20, 20, 255))
    sd.ellipse([34, 22, 68, 54], fill=(132, 138, 148, 255), outline=(24, 24, 28, 255))
    sd.rectangle([42, 22, 56, 36], fill=(0, 0, 0, 0))
    save_png(sp, WEAPONS_DIR / "spanner_idle.png")

    # spanner_swing.png
    sw = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    swd = ImageDraw.Draw(sw)
    swd.polygon([(20, 127), (40, 127), (98, 56), (82, 44)], fill=(156, 78, 40, 255), outline=(24, 20, 20, 255))
    swd.ellipse([78, 24, 114, 58], fill=(156, 164, 174, 255), outline=(24, 24, 28, 255))
    swd.arc([28, 16, 110, 98], 200, 320, fill=(242, 168, 108, 255), width=3)
    save_png(sw, WEAPONS_DIR / "spanner_swing.png")


def generate_ui() -> None:
    # Paper-doll base & layers (128x256 RGBA)
    base = Image.new("RGBA", (128, 256), (0, 0, 0, 0))
    d = ImageDraw.Draw(base)
    # Head
    d.ellipse([48, 18, 80, 52], fill=(94, 98, 108, 255), outline=(24, 24, 28, 255))
    # Neck & Torso
    d.rectangle([58, 50, 70, 60], fill=(72, 76, 84, 255))
    d.polygon([(38, 60), (90, 60), (82, 142), (46, 142)], fill=(76, 82, 92, 255), outline=(24, 24, 28, 255))
    # Arms
    d.rectangle([22, 62, 38, 134], fill=(68, 72, 82, 255), outline=(24, 24, 28, 255))
    d.rectangle([90, 62, 106, 134], fill=(68, 72, 82, 255), outline=(24, 24, 28, 255))
    # Legs
    d.rectangle([44, 142, 60, 232], fill=(62, 66, 76, 255), outline=(24, 24, 28, 255))
    d.rectangle([68, 142, 84, 232], fill=(62, 66, 76, 255), outline=(24, 24, 28, 255))
    save_png(base, UI_DIR / "paperdoll_undersuit.png")

    # Paper-doll Torso layer
    torso = Image.new("RGBA", (128, 256), (0, 0, 0, 0))
    td = ImageDraw.Draw(torso)
    td.polygon([(36, 60), (92, 60), (84, 140), (44, 140)], fill=(156, 76, 36, 255), outline=(24, 20, 20, 255))
    td.rectangle([52, 76, 76, 98], fill=(118, 124, 134, 255))
    save_png(torso, UI_DIR / "paperdoll_torso.png")

    # Paper-doll Helmet layer
    helm = Image.new("RGBA", (128, 256), (0, 0, 0, 0))
    hd = ImageDraw.Draw(helm)
    hd.ellipse([46, 16, 82, 54], fill=(140, 146, 154, 255), outline=(24, 24, 28, 255))
    hd.rectangle([52, 28, 76, 38], fill=(118, 236, 255, 255))
    save_png(helm, UI_DIR / "paperdoll_helmet.png")

    # Paper-doll Pauldrons layer
    pauld = Image.new("RGBA", (128, 256), (0, 0, 0, 0))
    pd = ImageDraw.Draw(pauld)
    pd.ellipse([18, 54, 44, 82], fill=(194, 88, 36, 255), outline=(24, 20, 20, 255))
    pd.ellipse([84, 54, 110, 82], fill=(194, 88, 36, 255), outline=(24, 20, 20, 255))
    save_png(pauld, UI_DIR / "paperdoll_pauldrons.png")

    # Paper-doll Gauntlets layer
    gaunt = Image.new("RGBA", (128, 256), (0, 0, 0, 0))
    gd = ImageDraw.Draw(gaunt)
    gd.rectangle([20, 108, 40, 138], fill=(212, 158, 28, 255), outline=(24, 20, 20, 255))
    gd.rectangle([88, 108, 108, 138], fill=(212, 158, 28, 255), outline=(24, 20, 20, 255))
    save_png(gaunt, UI_DIR / "paperdoll_gauntlets.png")

    # Paper-doll Greaves layer
    greav = Image.new("RGBA", (128, 256), (0, 0, 0, 0))
    grd = ImageDraw.Draw(greav)
    grd.rectangle([42, 176, 62, 234], fill=(124, 130, 140, 255), outline=(24, 24, 28, 255))
    grd.rectangle([66, 176, 86, 234], fill=(124, 130, 140, 255), outline=(24, 24, 28, 255))
    save_png(greav, UI_DIR / "paperdoll_greaves.png")

    # Starter 32x32 item icons
    icons = {
        "icon_blaster.png": ((124, 130, 140), (54, 138, 208)),
        "icon_spanner.png": ((156, 78, 40), (164, 170, 178)),
        "icon_suit.png": ((174, 78, 34), (118, 124, 134)),
        "icon_medhypo.png": ((196, 42, 32), (236, 240, 244)),
        "icon_powercell.png": ((54, 138, 208), (218, 166, 28)),
        "icon_keycard.png": ((218, 166, 28), (118, 236, 255)),
        "icon_gauntlets.png": ((212, 158, 28), (82, 86, 94)),
        "icon_blackbox.png": ((42, 132, 54), (156, 250, 142)),
        "icon_magpick.png": ((150, 156, 166), (242, 168, 108)),
    }
    for name, (c1, c2) in icons.items():
        ic = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        icd = ImageDraw.Draw(ic)
        icd.rectangle([4, 4, 27, 27], fill=c1 + (255,), outline=(20, 20, 24, 255), width=2)
        icd.rectangle([10, 10, 21, 21], fill=c2 + (255,))
        save_png(ic, UI_DIR / name)


def main() -> None:
    generate_textures()
    generate_sprites()
    generate_weapons()
    generate_ui()
    print("Generated all Khoros-IV 256-color retro assets in:", ASSETS_DIR)


if __name__ == "__main__":
    main()
