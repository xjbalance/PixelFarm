"""Import user-supplied Scheme C world art without changing need/.

Only native 32-grid runtime assets are copied. Source art, previews and 2x
duplicates stay in need/. Each imported byte is checked against its manifest.
Seasonal variants are explicitly marked palette derivatives, not supplied art.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path
import zipfile

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/world_scheme_c"
SEASONS = ("spring", "summer", "autumn", "winter")


def seasonal(image: Image.Image, season: int, ground: bool = False) -> Image.Image:
    """Keep pixel locations/alpha; recolor foliage only, never blur or resample."""
    if season == 0:
        return image.copy()
    result = image.copy()
    colors = {}
    for rgba in set(image.getdata()):
        r, g, b, a = rgba
        if not a:
            colors[rgba] = rgba
            continue
        # Olive/sage foliage includes ochre highlights. Brown trunks survive.
        leaf = g > b * 1.13 and g >= r * .86 and (g > r * 1.04 or r - b > 18)
        if not leaf:
            colors[rgba] = rgba
            continue
        light = (r * .28 + g * .57 + b * .15) / 255
        if season == 1:
            rgb = (r * .85, g * .96, b * .87)
        elif season == 2:
            rgb = (61 + light * 158, 47 + light * 118, 35 + light * 60)
        else:
            rgb = (137 + light * 105, 154 + light * 94, 148 + light * 98)
        colors[rgba] = (*[max(0, min(255, round(c))) for c in rgb], a)
    result.putdata([colors[c] for c in image.getdata()])
    return result


def import_assets() -> dict:
    need = ROOT / "need"
    trees = next(need.glob("像素世界_方案C_第1组*/PixelWorld_SchemeC_Trees_Pack"))
    grounds = need / "PixelWorld_SchemeC_Groups_2_to_5"
    archive = zipfile.ZipFile(next(need.glob("*第6至10组*.zip")))
    prefix = "PixelWorld_SchemeC_Groups_6_to_10/"
    packages = [(trees.name, lambda p: (trees / p).read_bytes()),
                (grounds.name, lambda p: (grounds / p).read_bytes()),
                (prefix[:-1], lambda p: archive.read(prefix + p))]
    entries = {}
    copied = []

    def write(path: str, data: bytes, package: str, original: str) -> None:
        target = DEST / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        copied.append(dict(path=path, package=package, original=original,
                           sha256=hashlib.sha256(data).hexdigest()))

    for package, read in packages:
        manifest = json.loads(read("metadata/asset_manifest.json"))
        for item in manifest["assets"]:
            ident = item["id"]
            assert ident not in entries, ident
            original = item["native_path"]
            data = read(original)
            assert hashlib.sha256(data).hexdigest() == item["native_sha256"], original
            path = "sprites/" + ident + ".png"
            write(path, data, package, original)
            image = Image.open(io.BytesIO(data)).convert("RGBA")
            assert list(image.size) == item["native_size"], ident
            entry = dict(id=ident, name=item["name"], group=item.get("group", "01_trees"),
                         path="res://assets/world_scheme_c/" + path,
                         size=item["native_size"], anchor=item["anchor_native"],
                         frames=item.get("frame_count", 1), package=package)
            entries[ident] = entry
            if entry["frames"] > 1:
                for index in range(entry["frames"]):
                    src = f"animations_32/{ident}/frame_{index:02}.png"
                    write(f"animations/{ident}/frame_{index:02}.png", read(src), package, src)
                entry["animation"] = f"res://assets/world_scheme_c/animations/{ident}/sprite_frames.tres"
                refs = "\n".join(f'[ext_resource type="Texture2D" path="res://assets/world_scheme_c/animations/{ident}/frame_{i:02}.png" id="{i+1}"]' for i in range(entry["frames"]))
                frames = ",\n".join('{"duration": 1.0, "texture": ExtResource("%d")}' % (i+1) for i in range(entry["frames"]))
                content = f'[gd_resource type="SpriteFrames" load_steps={entry["frames"]+1} format=3]\n{refs}\n[resource]\nanimations = [{{"frames": [{frames}], "loop": true, "name": &"loop", "speed": 4.0}}]\n'
                (DEST / f"animations/{ident}/sprite_frames.tres").write_text(content)
            seasonal_group = entry["group"] in ("01_trees", "02_grass_flowers", "03_ground_paths")
            if seasonal_group:
                for season, name in enumerate(SEASONS):
                    folder = DEST / "seasons" / name
                    folder.mkdir(parents=True, exist_ok=True)
                    seasonal(image, season, entry["group"] == "03_ground_paths").save(folder / (ident + ".png"))
        if manifest.get("terrain_sets"):
            mapping = json.loads(read("metadata/terrain_mapping.json"))
            (DEST / "terrain_mapping.json").write_text(json.dumps(mapping, ensure_ascii=False, indent=2))
            for item in manifest["terrain_sets"]:
                data = read(item["atlas_32"])
                write("terrain/" + item["id"] + ".png", data, package, item["atlas_32"])
                image = Image.open(io.BytesIO(data)).convert("RGBA")
                for season, name in enumerate(SEASONS):
                    folder = DEST / "seasons" / name / "terrain"
                    folder.mkdir(parents=True, exist_ok=True)
                    seasonal(image, season, True).save(folder / (item["id"] + ".png"))
        for module in manifest.get("repeat_modules", []):
            src = module["native_path"]
            data = read(src)
            write("modules/" + module["id"] + ".png", data, package, src)
            image = Image.open(io.BytesIO(data)).convert("RGBA")
            for season, name in enumerate(SEASONS):
                folder = DEST / "seasons" / name / "modules"
                folder.mkdir(parents=True, exist_ok=True)
                seasonal(image, season).save(folder / (module["id"] + ".png"))
    archive.close()
    result = dict(version=1, grid=32, origin="User supplied need/ Scheme C packs, 2026-10-28",
                  seasonal_derivatives="Palette adaptations made by import_world_scheme_c.py; not supplied seasonal artwork.",
                  assets=entries, copied_files=copied)
    (DEST / "manifest.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    verify()
    return result


def verify() -> None:
    data = json.loads((DEST / "manifest.json").read_text())
    assert len(data["assets"]) == 97
    for item in data["copied_files"]:
        assert hashlib.sha256((DEST / item["path"]).read_bytes()).hexdigest() == item["sha256"], item["path"]
    for item in data["assets"].values():
        assert Image.open(ROOT / item["path"].removeprefix("res://")).size == tuple(item["size"])
    print(f'WORLD SCHEME C: {len(data["assets"])} assets, {len(data["copied_files"])} byte-verified runtime files')


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true", help="Verify installed art without need/")
    args = parser.parse_args()
    if args.verify:
        verify()
    else:
        import_assets()
        # Rebuild the reviewed shared palette as part of a normal reimport,
        # rather than leaving seasonal and non-seasonal art in different styles.
        from brighten_world_assets import main as brighten_world
        brighten_world()
