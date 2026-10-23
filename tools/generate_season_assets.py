"""Four seasonal variants of the project's original tiles/tree, drawn in pixel space.
Uses only existing original artwork plus deterministic Pillow geometry. Collisions live
in Godot TileData and are not encoded here. Tile 7 bridge planks remain unchanged.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import random

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/seasons'
OUT.mkdir(parents=True, exist_ok=True)
BASE = Image.open(ROOT/'assets/tilesets/ground.png').convert('RGBA')
TREE = Image.open(ROOT/'assets/tilesets/tree.png').convert('RGBA')
NAMES = ['spring','summer','autumn','winter']


def mix(rgb, target, weight):
    return tuple(round(v*(1-weight)+t*weight) for v,t in zip(rgb[:3],target)) + (rgb[3],)


for season, name in enumerate(NAMES):
    im = BASE.copy()
    for y in range(32):
        for x in range(7*32):
            tile=x//32; px=im.getpixel((x,y))
            if tile<3:
                target=[(141,172,103),(89,135,80),(169,143,84),(201,216,211)][season]
                im.putpixel((x,y),mix(px,target,[.35,.40,.60,.87][season]))
            elif tile in (3,4):
                if season==3: im.putpixel((x,y),mix(px,(178,189,183),.45 if tile==3 else .28))
                elif season==2: im.putpixel((x,y),mix(px,(161,123,80),.18))
            elif tile in (5,6):
                target=[(100,160,151),(72,141,146),(95,142,146),(109,150,167)][season]
                im.putpixel((x,y),mix(px,target,.25))
    d=ImageDraw.Draw(im)
    # Geometry differs too: buds, dense blades, fallen leaves, snow hummocks.
    for tile in range(3):
        rng=random.Random(7000+season*31+tile)
        for i in range(5 if season!=2 else 8):
            x=tile*32+rng.randrange(3,29);y=rng.randrange(4,29)
            if season==0:
                d.line((x,y,x,y-3),fill='#6c9656')
                if i%2==0:
                    d.rectangle((x-1,y-4,x+1,y-3),fill='#e8cdab')
                    d.point((x,y-4),fill='#f2e1b2')
            elif season==1:
                d.line((x-2,y,x,y-4,x+2,y),fill='#497343')
                d.point((x+1,y-3),fill='#9fb778')
            elif season==2:
                color=['#b77a4c','#c6a263','#927444'][i%3]
                d.line((x-2,y,x,y-1,x+2,y),fill=color)
                d.point((x,y+1),fill='#d5b474')
            else:
                d.line((x-2,y,x+2,y),fill='#e5ece3')
                d.line((x-3,y+1,x+3,y+1),fill='#b4c9c9')
        if season==3:
            # Small grass tips above snow preserve the pixel scale.
            d.line((tile*32+9,11,tile*32+10,8),fill='#94a79c')
            d.line((tile*32+21,25,tile*32+23,23),fill='#a6b9aa')
    if season==3:
        # Shore rim/floating pieces are visual only; water remains blocking.
        for tile in (5,6):
            d.line((tile*32+3,6,tile*32+10,6),fill='#d1ded8')
            d.line((tile*32+20,24,tile*32+26,24),fill='#c2d5d4')
    im.save(OUT/f'ground_{name}.png')

    tree=TREE.copy()
    for y in range(tree.height):
        for x in range(tree.width):
            px=tree.getpixel((x,y))
            if px[3] and px[1]>px[0]*.95 and px[1]>px[2]*1.05:
                target=[(119,151,81),(64,108,65),(179,119,64),(137,164,157)][season]
                tree.putpixel((x,y),mix(px,target,[.3,.35,.77,.56][season]))
    d=ImageDraw.Draw(tree)
    if season==0:
        for x,y in [(21,19),(37,30),(17,43),(45,48)]:
            if x<tree.width and y<tree.height and TREE.getpixel((x,y))[3]:
                d.rectangle((x-1,y-1,x+1,y),fill='#e3c3a5')
    elif season==3:
        # Snow sits on the canopy's top exposed pixels, not the trunk/collider.
        for x in range(3,tree.width-3):
            top=next((y for y in range(tree.height-18) if TREE.getpixel((x,y))[3]),None)
            if top is not None:
                for y in range(top,min(top+3+(x%5==0),tree.height)):
                    if TREE.getpixel((x,y))[3]: d.point((x,y),fill='#e3e9de')
        for x,y in [(18,28),(31,38),(43,49)]:
            if x+6<tree.width and y<tree.height and TREE.getpixel((x,y))[3]:
                d.line((x-4,y,x+5,y),fill='#dde5db',width=2)
    tree.save(OUT/f'tree_{name}.png')
print('Generated 8 original seasonal ground/tree variants; bridge tile and pixel dimensions preserved.')
