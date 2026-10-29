"""Fit supplied Scheme C art to existing entrances; never edit original PNGs."""
from pathlib import Path
import json
from PIL import Image, ImageDraw
from world_palette import harmonize

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/world_scheme_c'
OUT = ART / 'derived'


def source(ident):
    path = ART / 'bright' / 'sprites' / (ident + '.png')
    if not path.exists(): path = ART / 'sprites' / (ident + '.png')
    return Image.open(path).convert('RGBA')


def recolor_roof(im, level):
    result = im.copy()
    px = result.load()
    for y in range(120):
        for x in range(result.width):
            r, g, b, a = px[x, y]
            if a and r > g * 1.28 and g > b * 1.14:
                if level == 2: px[x, y] = (int(r*.97), min(255,int(g*1.06)), min(255,int(b*1.12)), a)
                if level == 3: px[x, y] = (int(r*.78), min(255,int(g*1.08)), min(255,int(b*1.2)), a)
                if level == 4: px[x, y] = (int(r*.68), min(255,int(g*.94)), min(255,int(b*1.43)), a)
    return result


def derive():
    OUT.mkdir(parents=True, exist_ok=True)
    for level in range(1, 5):
        house = Image.new('RGBA', (192, 168))
        house.alpha_composite(recolor_roof(source('farmhouse'), level), (16, 8))
        # Same 192x168 canvas, centered door and existing physical shell.
        # The supplied pack has ONE house; higher tiers are explicit variants.
        draw = ImageDraw.Draw(house)
        if level >= 2:
            for x in (7, 164):
                house.alpha_composite(source('flower_pot'), (x, 132))
        if level >= 3:
            for x in (17, 160):
                draw.rectangle((x, 99, x+3, 143), fill='#69533b')
                for y in range(98, 140, 9):
                    draw.rectangle((x-3, y, x+6, y+4), fill='#79916a')
            house.alpha_composite(source('flower_basket'), (20, 97))
        if level >= 4:
            star = source('moon_lamp').resize((16, 28), Image.NEAREST)
            house.alpha_composite(star, (144, 111))
            for x, y in ((87, 46), (93, 43), (99, 46)):
                draw.rectangle((x, y, x+2, y+2), fill='#e7c78b')
        harmonize(house).save(OUT / f'exterior_{level}.png')
    for ident, filename, size, color in (
        ('farmhouse', 'tea_house', (192,168), '#6e8c69'),
        ('tool_shed', 'workshop', (192,168), '#ac7754'),
        ('market_stall', 'market', (136,96), None),
    ):
        image = Image.new('RGBA', size)
        art = source(ident)
        if ident == 'tool_shed':
            art = art.resize((160,144), Image.NEAREST)
        if ident == 'market_stall':
            art = art.resize((112,88), Image.NEAREST)
        if color:
            pixels = art.load()
            base = tuple(bytes.fromhex(color[1:]))
            for y in range(art.height):
                for x in range(art.width):
                    r,g,b,a=pixels[x,y]
                    if a and r>g*1.28 and g>b*1.14 and y<art.height*.72:
                        light=(r*.3+g*.5+b*.2)/140
                        pixels[x,y]=(*[min(255,round(v*light)) for v in base],a)
        image.alpha_composite(art, ((size[0]-art.width)//2, size[1]-art.height))
        harmonize(image).save(OUT / (filename+'.png'))
    # Preserve the original built-in furniture canvases so the placement preview,
    # final drawing, Y sort and old saved cell offsets agree exactly.
    for ident, supplied in {
        'chair_left':'wood_chair', 'chair_right':'wood_chair', 'plant':'flower_pot',
        'window':'window_open', 'window_cottage':'window_open', 'window_estate':'window_open',
        'lamp':'lantern', 'star_lantern':'star_lamp',
    }.items():
        size=Image.open(ROOT/'assets/housing/interior'/(ident+'.png')).size
        canvas=Image.new('RGBA',size)
        art=source(supplied)
        ratio=min(1,size[0]/art.width,size[1]/art.height)
        if ratio<1: art=art.resize((round(art.width*ratio),round(art.height*ratio)),Image.NEAREST)
        canvas.alpha_composite(art,((size[0]-art.width)//2,size[1]-art.height))
        harmonize(canvas).save(OUT/('home_'+ident+'.png'))
    for kind, supplied in {'table':'square_table','chair':'wood_chair','plant':'flower_pot','yard_lamp':'street_lamp'}.items():
        canvas=Image.new('RGBA',{'table':(64,32)}.get(kind,(32,32)))
        art=source(supplied)
        # Tall courtyard lamps keep their full visible height above the cell.
        if kind=='yard_lamp': canvas=Image.new('RGBA',(32,64))
        canvas.alpha_composite(art,((canvas.width-art.width)//2,canvas.height-art.height))
        harmonize(canvas).save(OUT/('furniture_'+kind+'.png'))
    (OUT/'building_sources.json').write_text(json.dumps({
        'source': 'User-supplied native32 Scheme C farmhouse, tool_shed, market_stall, flower_pot, flower_basket, moon_lamp',
        'processing': 'Nearest-neighbor fitting, palette variants and existing-art composites; no AI generation in this integration.',
        'house_levels': 'One supplied house, four derived tiers; not four distinct supplied architectures.',
        'entrances': 'Original game positions, collision shapes and interior levels unchanged.'
    }, ensure_ascii=False, indent=2)+'\n')


if __name__ == '__main__':
    derive()
