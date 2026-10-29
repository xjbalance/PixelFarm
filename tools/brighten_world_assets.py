"""Build a coherent bright edition of the supplied Scheme C art, without editing sources."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image

from world_palette import CONFIG_PATH, SEASONS, grade

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/world_scheme_c'
OUT = ART / 'bright'


def main() -> None:
    manifest = json.loads((ART/'manifest.json').read_text())
    outputs = []

    def write(source: Path, destination: Path, ident: str, group: str, season: str = 'spring') -> None:
        original = Image.open(source).convert('RGBA')
        image = grade(original, ident, group, season)
        assert image.size == original.size
        assert image.getchannel('A').tobytes() == original.getchannel('A').tobytes()
        destination.parent.mkdir(parents=True, exist_ok=True)
        image.save(destination)
        outputs.append({'path': destination.relative_to(ROOT).as_posix(),
                        'source': source.relative_to(ROOT).as_posix(),
                        'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                        'sha256': hashlib.sha256(destination.read_bytes()).hexdigest(),
                        'size': list(image.size), 'alpha_preserved': True})

    for ident, info in manifest['assets'].items():
        source = ART/'sprites'/f'{ident}.png'
        write(source, OUT/'sprites'/source.name, ident, info['group'])
        if info['group'] in ('01_trees', '02_grass_flowers', '03_ground_paths'):
            for season in SEASONS:
                write(source, ART/'seasons'/season/source.name, ident, info['group'], season)
        if info['frames'] > 1:
            for frame in range(info['frames']):
                path = Path('animations')/ident/f'frame_{frame:02}.png'
                write(ART/path, OUT/path, ident, info['group'])
            source_frames = ART/'animations'/ident/'sprite_frames.tres'
            frames = source_frames.read_text().replace('res://assets/world_scheme_c/animations/',
                                                       'res://assets/world_scheme_c/bright/animations/')
            (OUT/'animations'/ident/'sprite_frames.tres').write_text(frames)
    for folder in ('terrain', 'modules'):
        for source in sorted((ART/folder).glob('*.png')):
            ident = source.stem
            write(source, OUT/folder/source.name, ident, folder)
            for season in SEASONS:
                write(source, ART/'seasons'/season/folder/source.name, ident, folder, season)
    # A normal rebuild always starts from original supplied PNGs. This avoids
    # cumulative brightening if the tool is run more than once.
    from derive_scheme_c_nature import main as derive_nature
    from derive_scheme_c_buildings import derive as derive_buildings
    derive_nature()
    derive_buildings()
    # Existing indoor furniture without a supplied replacement keeps its exact
    # silhouette. Apply the same palette so those pieces also belong together.
    for source in sorted((ROOT/'assets/housing/interior').glob('*.png')):
        destination = ART/'derived'/('home_'+source.name)
        if source.stem in ('chair_left', 'chair_right', 'plant', 'window', 'window_cottage',
                            'window_estate', 'lamp', 'star_lantern'):
            continue  # These already use the user's supplied furniture above.
        write(source, destination, source.stem, 'interior')
    furniture = json.loads((ROOT/'resources/housing/housing.json').read_text())['furniture']
    for ident, info in furniture.items():
        if ident in ('table', 'chair', 'plant', 'yard_lamp'): continue
        source = ROOT/'assets/housing'/f'{ident}.png'
        preferred = ROOT/'assets/housing/interior'/f'placeable_{ident}.png'
        if info['area'] == 'home' and preferred.exists(): source = preferred
        write(source, ART/'derived'/f'furniture_{ident}.png', ident, 'interior')
    for item in manifest['copied_files']:
        assert hashlib.sha256((ART/item['path']).read_bytes()).hexdigest() == item['sha256'], item['path']
    report = {'version': 1, 'name': '晴光河湾 · 明亮田园',
              'palette': CONFIG_PATH.relative_to(ROOT).as_posix(),
              'source_manifest_unchanged': True, 'original_files_verified': len(manifest['copied_files']),
              'pixel_geometry_unchanged': True, 'runtime_shader': False, 'outputs': outputs}
    (ART/'bright_manifest.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
    print(f'BRIGHT WORLD: {len(outputs)} palette derivatives; {len(manifest["copied_files"])} original files unchanged')


if __name__ == '__main__':
    main()
