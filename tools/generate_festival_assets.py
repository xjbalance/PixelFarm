"""四季节庆原创32px像素纪念品；Pillow几何描画，无外部商业素材。"""
from pathlib import Path
from PIL import Image, ImageDraw
R=Path(__file__).resolve().parents[1]/'assets/festivals';R.mkdir(parents=True,exist_ok=True)
def make():
    im=Image.new('RGBA',(32,32));return im,ImageDraw.Draw(im)
im,d=make();d.polygon([(10,18),(7,30),(14,26),(17,30),(20,18)],fill='#b07969');d.ellipse((7,3,25,22),fill='#6d6a4c');d.ellipse((9,5,23,20),fill='#d4c181')
d.line([(15,8),(15,18)],fill='#697c53',width=2)
for x,y in [(12,9),(17,11),(12,13),(17,15)]:d.ellipse((x,y,x+3,y+3),fill='#8da66b')
im.save(R/'festival_spring_ribbon.png')
im,d=make();d.line([(16,2),(16,7)],fill='#807458',width=2);d.rectangle((7,7,24,24),fill='#536d68');d.rectangle((9,8,22,22),fill='#e3ca88');d.rectangle((7,6,24,9),fill='#8b7959');d.rectangle((8,23,23,25),fill='#8b7959');d.line([(16,10),(16,21)],fill='#b69b6e',width=1);d.line([(16,25),(16,29)],fill='#c8ad78',width=2);d.rectangle((13,28,19,30),fill='#c8ad78');im.save(R/'festival_summer_lantern.png')
im,d=make();d.arc((5,2,26,24),180,360,fill='#837256',width=3);d.rectangle((3,15,28,28),fill='#715d45');d.rectangle((5,16,26,26),fill='#c3a375')
for y in [18,22,26]:d.line([(5,y),(26,y)],fill='#9e815e',width=1)
d.ellipse((6,9,14,17),fill='#b67a55');d.ellipse((15,10,25,18),fill='#88a272');d.polygon([(10,15),(11,7),(13,9),(13,15)],fill='#a8b380');im.save(R/'festival_autumn_basket.png')
im,d=make();d.line([(16,1),(16,7)],fill='#b0c7c4',width=1);d.polygon([(16,5),(19,12),(27,12),(21,18),(23,27),(16,22),(9,27),(11,18),(5,12),(13,12)],fill='#557b83');d.polygon([(16,8),(18,14),(24,14),(19,18),(20,24),(16,21),(12,24),(13,18),(8,14),(14,14)],fill='#e2d9b2');im.save(R/'festival_winter_star.png')
im,d=make();d.ellipse((4,4,28,28),outline='#6c8f61',width=5)
for x,y in [(7,6),(18,5),(23,14),(18,24),(6,20)]:d.rectangle((x,y,x+4,y+4),fill='#e7b7a3');d.rectangle((x+1,y+1,x+3,y+3),fill='#e6d2a0')
im.save(R/'shop_spring_wreath.png')
im,d=make();d.line([(5,3),(5,30)],fill='#796c50',width=3);d.polygon([(7,4),(28,7),(24,14),(28,21),(7,18)],fill='#7eb0b2');d.polygon([(7,4),(17,5),(17,19),(7,18)],fill='#d1b67c');d.line([(9,9),(24,12)],fill='#eddfac',width=2);im.save(R/'shop_summer_flag.png')
im,d=make();d.rectangle((3,3,29,29),fill='#6c867e');d.rectangle((5,5,27,27),fill='#b2cbc8');d.line([(16,5),(16,27)],fill='#e0d3ae',width=2);d.line([(5,16),(27,16)],fill='#e0d3ae',width=2);d.polygon([(16,8),(18,13),(24,16),(18,19),(16,24),(13,19),(8,16),(13,13)],fill='#f0e1ac');im.save(R/'shop_winter_window.png')
