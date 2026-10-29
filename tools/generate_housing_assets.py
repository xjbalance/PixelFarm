"""Original grid furniture pixel art. No commercial assets or generated stock art."""
from pathlib import Path
from PIL import Image, ImageDraw
import json
R=Path(__file__).resolve().parents[1]
D=R/'assets/housing';D.mkdir(parents=True,exist_ok=True)
data=json.loads((R/'resources/housing/housing.json').read_text())
for key,entry in data['furniture'].items():
 w,h=[x*32 for x in entry['size']];im=Image.new('RGBA',(w,h));d=ImageDraw.Draw(im)
 if key=='bed':
  d.rectangle((3,2,w-4,h-2),fill='#6a5646');d.rectangle((6,7,w-7,h-8),fill='#c7b78c');d.rectangle((8,10,w-9,22),fill='#e5dab5');d.rectangle((6,26,w-7,h-8),fill='#77928b')
  for y in range(28,h-9,8):d.line((7,y,w-8,y),fill='#a9bbb0',width=2)
 elif key in ['table','spouse_desk']:
  d.rectangle((5,h-9,9,h-2),fill='#655343');d.rectangle((w-10,h-9,w-6,h-2),fill='#655343');d.rectangle((1,5,w-2,h-8),fill='#7c6247');d.rectangle((3,3,w-4,h-11),fill='#b49a70')
  if key=='spouse_desk':
   d.rectangle((9,8,28,19),fill='#d4cfad');d.line((12,12,23,12),fill='#789484');d.ellipse((40,8,49,17),fill='#87b7b0');d.rectangle((43,6,47,10),fill='#d9d7b2')
 elif key=='chair':
  d.rectangle((7,3,25,18),fill='#7d634a');d.rectangle((10,6,22,14),fill='#af9671');d.rectangle((5,17,27,23),fill='#baa17a');d.rectangle((7,23,11,29),fill='#716046');d.rectangle((22,23,26,29),fill='#716046')
 elif key=='cabinet':
  d.rectangle((4,4,28,29),fill='#6e5e48');d.rectangle((6,6,26,26),fill='#ac956d');d.line((16,7,16,25),fill='#75634a',width=2);d.rectangle((12,14,14,17),fill='#dbc48d');d.rectangle((18,14,20,17),fill='#dbc48d')
 elif key=='rug':
  d.rectangle((1,1,w-2,h-2),fill='#8a6e64');d.rectangle((4,4,w-5,h-5),fill='#c6ad7c');d.rectangle((7,7,w-8,h-8),fill='#9c8e6b')
  for x in range(11,w-8,10):d.line((x,12,x+3,h-13),fill='#d8caa0',width=2)
 elif key in ['lamp','yard_lamp']:
  d.rectangle((14,12,18,29),fill='#786047');d.rectangle((8,28,24,30),fill='#8b7754');d.rectangle((6,4,26,16),fill='#b89b6d');d.rectangle((8,6,24,14),fill='#ead69e');d.rectangle((11,7,14,13),fill='#f3e2ad')
 elif key in ['plant','flower']:
  d.rectangle((9,19,24,30),fill='#8d7354');d.rectangle((7,18,26,22),fill='#b49a71')
  for x,y in [(8,11),(16,5),(23,10),(13,15)]:
   d.line((17,23,x,y),fill='#577852',width=2);d.rectangle((x-4,y-3,x+3,y+2),fill='#88a36d')
  if key=='flower':
   for x,y in [(8,10),(17,5),(24,11)]:d.rectangle((x-2,y-3,x+2,y+1),fill='#dec19a')
 elif key=='road':
  d.rectangle((2,5,17,15),fill='#a1a58d');d.rectangle((15,16,29,28),fill='#8e9684');d.line((4,6,16,6),fill='#c0bfa1');d.line((17,17,28,17),fill='#b4b69c')
 elif key=='water_basin':
  d.ellipse((3,12,29,29),fill='#7b8273');d.ellipse((3,5,29,23),fill='#b1b6a2');d.ellipse((6,8,26,20),fill='#78a7a5');d.line((10,12,22,12),fill='#c6d4bd',width=2)
 elif key=='wallpaper':
  d.rectangle((3,2,29,30),fill='#b9b997')
  for x in [8,19]:d.line((x,5,x+5,27),fill='#6f9170',width=2);d.line((x+2,13,x+7,8),fill='#dbd3a5',width=2)
 elif key=='floor':
  d.rectangle((2,2,30,30),fill='#bea376')
  for y in [8,16,24]:d.line((3,y,29,y),fill='#8b7658',width=1)
  for x in [9,23]:d.line((x,3,x,29),fill='#a58b63',width=1)
 im.save(D/f'{key}.png')
original=Image.open(R/'assets/tilesets/ground.png').convert('RGBA');pixels=original.load()
for y in range(32):
 for x in range(224,256):
  pixels[x,y]=((169,145,105,255) if y%8==0 or (x+(16 if y//8%2 else 0))%32==0 else (193,167,126,255))
original.save(D/'floor_texture.png')
print('Generated 14 original furniture icons and floor texture.')
