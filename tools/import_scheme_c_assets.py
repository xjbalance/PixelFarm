"""Verify and import the user-provided Scheme C pack without editing its originals.

The provided atlases/SpriteFrames are copied byte-for-byte. UI illustrations are
explicit crops from the supplied reference, not enlarged world sprites. Ceremony
atlases are light, documented palette derivatives of the supplied walk frames.
"""
from __future__ import annotations

import argparse
import colorsys
import hashlib
import json
from pathlib import Path
import re
import shutil

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PACK = ROOT / "need/PixelWorld_SchemeC_Codex_Reference_Pack"
OUT = ROOT / "assets/characters/scheme_c"
VARIANTS = ("player_male", "player_female", "xiaojing_female", "xiaojing_male")
DIRECTIONS = ("down", "left", "right", "up")
# Coordinates are local to the corresponding unmodified reference column.
# The front portrait crops stay strictly inside the original face frames.
PORTRAITS = {
    "player_male": (265, 82, 339, 180),
    "player_female": (262, 83, 336, 179),
    "xiaojing_female": (268, 83, 344, 179),
    "xiaojing_male": (270, 82, 349, 179),
}
# These card masks exclude titles, swatches, auxiliary heads, pixel figurines and
# captions. Paper within the selected illustration is intentionally retained.
STANDING = {
    "player_male": [(8, 55), (253, 55), (253, 296), (278, 304), (281, 574), (256, 590), (256, 767), (8, 767)],
    "player_female": [(5, 74), (255, 74), (255, 308), (294, 344), (294, 584), (255, 600), (233, 638), (233, 765), (5, 765)],
    "xiaojing_female": [(12, 55), (258, 55), (258, 300), (300, 303), (300, 445), (324, 455), (324, 558), (285, 588), (231, 613), (231, 768), (12, 768)],
    "xiaojing_male": [(5, 55), (254, 55), (254, 303), (301, 311), (301, 447), (352, 457), (352, 576), (237, 598), (237, 640), (225, 646), (225, 768), (5, 768)],
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def check_atlas(path: Path, frame_size: tuple[int, int]) -> dict:
    image = Image.open(path)
    width, height = frame_size
    check(image.mode == "RGBA", f"Not RGBA: {path}")
    check(image.size == (width * 4, height * 4), f"Wrong 4×4 layout: {path}")
    check(set(image.getchannel("A").getdata()) == {0, 255}, f"Non-binary alpha: {path}")
    check(all(a != 0 or (r, g, b) == (0, 0, 0) for r, g, b, a in image.getdata()), f"Dirty transparent RGB: {path}")
    boxes, unique = [], []
    for row in range(4):
        frames = []
        for column in range(4):
            frame = image.crop((column * width, row * height, (column + 1) * width, (row + 1) * height))
            box = frame.getbbox()
            check(box is not None, f"Empty frame: {path} {row}/{column}")
            check(0 < box[0] and box[2] < width and 0 < box[1] and box[3] < height, f"Frame clips border: {path} {row}/{column}")
            check(box[3] == (45 if height == 48 else 90), f"Foot baseline shifted: {path} {row}/{column} {box}")
            boxes.append(list(box))
            frames.append(hashlib.sha256(frame.tobytes()).hexdigest())
        unique.append(len(set(frames)))
        check(unique[-1] == 4, f"Walk frames are not distinct: {path} row {row}")
    return {"size": list(image.size), "frame_size": list(frame_size), "alpha": "binary_0_or_255", "foot_baseline": 45 if height == 48 else 90,
            "frame_boxes": boxes, "distinct_walk_frames_per_direction": unique}


def verify_source(pack: Path) -> tuple[dict, dict, list[dict]]:
    manifest = json.loads((pack / "metadata/asset_manifest.json").read_text())
    animation = json.loads((pack / "metadata/animation_manifest.json").read_text())
    check({c["variant_id"] for c in manifest["characters"]} == set(VARIANTS), "Unexpected character variants")
    check(manifest["linkage"] == {"player_male": "xiaojing_female", "player_female": "xiaojing_male"}, "Unexpected Scheme C pairing")
    checked = []
    for line in (pack / "metadata/SHA256SUMS.txt").read_text().splitlines():
        if not line.strip():
            continue
        digest, name = line.split(None, 1)
        path = pack / name.strip()
        check(path.is_file() and sha(path) == digest, f"Source checksum mismatch: {name}")
        checked.append({"path": name.strip(), "sha256": digest})
    original = Image.open(pack / manifest["source"]["preserved_path"])
    check(sha(pack / manifest["source"]["preserved_path"]) == manifest["source"]["sha256"], "Original mismatch")
    check(sha(pack / manifest["full_reference"]["path"]) == manifest["source"]["sha256"], "Full reference mismatch")
    check(original.size == (1448, 1086) and original.mode == "RGB", "Unexpected original layout")
    check(animation["row_directions"] == list(DIRECTIONS) and animation["walk_fps"] == 6, "Unexpected animation order")
    for character in manifest["characters"]:
        reference = Image.open(pack / character["path"])
        check(reference.size == (character["width"], character["height"]), "Reference size mismatch")
        crop = original.crop(character["crop_box_xyxy_exclusive"])
        check(ImageChops.difference(crop, reference).getbbox() is None, "Reference is not the declared lossless crop")
    return manifest, animation, checked


def ceremony(source: Image.Image, variant: str) -> Image.Image:
    result = source.copy()
    pixels = result.load()
    for row in range(4):
        for column in range(4):
            for y in range(40, 90):
                for x in range(64):
                    at = (column * 64 + x, row * 96 + y)
                    r, g, b, alpha = pixels[at]
                    if not alpha:
                        continue
                    hue, saturation, value = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
                    if variant.startswith("player") and 45 <= hue * 360 <= 145 and saturation > .12:
                        pixels[at] = (round(195 + 48 * value), round(183 + 53 * value), round(150 + 70 * value), alpha)
                    elif variant.startswith("xiaojing") and 15 <= x <= 49 and 190 <= hue * 360 <= 285 and saturation > .40 and value < .75:
                        pixels[at] = (round(r * .88 + 238 * .12), round(g * .88 + 229 * .12), round(b * .88 + 211 * .12), alpha)
            clasp_x = [32, 26, 38, 32][row]
            for dx, dy, color in [(0, 0, (216, 178, 96)), (-1, 0, (238, 210, 144)), (1, 0, (182, 140, 72)), (0, -1, (248, 229, 174)), (0, 1, (216, 178, 96))]:
                at = (column * 64 + clasp_x + dx, row * 96 + 46 + dy)
                if pixels[at][3]:
                    pixels[at] = (*color, 255)
    check(ImageChops.difference(result.getchannel("A"), source.getchannel("A")).getbbox() is None, "Ceremony silhouette changed")
    for row in range(4):
        for column in range(4):
            box = (column * 64, row * 96, (column + 1) * 64, row * 96 + 36)
            check(result.crop(box).tobytes() == source.crop(box).tobytes(), "Ceremony changed face/hair rows")
    return result


def reference_cards(reference: Image.Image, variant: str) -> tuple[Image.Image, Image.Image]:
    portrait = reference.crop(PORTRAITS[variant]).convert("RGBA")
    reference = reference.convert("RGBA")
    paper = reference.crop((18, 55, 42, 79))
    mask = Image.new("L", reference.size, 0)
    ImageDraw.Draw(mask).polygon(STANDING[variant], fill=255)
    # Remove the source column's light decorative rule where it meets the crop,
    # while retaining the dark/purple character silhouette in the same strip.
    if variant in ["player_female", "xiaojing_female"]:
        pixels = reference.load()
        for y in range(reference.height):
            for x in range(19 if variant == "xiaojing_female" else 15):
                r, g, b, _a = pixels[x, y]
                if r > 150 and g > 130 and b > 105 and r >= g >= b:
                    mask.putpixel((x, y), 0)
    reference.putalpha(mask)
    bounds = mask.getbbox()
    piece = reference.crop(bounds)
    standing = Image.new("RGBA", (384, 768))
    for y in range(0, 768, 24):
        for x in range(0, 384, 24):
            standing.paste(paper, (x, y))
    standing.alpha_composite(piece, ((384 - piece.width) // 2, 744 - piece.height))
    # Keep invisible RGB clean, as with the supplied sprite atlases.
    standing.putdata([(r, g, b, a) if a else (0, 0, 0, 0) for r, g, b, a in standing.getdata()])
    return portrait, standing


def write_resource_derivative(path: Path, original: Path) -> None:
    text = original.read_text()
    check("spritesheet.png" in text, f"No atlas path in {original}")
    path.write_text(text.replace("spritesheet.png", "ceremony.png"))


def verify_output() -> dict:
    record = json.loads((OUT / "asset_manifest.json").read_text())
    for name, data in record["files"].items():
        path = OUT / name
        check(path.is_file() and sha(path) == data["sha256"], f"Output mismatch: {name}")
    for variant in VARIANTS:
        for compact, size in [(False, (64, 96)), (True, (32, 48))]:
            directory = OUT / variant / ("compact_32x48" if compact else "")
            check_atlas(directory / "spritesheet.png", size)
            check_atlas(directory / "ceremony.png", size)
            for name in ["sprite_frames.tres", "ceremony_frames.tres"]:
                text = (directory / name).read_text()
                for direction in DIRECTIONS:
                    check(f'&"walk_{direction}"' in text and f'&"idle_{direction}"' in text, "Missing named animation")
                for resource in re.findall(r'path="res://([^\"]+)"', text):
                    check((ROOT / resource).is_file(), "Broken SpriteFrames texture path")
        for name in ["portrait.png", "standing.png", "preview_pixel.png"]:
            image = Image.open(OUT / variant / name)
            check(image.mode == "RGBA" and image.getbbox() is not None, f"Empty UI image {variant}/{name}")
    return record


def run(pack: Path) -> dict:
    manifest, animation, checked = verify_source(pack)
    old = {str(p): sha(p) for p in (ROOT / "assets/characters").glob("*.png")}
    OUT.mkdir(parents=True, exist_ok=True)
    variants = {}
    sources = {}
    for variant in VARIANTS:
        source_dir = pack / "godot_ready/assets/characters/scheme_c" / variant
        target = OUT / variant
        target.mkdir(exist_ok=True)
        (target / "compact_32x48").mkdir(exist_ok=True)
        for relative in ["spritesheet.png", "sprite_frames.tres", "compact_32x48/spritesheet.png", "compact_32x48/sprite_frames.tres"]:
            src = source_dir / relative
            dst = target / relative
            shutil.copyfile(src, dst)
            sources[str(dst.relative_to(OUT))] = {"source": str(src.relative_to(pack)), "source_sha256": sha(src), "operation": "byte_identical_copy"}
        primary = Image.open(target / "spritesheet.png").convert("RGBA")
        compact = Image.open(target / "compact_32x48/spritesheet.png").convert("RGBA")
        check(primary.resize((128, 192), Image.NEAREST).tobytes() == compact.tobytes(), "Compact atlas is not exact nearest-neighbor half size")
        dimensions = check_atlas(target / "compact_32x48/spritesheet.png", (32, 48))
        check_atlas(target / "spritesheet.png", (64, 96))
        reference_entry = next(c for c in manifest["characters"] if c["variant_id"] == variant)
        reference = Image.open(pack / reference_entry["path"])
        portrait, standing = reference_cards(reference, variant)
        portrait.save(target / "portrait.png")
        standing.save(target / "standing.png")
        primary.crop((0, 0, 64, 96)).save(target / "preview_pixel.png")
        formal = ceremony(primary, variant)
        formal.save(target / "ceremony.png")
        formal.resize((128, 192), Image.NEAREST).save(target / "compact_32x48/ceremony.png")
        write_resource_derivative(target / "ceremony_frames.tres", target / "sprite_frames.tres")
        write_resource_derivative(target / "compact_32x48/ceremony_frames.tres", target / "compact_32x48/sprite_frames.tres")
        variants[variant] = {"world_texture": f"res://assets/characters/scheme_c/{variant}/compact_32x48/spritesheet.png",
                             "ceremony_texture": f"res://assets/characters/scheme_c/{variant}/compact_32x48/ceremony.png",
                             "portrait": f"res://assets/characters/scheme_c/{variant}/portrait.png",
                             "standing": f"res://assets/characters/scheme_c/{variant}/standing.png",
                             "compact": dimensions, "portrait_source_box": list(PORTRAITS[variant]),
                             "standing_source_polygon": [list(p) for p in STANDING[variant]],
                             "standing_size": [384, 768], "standing_source": reference_entry["path"],
                             "standing_processing": "opaque_rectangular_reference_card; paper_retained; auxiliary_elements_masked",
                             "ceremony_processing": "light_cream_blue_gold_palette_derivative; original_alpha_and_face_rows_preserved"}
    check(all(sha(Path(p)) == digest for p, digest in old.items()), "Original character files were modified")
    files = {}
    for path in sorted(OUT.rglob("*")):
        if not path.is_file() or path.name.endswith(".import") or path.name == "asset_manifest.json":
            continue
        data = {"sha256": sha(path), "bytes": path.stat().st_size}
        if path.suffix == ".png":
            image = Image.open(path)
            data.update({"size": list(image.size), "mode": image.mode})
        data.update(sources.get(str(path.relative_to(OUT)), {}))
        files[str(path.relative_to(OUT))] = data
    record = {"design_set": "scheme_c", "source": "user_supplied_reference_pack", "source_pack_id": manifest["package_id"], "pairing": manifest["linkage"],
              "source_original_sha256": manifest["source"]["sha256"], "source_sumfile_sha256": sha(pack / "metadata/SHA256SUMS.txt"),
              "source_files_verified": len(checked), "source_checksums": checked, "variants": variants,
              "row_directions": list(DIRECTIONS), "columns": 4, "walk_fps": animation["walk_fps"],
              "idle": "static_first_frame_per_direction", "compact_foot_anchor": [16, 45], "compact_centered_offset": [0, -21],
              "primary_foot_anchor": [32, 90], "primary_centered_offset": [0, -42], "files": files,
              "notes": ["Original pack and six existing character files are not edited.",
                        "Reference-card portraits and standing illustrations retain supplied paper; they are not newly painted transparent illustrations.",
                        "Ceremony sprites are palette derivatives, not complete original wedding-costume animations.",
                        "No breathing animation or tool-specific sprite actions were supplied or invented by this import."]}
    (OUT / "asset_manifest.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
    verify_output()
    return record


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pack", type=Path, default=DEFAULT_PACK)
    parser.add_argument("--verify-output", action="store_true", help="Validate imported assets without needing the private source pack.")
    args = parser.parse_args()
    record = verify_output() if args.verify_output else run(args.pack.resolve())
    print(f"SCHEME C ASSETS: PASS; {len(record['files'])} files, {record['source_files_verified']} source checksums, four variants")
