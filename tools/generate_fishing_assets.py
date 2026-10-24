"""原创32px鱼竿、饵、稳流钩与永恒星鲤。只使用Pillow几何像素，不引用外部商业素材。"""
from pathlib import Path
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/fishing'
OUT.mkdir(parents=True,exist_ok=True)
def image():
    im=Image.new('RGBA',(32,32));return im,ImageDraw.Draw(im)
im,d=image()
d.line([(6,28),(20,5),(24,3)],fill='#443f38',width=4)
d.line([(6,28),(20,5),(24,3)],fill='#c5a273',width=2)
d.rectangle((4,23,9,28),fill='#71533c');d.rectangle((7,19,13,24),fill='#677f77')
d.line([(24,4),(27,14),(25,23)],fill='#d3dfd2',width=1);d.rectangle((23,22,27,25),fill='#c9755f')
im.save(OUT/'fishing_rod.png')
im,d=image()
d.rectangle((7,12,24,28),fill='#675e43');d.rectangle((8,10,23,25),fill='#bda778')
d.rectangle((10,9,21,12),fill='#dac38c');d.line([(11,19),(14,15),(18,20),(21,16)],fill='#ad6758',width=3)
d.line([(12,19),(15,16),(18,21),(21,17)],fill='#d2946f',width=1)
im.save(OUT/'fishing_bait.png')
im,d=image()
d.line([(19,6),(19,19),(16,25),(10,26),(6,22),(6,17)],fill='#3d4b48',width=4)
d.line([(19,6),(19,19),(16,25),(10,26),(6,22),(6,17)],fill='#b7c5bc',width=2)
d.ellipse((16,2,22,8),outline='#dbe0c7',width=2);d.polygon([(4,18),(8,16),(8,21)],fill='#dbe0c7')
im.save(OUT/'fishing_hook.png')
im,d=image()
d.polygon([(3,14),(8,9),(17,7),(25,11),(28,15),(24,21),(14,24),(7,21)],fill='#37595f')
d.polygon([(5,14),(10,10),(17,9),(24,12),(26,15),(22,20),(14,22),(8,19)],fill='#d2ded4')
d.polygon([(5,14),(1,9),(1,20),(6,17)],fill='#82b7b7');d.polygon([(11,10),(16,3),(19,9)],fill='#a4caca')
d.polygon([(13,21),(18,28),(21,21)],fill='#80b8ba');d.line([(6,14),(1,4)],fill='#e4ce89',width=1)
d.line([(6,18),(1,29)],fill='#e4ce89',width=1);d.rectangle((23,13,25,15),fill='#2c4647')
for x,y in [(10,13),(15,11),(19,15),(13,18),(20,19)]:
    d.line([(x-1,y),(x+1,y)],fill='#ddba6f');d.line([(x,y-1),(x,y+1)],fill='#f2dda2')
im.save(OUT/'fish_eternal.png')
