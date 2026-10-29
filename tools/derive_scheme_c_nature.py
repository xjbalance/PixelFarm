"""Derive native-size map surfaces from the user's Scheme C PNGs, without changing sources.

No generated images or textures from unrelated games are used. Source sprites and the
47-pattern terrain sheets remain byte-for-byte copies in assets/world_scheme_c.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets/world_scheme_c"
OUT = ART / "derived"
SEASONS = ("spring", "summer", "autumn", "winter")
MAPPING = json.loads((ART / "terrain_mapping.json").read_text())
REGIONS = {entry["id"]: {tile["mask"]: tile["atlas"] for tile in entry["tiles"]} for entry in MAPPING["sets"]}
DIRECTIONS = ((0, -1, 1), (1, -1, 2), (1, 0, 4), (1, 1, 8),
              (0, 1, 16), (-1, 1, 32), (-1, 0, 64), (-1, -1, 128))


def picture(name: str, season: str) -> Image.Image:
    path = ART / "seasons" / season / f"{name}.png"
    if not path.exists():
        path = ART / "bright" / "sprites" / f"{name}.png"
        if not path.exists():
            path = ART / "sprites" / f"{name}.png"
    return Image.open(path).convert("RGBA")


def valid_mask(mask: int) -> int:
    for diagonal, edge_a, edge_b in ((2, 1, 4), (8, 4, 16), (32, 16, 64), (128, 64, 1)):
        if mask & edge_a == 0 or mask & edge_b == 0:
            mask &= ~diagonal
    return mask


def terrain(name: str, season: str, mask: int = 255) -> Image.Image:
    sheet = Image.open(ART / "seasons" / season / "terrain" / f"{name}.png").convert("RGBA")
    x, y = REGIONS[name][valid_mask(mask)]
    return sheet.crop((x * 32, y * 32, x * 32 + 32, y * 32 + 32))


def farm_kind(x: int, y: int) -> int:
    kind = 0
    if y in (13, 14) or (x in (14, 15) and y > 5):
        kind = 3
    if 16 <= x < 28 and 15 <= y < 23:
        kind = 4
    distance = ((x - 34) ** 2 + (y - 18) ** 2) ** .5
    if distance < 4.8:
        kind = 3
    if distance < 4.1:
        kind = 5
    if distance < 2.9:
        kind = 6
    return kind


def water_tile(season: str) -> Image.Image:
    # The source pond is not a seamless texture. Reflect one clean native 16px
    # patch to pair opposite edges, then lower only its contrast for readable water.
    pond = picture("large_pond", season)
    patch = pond.crop((60, 32, 76, 48)).convert("RGB")
    patch = ImageEnhance.Contrast(patch).enhance(.26)
    patch = Image.blend(patch, Image.new("RGB", patch.size, "#72bdca"), .34).convert("RGBA")
    water = Image.new("RGBA", (32, 32))
    water.alpha_composite(patch, (0, 0))
    water.alpha_composite(ImageOps.mirror(patch), (16, 0))
    water.alpha_composite(ImageOps.flip(patch), (0, 16))
    water.alpha_composite(ImageOps.flip(ImageOps.mirror(patch)), (16, 16))
    if season == "winter":
        water = Image.blend(water, Image.new("RGBA", (32, 32), "#b3cfce"), .35)
    return water


def grass_variants(season: str) -> list[Image.Image]:
    base = picture("grass", season)
    return [base, ImageOps.mirror(base), ImageOps.flip(base)]


def ground_atlas(season: str) -> Image.Image:
    atlas = Image.new("RGBA", (256, 32))
    tiles = grass_variants(season) + [picture("dirt_path", season), picture("dirt", season),
                                      water_tile(season), water_tile(season), picture("wood_path", season)]
    for index, tile in enumerate(tiles):
        atlas.alpha_composite(tile, (index * 32, 0))
    return atlas


def forest_atlas(season: str) -> Image.Image:
    atlas = Image.new("RGBA", (256, 32))
    grass = picture("grass", season)
    wall = ImageEnhance.Brightness(grass).enhance(.72)
    barrier = wall.copy()
    hedge = picture("bush", season)
    barrier.alpha_composite(hedge, ((32 - hedge.width) // 2, 32 - hedge.height))
    tiles = [grass, wall, water_tile(season), picture("dirt_path", season), barrier,
             picture("wood_path", season), picture("stone_path", season), grass]
    for index, tile in enumerate(tiles):
        atlas.alpha_composite(tile, (index * 32, 0))
    return atlas


def farm_ground(season: str) -> Image.Image:
    result = Image.new("RGBA", (1536, 1024))
    grasses = grass_variants(season)
    water = water_tile(season)
    water_mask = Image.new("L", result.size)
    water_draw = ImageDraw.Draw(water_mask)
    for y in range(32):
        for x in range(48):
            kind = farm_kind(x, y)
            if kind < 3:
                tile = grasses[(x * 71 + y * 137) % 3]
            elif kind in (3, 4):
                name = "dirt_path" if kind == 3 else "dirt"
                mask = sum(bit for dx, dy, bit in DIRECTIONS
                           if farm_kind(x + dx, y + dy) == kind or kind == 3 and farm_kind(x + dx, y + dy) in (5, 6))
                tile = terrain(name, season, mask)
            else:
                tile = water.copy()
                water_draw.rectangle((x * 32, y * 32, x * 32 + 31, y * 32 + 31), fill=255)
            result.alpha_composite(tile, (x * 32, y * 32))
    # Build crisp binary shore masks at the original collision shoreline. Filtering
    # shapes only the mask; the final art is native pixel texture with no soft edges.
    # Water never extends into walkable cells. A 6px bank softens staircase corners.
    smooth = water_mask.filter(ImageFilter.GaussianBlur(4)).point(lambda value: 255 if value >= 160 else 0)
    smooth = ImageChops.darker(smooth, water_mask)
    outer = water_mask.filter(ImageFilter.MaxFilter(13)).filter(ImageFilter.GaussianBlur(3)).point(lambda value: 255 if value >= 104 else 0)
    bank_mask = ImageChops.subtract(outer, smooth)
    bank_image = Image.new("RGBA", result.size)
    sand = ImageEnhance.Color(picture("sand", season)).enhance(.65)
    for y in range(13 * 32, 24 * 32, 32):
        for x in range(29 * 32, 40 * 32, 32):
            bank_image.alpha_composite(sand, (x, y))
    result.paste(bank_image, (0, 0), bank_mask)
    # Place a handful of separated native-pixel wave strokes over the whole pond,
    # instead of one bright highlight repeated in every 32px tile.
    ripples = ImageDraw.Draw(result)
    for x, y, width in ((1030, 504, 8), (1103, 533, 12), (1017, 581, 10),
                         (1131, 611, 7), (1074, 646, 11), (1161, 555, 6)):
        if smooth.getpixel((x, y)):
            ripples.line((x, y, x + width, y), fill="#91c3bd" if season != "winter" else "#c2dcda", width=1)
    # Sparse, native-sized herbs decorate free grass. They sit below the editing surface.
    # Buildings, original fields, resources and their approach areas are left readable.
    names = ("short_grass", "clover", "grass_clump", "white_wildflowers", "yellow_wildflowers")
    protected = ((16, 7, 10, 8), (8, 9, 6, 6), (16, 14, 13, 10), (29, 13, 12, 11))
    for index in range(135):
        x, y = 2 + index * 17 % 44, 2 + index * 11 % 28
        if farm_kind(x, y) != 0 or any(px <= x < px + w and py <= y < py + h for px, py, w, h in protected):
            continue
        image = picture(names[index % len(names)], season)
        result.alpha_composite(image, (x * 32 + 16 - image.width // 2, y * 32 + 18 - image.height))
    return result


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    files = []
    for season in SEASONS:
        atlas = ground_atlas(season)
        outputs = {f"ground_{season}.png": atlas, f"farm_ground_{season}.png": farm_ground(season),
                   f"forest_ground_{season}.png": forest_atlas(season)}
        annex = Image.new("RGBA", (160, 32))
        for index in range(5):
            source = atlas.crop((min(index, 3) * 32, 0, min(index, 3) * 32 + 32, 32))
            if index == 4:
                source = ImageEnhance.Brightness(atlas.crop((0, 0, 32, 32))).enhance(.8)
            annex.alpha_composite(source, (index * 32, 0))
        outputs[f"annex_ground_{season}.png"] = annex
        for name, image in outputs.items():
            path = OUT / name
            image.save(path)
            files.append({"path": path.relative_to(ROOT).as_posix(), "size": list(image.size),
                          "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    dry = picture("tilled_soil", "spring")
    dry.save(OUT / "soil_dry.png")
    # Blue-brown damp soil retains the supplied furrows and the exact 32px plot boundary.
    wet = Image.blend(ImageEnhance.Brightness(dry).enhance(.73), Image.new("RGBA", dry.size, "#3d4548"), .15)
    wet.save(OUT / "soil_wet.png")
    for name in ("soil_dry.png", "soil_wet.png"):
        path = OUT / name
        files.append({"path": path.relative_to(ROOT).as_posix(), "size": [32, 32],
                      "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    (OUT / "nature_derivatives.json").write_text(json.dumps({
        "source": "User-provided Scheme C groups 1–10; native 32px assets",
        "source_manifest_sha256": hashlib.sha256((ART / "manifest.json").read_bytes()).hexdigest(),
        "method": "47-mask terrain composition, mirrored native pond samples with paired edges, binary 6px shore masks, seasonal palettes; no resize",
        "gameplay_coordinates_changed": False, "outputs": files,
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf8")
    print(f"Derived {len(files)} native map surfaces; original source sprites unchanged.")


if __name__ == "__main__":
    main()
