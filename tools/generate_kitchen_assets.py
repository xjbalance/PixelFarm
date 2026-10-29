"""原创32px厨房食材/料理图标；几何像素绘制，无第三方素材。"""
from pathlib import Path
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/kitchen';OUT.mkdir(exist_ok=True)
INK='#4c5144'; GOLD='#dfc389'; CREAM='#ede2bc'
def draw_item(item):
 im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
 if item=='wild_berry':
  d.line((11,12,21,4),fill='#7d9664',width=2)
  for x,y in [(7,12),(15,15),(18,8),(12,22)]:
   d.rectangle((x,y,x+7,y+7),fill=INK);d.rectangle((x+1,y+1,x+6,y+6),fill='#b16f84');d.point((x+2,y+2),fill='#e8b9b8')
 elif item=='flour':
  d.polygon([(8,8),(22,8),(25,27),(5,27)],fill=INK);d.polygon([(9,10),(21,10),(23,25),(7,25)],fill=CREAM)
  d.rectangle((7,5,23,9),fill='#baa376');d.line((15,13,15,23),fill='#ac8a54',width=2)
  for y in (15,19):d.line((11,y-2,15,y),fill='#ac8a54',width=2);d.line((15,y,19,y-2),fill='#ac8a54',width=2)
 elif item=='cheese':
  d.polygon([(5,23),(6,12),(24,6),(27,24)],fill=INK);d.polygon([(7,13),(23,8),(25,22),(7,22)],fill='#e4c56f')
  for x,y in [(11,15),(20,13),(19,20)]:d.rectangle((x,y,x+2,y+2),fill='#b28d48')
 elif item=='smoked_fish':
  d.polygon([(3,15),(7,9),(13,12),(24,10),(29,16),(25,22),(12,20),(6,24)],fill=INK)
  d.polygon([(8,16),(14,13),(24,12),(27,16),(24,20),(14,18)],fill='#be9871');d.rectangle((24,14,25,15),fill=CREAM)
  d.line((13,13,16,18),fill='#81664d',width=2);d.line((18,12,21,19),fill='#81664d',width=2)
 elif item=='berry_jam':
  d.rectangle((7,9,24,27),fill=INK);d.rectangle((9,11,22,25),fill='#ac788a');d.rectangle((6,5,25,9),fill=GOLD)
  d.rectangle((11,15,20,21),fill=CREAM);d.rectangle((14,17,18,19),fill='#a26476')
 else:
  d.rectangle((4,18,27,22),fill=INK);d.rectangle((7,22,24,27),fill=INK);d.rectangle((7,19,24,22),fill=CREAM);d.rectangle((10,23,21,25),fill=GOLD)
  if item=='carrot_stew':
   d.ellipse((6,10,26,21),fill='#ba8561');d.rectangle((10,13,14,17),fill='#deaa6c');d.rectangle((19,12,23,16),fill='#e6cd8d');d.rectangle((16,17,20,20),fill='#7c9b68')
  elif item=='potato_bread':
   d.rounded_rectangle((6,7,26,21),radius=5,fill='#bc8d57');d.rectangle((8,11,24,17),fill='#dfba76')
   for x in (11,17,23):d.line((x,10,x-3,15),fill='#9c7548',width=2)
  elif item=='egg_meal':
   d.ellipse((6,7,24,21),fill=CREAM);d.ellipse((12,10,20,17),fill='#e1b454');d.rectangle((23,15,26,20),fill='#7f985f')
  elif item=='milk_porridge':
   d.ellipse((6,10,26,20),fill='#e9dbb4')
   for x,y in [(10,12),(17,11),(21,15),(12,17),(17,16)]:d.rectangle((x,y,x+2,y+1),fill='#bca170')
  elif item=='fish_feast':
   d.polygon([(7,10),(11,13),(21,8),(27,13),(23,19),(12,18),(6,21)],fill='#ba9b73')
   d.rectangle((20,11,21,12),fill=CREAM);d.rectangle((8,21,12,23),fill='#d7b45e');d.rectangle((23,21,26,23),fill='#84a274')
 im.save(OUT/(item+'.png'))
for item in ['wild_berry','flour','cheese','smoked_fish','berry_jam','carrot_stew','potato_bread','egg_meal','milk_porridge','fish_feast']:draw_item(item)
print('Generated 10 original kitchen icons')
