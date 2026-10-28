"""Original parchment underlay without baked farm buildings, plots, roads or water.
Runtime cartography draws those from the current editable farm; no saved data is read here.
"""
from pathlib import Path
import random
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[1]
rng = random.Random(80527)
im = Image.new('RGB', (512, 320), '#ead8ae')
d = ImageDraw.Draw(im)
d.rounded_rectangle((7,6,504,313), radius=5, fill='#d8be8c', outline='#72553b', width=2)
d.rounded_rectangle((10,9,501,310), radius=4, fill='#ead8ae', outline='#f7e8c7')
for _ in range(420):
    x,y=rng.randrange(13,499),rng.randrange(12,308)
    d.line((x,y,x+rng.randrange(1,5),y),fill=rng.choice(['#e3cca0','#efdfbc','#e8d4aa']))
for y in (15,303):
    d.line((20,y,491,y),fill='#bb9665'); d.line((20,y+1,491,y+1),fill='#f6e7c6')
for x in (19,491): d.line((x,19,x,299),fill='#bb9665')
d.rectangle((32,24,480,296), fill='#b4bf83', outline='#9ba578', width=2)
for y in range(32,291,19):
    for x in range(40,476,23):
        x2=x+rng.randrange(-4,5);y2=y+rng.randrange(-3,4)
        d.line((x2-2,y2+2,x2,y2-1,x2+1,y2+2),fill='#a4b17d')
for x,y in ((25,24),(486,24),(25,295),(486,295)):
    d.line((x-4,y,x+4,y),fill='#72553b'); d.line((x,y-4,x,y+4),fill='#72553b')
out=ROOT/'assets/maps/farm_editable_base.png'
im.resize((1024,640),Image.NEAREST).save(out)
print(out)
