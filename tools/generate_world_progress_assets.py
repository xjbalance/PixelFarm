"""World development sign original pixel emblem."""
from pathlib import Path
from PIL import Image,ImageDraw
p=Path(__file__).resolve().parents[1]/'assets/world_progress';p.mkdir(parents=True,exist_ok=True)
im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
d.rectangle((2,3,29,29),fill='#596950');d.rectangle((4,5,27,27),fill='#c9ba87')
d.rectangle((5,21,26,24),fill='#749b9a');d.line([(7,16),(13,21),(24,21),(27,16)],fill='#7f684a',width=2)
d.line([(17,7),(17,19)],fill='#725e45',width=2);d.polygon([(18,7),(25,14),(18,14)],fill='#8fa076')
d.rectangle((6,7,9,17),fill='#776c4f');d.rectangle((4,6,11,8),fill='#776c4f');d.rectangle((5,8,10,13),fill='#e4cb86')
im.save(p/'development_sign.png')
