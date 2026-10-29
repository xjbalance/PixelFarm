"""Refine the project's own pixel sprites into one warm pastoral material family.

Inputs are committed project-original sources, not downloaded game assets. Every
output preserves the complete original alpha channel, dimensions and animation
frame layout. No actor pivot, collision, gameplay or scene position is changed.
"""
from pathlib import Path
import colorsys
import hashlib
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'tools/art_sources/style07'

PALETTE = {
    'e9b984': 'e5b98c', 'e3ae7c': 'dba77c', 'e8b98c': 'e5b98c',
    'c98c6b': 'bb8868', 'f0d19e': 'efd0a3',
    'dfbd70': 'c7ab72', 'f1d38c': 'e0c390', 'f7dfa0': 'f0d9aa', 'ae8551': '9d8055',
    'cc754d': 'ae7d5f', '4b6b70': '718269', '677b70': '61735d', '8b9b88': 'a4ad87',
    '344c59': '4f5b53', '483a36': '514237', '4a383a': '554539', '574038': '63503f',
    '76568b': '8f8297', '9480a8': 'a595ad', 'beabd0': 'c6b7cc', 'd1c58b': 'e0cfaa',
    '527d83': '68817b', '4e4d48': '555043', 'ab7657': 'ad8164', 'c7c3ae': 'd1c6aa',
    'b9a67c': 'cab48a', '4d424c': '5a4b4d', '668c91': '78948d', 'b6c98e': 'acbd8c',
    'e7e5d3': 'f0e6cd', 'c4c9bc': 'cecdb6', 'e2c985': 'd9bd80', 'b77b72': 'bb8d79',
}

def rgb(value):
    return tuple(int(value[i:i+2], 16) for i in (0, 2, 4))

def warm_material(color):
    """Small bounded palette adjustment, not a screen-wide tint or blur."""
    r, g, b = color
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    s *= .84
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return tuple(max(0, min(255, round(c * 255 + shift))) for c, shift in zip((r,g,b), (3,2,0)))

def person(original, name):
    out = original.copy()
    src = original.load(); px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r,g,b,a = src[x,y]
            if not a:
                continue
            key = f'{r:02x}{g:02x}{b:02x}'
            new = rgb(PALETTE[key]) if key in PALETTE else (r,g,b)
            # Keep eyes and tiny accessories crisp. Clothing/headwear receives
            # the same upper-left light as trees, roofs and interior furniture.
            local_x, local_y = x % 32, y % 48
            if a == 255 and key not in ['303836','35413c'] and 10 <= local_y <= 37:
                lift = 5 if local_x < 16 else -3
                new = tuple(max(0,min(255,c+lift)) for c in new)
            px[x,y] = (*new,a)
    d = ImageDraw.Draw(out)
    for oy in range(0,out.height,48):
        for ox in range(0,out.width,32):
            # Small stitched cloth accents occupy existing opaque clothing only.
            for x,y in [(12,26),(12,30),(20,32)]:
                old = src[ox+x,oy+y]
                if old[3] == 255 and old[:3] not in [rgb('e9b984'),rgb('e3ae7c'),rgb('e8b98c')]:
                    shade = '#a6b08f' if name in ['player','zhou'] else '#e2d1ad'
                    d.rectangle((ox+x,oy+y,ox+x+1,oy+y+1),fill=shade)
    return out

def building(original, name):
    out = original.copy(); src = original.load(); px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r,g,b,a = src[x,y]
            if not a: continue
            new = warm_material((r,g,b))
            # Cream plaster and warm oak connect old village structures to the
            # existing farmhouse; saturated glass and roof bands become softer.
            if a == 255 and 58 <= y <= 137 and r > 175 and r > g > b and g-b > 27:
                new = tuple(round(c*.4+t*.6) for c,t in zip(new,(223,205,164)))
            px[x,y] = (*new,a)
    d=ImageDraw.Draw(out)
    if name == 'market':
        for x in range(18,112,28):
            d.line((x,12,x-7,35),fill='#c7d0aa',width=2)
        for y in [67,75]:
            d.line((18,y,111,y),fill='#856a4e',width=2)
        for x in [34,70,99]:
            d.line((x,66,x+12,66),fill='#d8b98a',width=2)
        for x in [29,58,88]:
            d.line((x,49,x+10,49),fill='#f0dfb9',width=2)
    else:
        # Existing roof courses and plank edges gain sparse material detail,
        # never new protrusions, chimneys, entrances or collision silhouettes.
        for y in range(25,65,10):
            half=max(0,int((y-8)*1.48))
            for x in range(max(10,96-half+8),min(out.width-10,96+half-4),25):
                if src[x,y][3]==255:
                    c=out.getpixel((x,y));shade=tuple(max(0,v-13) for v in c[:3])
                    d.line((x,y,x+2,y+3),fill=(*shade,255),width=2)
        for x in [31,155]:
            if x < out.width:
                d.line((x,86,x,111),fill='#b99a70',width=2)
                d.line((x+2,89,x+2,107),fill='#ecd8ad',width=2)
        for x in [47,137]:
            if x+7 < out.width:
                d.line((x,94,x+7,94),fill='#e9e3bd',width=2)
    return out

def main():
    sources=json.loads((SOURCE/'sources.json').read_text())
    report={'baseline':sources['baseline'],'direction':'warm oak / cream / moss, upper-left light','assets':{}}
    for path, expected in sources['files'].items():
        base=SOURCE/path.removeprefix('assets/')
        assert hashlib.sha256(base.read_bytes()).hexdigest()==expected,path
        original=Image.open(base).convert('RGBA')
        output=person(original,base.stem) if '/characters/' in path else building(original,base.stem)
        # Exact alpha/pivot conservation is a production invariant, including
        # the old contact shadow and single-pixel wedding dress details.
        output.putalpha(original.getchannel('A'))
        assert output.size==original.size and output.getchannel('A').tobytes()==original.getchannel('A').tobytes()
        output.save(ROOT/path)
        report['assets'][path]={'size':list(output.size),'alpha_sha256':hashlib.sha256(output.getchannel('A').tobytes()).hexdigest(),
                                'sha256':hashlib.sha256((ROOT/path).read_bytes()).hexdigest()}
    target=ROOT/'resources/ui/world_style07.json'
    target.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print('Coordinated original-world sprites:',len(report['assets']))

if __name__=='__main__': main()
