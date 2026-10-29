"""Original 32px lake fish silhouettes and implements; deterministic Pillow pixel art.
No external images, palettes sampled only from the project's original farm scenery.
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/aquaculture'
OUT.mkdir(parents=True, exist_ok=True)
SPECIES = ['crucian', 'carp', 'grass', 'perch', 'golden', 'star']
INK = '#294c50'


def fish(species, frame=0):
    im = Image.new('RGBA', (32, 32)); d = ImageDraw.Draw(im)
    # All species share a scale and outline. Geometry and identifying anatomy differ.
    if species == 'crucian':
        # Deep-bodied silver crucian, short round fins, a distinctly tall belly.
        d.polygon([(4,11+frame),(10,14),(13,8),(21,8),(27,13),(28,17),(23,22),(14,22),(10,18),(4,22-frame)], fill=INK)
        d.polygon([(10,15),(14,10),(21,10),(26,14),(25,18),(21,20),(14,20),(10,17)], fill='#b9c9b9')
        d.polygon([(14,9),(16,5),(20,5),(21,9)], fill='#749998')
        d.rectangle((5,14,8,18), fill='#7a9c99'); d.line((13,14,23,14), fill='#e1e3c3')
        d.line((16,18,19,20), fill='#729b98'); d.line((21,11,21,18), fill='#829e98')
    elif species == 'carp':
        # A longer amber body with split tail, long dorsal and two whiskers.
        d.polygon([(2,8),(9,14),(13,9),(22,9),(28,13),(29,18),(23,22),(12,21),(8,18),(2,23),(4,15)], fill=INK)
        d.polygon([(9,15),(14,11),(22,11),(27,14),(27,18),(22,20),(12,19)], fill='#ba9364')
        d.polygon([(13,10),(15,6),(23,8),(23,10)], fill='#c7ab72')
        d.polygon([(3,11),(7,15),(3,20),(5,15)], fill='#aa795d')
        d.line((28,18,30,21), fill='#e7c996'); d.line((27,19,27,23), fill='#e7c996')
        for x,y in [(13,14),(17,13),(21,14),(15,17),(20,17)]: d.rectangle((x,y,x+1,y+1), fill='#dec08a')
    elif species == 'grass':
        # Slender torpedo, pointed head and a small offset dorsal fin.
        d.polygon([(2,10),(9,14),(16,11),(24,12),(30,16),(25,20),(14,20),(9,18),(2,23),(5,16)], fill=INK)
        d.polygon([(9,15),(16,13),(24,14),(28,16),(24,18),(14,18),(9,17)], fill='#91af7b')
        d.polygon([(14,12),(16,7),(20,11)], fill='#638574')
        d.polygon([(17,19),(20,23),(22,19)], fill='#9cbb89')
        d.line((11,15,24,15), fill='#c7d3a1'); d.line((4,13,6,16), fill='#6a9887')
    elif species == 'perch':
        # Two jagged dorsal sections and dark flank bars, large angular mouth.
        d.polygon([(3,10),(9,14),(13,10),(12,6),(16,8),(17,4),(20,8),(22,6),(24,11),(28,14),(27,16),(30,18),(24,21),(13,22),(9,18),(3,22)], fill=INK)
        d.polygon([(10,15),(14,11),(23,12),(27,14),(25,16),(28,18),(23,19),(14,20),(10,17)], fill='#9fb795')
        d.polygon([(13,9),(14,7),(17,10),(18,6),(21,10),(22,8),(24,11)], fill='#6c9f93')
        for x in (13,17,21): d.line((x,12,x+1,19), fill='#4d7b74',width=2)
        d.polygon([(3,13),(7,16),(3,20)], fill='#d2aa77')
        d.polygon([(16,20),(20,24),(22,20)], fill='#d2aa77')
    elif species == 'golden':
        # Fan-tail and long ventral streamers; this is not a golden recolour of carp.
        d.polygon([(1,5),(10,13),(13,10),(22,9),(28,14),(28,19),(23,23),(14,22),(10,19),(1,27),(4,16)], fill=INK)
        d.polygon([(2,8),(9,15),(4,16),(8,18),(2,24),(5,16)], fill='#daa255')
        d.polygon([(11,15),(15,11),(22,11),(26,15),(26,18),(22,21),(15,20),(11,18)], fill='#e7c678')
        d.polygon([(14,11),(15,4),(21,9)], fill='#f3db96')
        d.line((17,20,14,27), fill='#e0b55e',width=2); d.line((21,21,20,27), fill='#e0b55e')
        d.line((15,13,22,13), fill='#fff0b6'); d.rectangle((17,16,19,17), fill='#c79b52')
    else:
        # A translucent ribbon-like star fish with a diamond dorsal and trailing tail.
        d.polygon([(1,9),(9,14),(13,12),(16,12),(19,3),(23,12),(28,14),(30,17),(26,21),(19,21),(15,25),(12,20),(7,20),(1,25),(5,17)], fill=INK)
        d.polygon([(7,16),(14,14),(24,14),(28,17),(25,19),(18,19),(14,22),(12,18),(7,18),(3,22)], fill='#91bfc6')
        d.polygon([(19,6),(21,12),(17,12)], fill='#e1d6ee')
        d.line((2,11,7,16), fill='#b8a9da',width=2); d.line((3,23,10,18), fill='#b8a9da')
        for x,y in [(15,15),(20,17),(23,15)]: d.point((x,y),fill='#fbebaf')
        d.line((17,20,20,25),fill='#b8a9da'); d.point((8,11),fill='#e5dcb7')
    eye_x = 25 if species not in ('grass','star') else 26
    d.rectangle((eye_x,14,eye_x+1,15),fill=INK); d.point((eye_x,14),fill='#f7efcc')
    # Second frame is one-pixel fin cadence. No filtering or new random geometry.
    if frame:
        body = im.copy(); im = Image.new('RGBA',(32,32)); im.alpha_composite(body,(0,-1))
    return im


atlas = Image.new('RGBA',(32*12,32))
for i,species in enumerate(SPECIES):
    adult=fish(species); adult.save(OUT/f'fish_{species}.png')
    for frame in range(2): atlas.alpha_composite(fish(species,frame),(i*64+frame*32,0))
    fry = Image.new('RGBA',(32,32)); d=ImageDraw.Draw(fry)
    d.ellipse((3,3,28,28),fill='#345d63',outline='#8db6ac',width=2)
    fry.alpha_composite(adult.resize((22,22),Image.NEAREST),(5,4))
    d.rectangle((13,25,18,27), fill='#f1ddb0'); fry.save(OUT/f'fry_{species}.png')
atlas.save(OUT/'fish_swim.png')

for name in ['fish_feed','dried_fish','fish_soup']:
    im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
    if name=='fish_feed':
        d.polygon([(8,7),(24,7),(28,27),(4,27)],fill=INK)
        d.polygon([(10,8),(22,8),(26,25),(6,25)],fill='#b69a6c')
        d.rectangle((9,5,23,9),fill='#d4bc8c');d.rectangle((11,13,21,21),fill='#68897b')
        d.polygon([(12,15),(17,14),(20,17),(17,19),(12,18),(10,20),(10,14)],fill='#e2cc96')
    elif name=='dried_fish':
        d.rectangle((3,7,28,9),fill='#8e7257');d.line((8,8,8,12),fill='#e6c792')
        d.line((23,8,23,12),fill='#e6c792'); d.polygon([(8,11),(12,17),(11,24),(8,27),(5,24),(4,17)],fill='#c39b71')
        d.polygon([(23,11),(27,17),(26,24),(23,27),(20,24),(19,17)],fill='#d5b183')
        for x in [8,23]:
            d.line((x,15,x,24),fill='#775b46');d.point((x-2,17),fill=INK)
    else:
        d.rectangle((5,12,27,17),fill='#f0d79d');d.ellipse((4,10,28,20),fill='#d7ad75',outline=INK,width=2)
        d.polygon([(5,17),(9,26),(23,26),(27,17)],fill='#8eaeb0');d.line((9,26,23,26),fill=INK,width=2)
        d.ellipse((8,12,24,18),fill='#d8c98f');d.line((13,14,19,15),fill='#e7e2be',width=2)
        d.line((11,5,10,8),fill='#c8d2bd');d.line((20,3,19,7),fill='#c8d2bd')
    im.save(OUT/f'{name}.png')
print('Generated 16 original lake images (six adult/fry pairs, swim atlas, three supplies).')
