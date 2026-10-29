"""Shared offline colour treatment; original need/ and copied source art stay intact."""
from __future__ import annotations

import colorsys
import json
from functools import lru_cache
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / 'resources/presentation/world_palette.json'
CONFIG = json.loads(CONFIG_PATH.read_text())
SEASONS = ('spring', 'summer', 'autumn', 'winter')


@lru_cache(maxsize=1)
def palette() -> Image.Image:
    colours = [tuple(bytes.fromhex(colour))
               for ramp in CONFIG['ramps'].values() for colour in ramp]
    result = Image.new('P', (1, 1))
    result.putpalette([channel for rgb in colours + [colours[-1]] * (256-len(colours))
                       for channel in rgb])
    return result


def harmonize(image: Image.Image) -> Image.Image:
    result = image.convert('RGB').quantize(palette=palette(), dither=Image.NONE).convert('RGB')
    result.putalpha(image.getchannel('A'))
    return result


def grade(image: Image.Image, ident: str, group: str = '', season: str = 'spring') -> Image.Image:
    """Change colours only, preserving original alpha and native pixel dimensions."""
    image = image.convert('RGBA')
    natural = group in ('01_trees', '02_grass_flowers', '03_ground_paths', 'terrain', 'modules')
    flower = 'flower' in ident or ident in ('sunflower', 'water_lily')
    foliage = CONFIG['foliage'][season]
    colours = {}
    # Constrain the extreme high-frequency texture of the ground. All connected
    # tiles receive the same colour transform, including their grass transitions.
    ground = ident == 'grass'
    for rgba in set(image.getdata()):
        r, g, b, a = rgba
        if not a:
            colours[rgba] = rgba
            continue
        hue, light, saturation = colorsys.rgb_to_hls(r/255, g/255, b/255)
        degrees = hue*360
        is_leaf = (45 <= degrees <= 157 and g >= r*.82 and g > b*1.09
                   and saturation > .14 and (natural or degrees >= 68))
        if flower and degrees < 65:
            is_leaf = False  # Keep yellow petals and gold details distinct.
        if is_leaf:
            hue = (foliage['hue'] + (degrees-65)*foliage['hue_spread'])/360
            saturation = foliage['saturation']
            light = foliage['light_base'] + light*foliage['light_scale']
            if ground:
                centre = foliage['light_base'] + .44*foliage['light_scale']
                light = centre + (light-centre)*.58
        else:
            lift = CONFIG['water_lift'] if 160 <= degrees <= 225 else CONFIG['midtone_lift']
            light += lift*4*light*(1-light)
            # Water stays clear cyan rather than olive-grey; shared wood and
            # cream ramps provide the same warmth on props and buildings.
            if 160 <= degrees <= 225 and saturation > .12:
                hue = (degrees*.65+194*.35)/360
                saturation = max(.30, saturation)
            else:
                saturation = min(.76, saturation*1.03)
        rgb = tuple(round(max(0, min(1, channel))*255)
                    for channel in colorsys.hls_to_rgb(hue, min(.97, light), saturation))
        if is_leaf and (ground or group in ('03_ground_paths', 'terrain')):
            # Use the same ground ramp on standalone grass and the grass side
            # of every connected tile. In particular, summer must not straddle
            # two distant greens and become a repeating camouflage pattern.
            base = tuple(bytes.fromhex(CONFIG['ground_colours'][season]))
            shade = (r*.28+g*.57+b*.15-132)*.13
            rgb = tuple(round(max(0, min(255, channel+shade))) for channel in base)
        if not is_leaf and ident in ('dirt_path', 'dirt'):
            # Recess broad ground planes behind detailed objects. Preserve the
            # source pebble locations with much quieter contrast, rather than
            # turning the original fine noise into conspicuous colour patches.
            base = (215, 189, 141) if ident == 'dirt_path' else (195, 159, 112)
            shade = (r*.28+g*.57+b*.15-155)*.30
            rgb = tuple(round(max(0, min(255, channel+shade))) for channel in base)
        colours[rgba] = (*rgb, a)
    result = image.copy()
    result.putdata([colours[pixel] for pixel in image.getdata()])
    # No dithering: a common limited palette quiets the photographic speckling
    # without blurring a sprite or introducing a second apparent pixel scale.
    rgb = harmonize(result).convert('RGB')
    if ident in ('grass', 'dirt_path', 'dirt', 'sand'):
        # Treat each native tile independently so standalone tiles and their
        # 47-pattern atlas versions receive the same spatial treatment.
        for y in range(0, image.height, 32):
            for x in range(0, image.width, 32):
                bounds = (x, y, min(x+32, image.width), min(y+32, image.height))
                rgb.paste(rgb.crop(bounds).filter(ImageFilter.ModeFilter(3)), bounds[:2])
    rgb.putalpha(image.getchannel('A'))
    return rgb
