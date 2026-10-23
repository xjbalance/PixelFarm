"""Extend the project's original 16px character palette; no external artwork."""
from pathlib import Path
from PIL import Image, ImageDraw
root = Path(__file__).resolve().parents[1]
im = Image.new('RGBA', (16,24))
p = ImageDraw.Draw(im)
p.ellipse((3,20,13,23),fill='#304b4248')
p.rectangle((5,17,7,22),fill='#344c59');p.rectangle((10,17,12,22),fill='#344c59')
p.rectangle((4,21,7,22),fill='#483a36');p.rectangle((10,21,13,22),fill='#483a36')
p.rectangle((3,10,13,17),fill='#668c91');p.rectangle((6,11,10,18),fill='#d1c59e')
p.rectangle((3,13,4,17),fill='#e8b98c');p.rectangle((12,13,13,17),fill='#e8b98c')
p.rectangle((4,2,12,11),fill='#4d424c');p.rectangle((5,5,12,11),fill='#e8b98c')
p.rectangle((4,2,12,6),fill='#4d424c');p.rectangle((4,5,5,12),fill='#4d424c')
p.rectangle((12,6,13,14),fill='#4d424c');p.rectangle((11,3,13,4),fill='#b6c98e')
p.point((7,8),fill='#35413c');p.point((11,8),fill='#35413c');p.point((9,10),fill='#b77b72')
p.rectangle((3,16,6,19),fill='#a4825e');p.line((4,16,5,13),fill='#d9bc8a')
im.resize((32,48),Image.NEAREST).save(root/'assets/characters/xiaojing.png')
print('Original Xiaojing sprite generated.')
