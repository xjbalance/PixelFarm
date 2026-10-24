"""0.7原创32px春庆种子/铃花/月影纸笺；仅使用Pillow像素几何。"""
from pathlib import Path
from PIL import Image, ImageDraw
R=Path(__file__).resolve().parents[1]
for folder in ['festivals','exploration']:(R/'assets'/folder).mkdir(exist_ok=True)
# Seed packet with stitched green border and a tiny bell-flower label.
im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
d.polygon([(8,5),(24,5),(27,27),(5,27)],fill='#535d49')
d.polygon([(9,7),(23,7),(25,25),(7,25)],fill='#d9c897')
d.rectangle((8,4,24,8),fill='#94aa7a');d.line((9,9,23,9),fill='#b3a879')
d.rectangle((11,12,21,22),fill='#eee5ba');d.line((16,14,16,21),fill='#6e9269',width=2)
d.polygon([(12,13),(13,10),(18,10),(20,14)],fill='#b5a3cb')
d.rectangle((12,14,20,16),fill='#cfc2df');d.rectangle((15,16,17,18),fill='#e2c77f')
im.save(R/'assets/festivals/spring_bloom_seed.png')
# Bloom silhouette: forked curved stem, two hanging bells, jagged paired leaves.
im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
d.line((15,29,16,16,12,9,8,8),fill='#587950',width=2)
d.line((16,18,22,12,24,12),fill='#587950',width=2)
d.polygon([(15,24),(8,19),(6,21),(14,27)],fill='#88a66d')
d.polygon([(16,22),(24,18),(26,20),(17,25)],fill='#a2b77b')
for x,y in [(5,8),(21,12)]:
 d.polygon([(x+1,y),(x+6,y),(x+8,y+7),(x-1,y+7)],fill='#706a92')
 d.polygon([(x+2,y+1),(x+5,y+1),(x+7,y+6),(x,y+6)],fill='#bcb0d7')
 d.rectangle((x,y+7,x+7,y+9),fill='#d9cce4');d.rectangle((x+3,y+9,x+4,y+11),fill='#e1c77f')
im.save(R/'assets/festivals/spring_bloom.png')
# Paper note: folded corner, a moon crescent and broken water reflection lines.
im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
d.polygon([(6,3),(22,3),(27,8),(27,28),(6,28)],fill='#58605b')
d.polygon([(8,5),(21,5),(25,9),(25,26),(8,26)],fill='#ddd6b6')
d.polygon([(21,5),(21,10),(25,10)],fill='#a8b4ab')
d.ellipse((11,7,20,16),fill='#e9db9d');d.ellipse((14,6,22,13),fill='#ddd6b6')
for x1,x2,y in [(10,22,18),(13,20,20),(11,23,23)]:d.line((x1,y,x2,y),fill='#7e9fa6',width=1)
d.rectangle((16,18,18,18),fill='#f0e3ac');d.rectangle((14,20,17,20),fill='#f0e3ac')
im.save(R/'assets/exploration/moon_note.png')
print('Generated original spring_bloom_seed, spring_bloom and moon_note icons')
