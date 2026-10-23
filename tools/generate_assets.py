"""原生几何绘制的原创像素素材。仅重新生成素材时需要 Pillow，游戏无 Python 依赖。"""
from pathlib import Path
from PIL import Image, ImageDraw
import math
import random
import wave
import struct

ROOT = Path(__file__).resolve().parents[1]
random.seed(81)

def canvas(w, h):
    image = Image.new('RGBA', (w, h))
    return image, ImageDraw.Draw(image)

def save(image, name, scale=2):
    path = ROOT / 'assets' / name
    path.parent.mkdir(parents=True, exist_ok=True)
    image.resize((image.width*scale, image.height*scale), Image.NEAREST).save(path)

# 八种 16px 地块放入单行图集，导出为 32px TileMapLayer 图块。
atlas, pen = canvas(128, 16)
colors = ['#86ad60', '#81a65b', '#8cb367', '#d4ba80', '#ba9662', '#569ca7', '#3b758b', '#82654d']
for tile, color in enumerate(colors):
    x = tile*16
    pen.rectangle((x, 0, x+15, 15), fill=color)
    for _ in range(8):
        px, py = x+random.randrange(15), random.randrange(15)
        ink = ['#97ba6d', '#6d9555'][random.randrange(2)] if tile < 3 else ('#e0c894' if tile in (3, 4) else '#70b4b9')
        if tile == 7: ink = '#927659'
        pen.line((px, py, px+1, py), fill=ink)
    if tile in (5, 6):
        pen.line((x+3, 5, x+8, 5), fill='#95c8bb')
        pen.line((x+9, 12, x+13, 12), fill='#82bbb7')
save(atlas, 'tilesets/ground.png')

def person(npc=False):
    sheet, _ = canvas(64, 96)
    for row in range(4):
        for frame in range(4):
            im, d = canvas(16, 24)
            step = [0, 1, 0, -1][frame]
            d.ellipse((3, 20, 13, 23), fill='#304b4248')
            d.rectangle((5, 17, 7, 21+max(step,0)), fill='#344c59')
            d.rectangle((9, 17, 11, 21+max(-step,0)), fill='#344c59')
            d.rectangle((4, 21+max(step,0), 7, 22+max(step,0)), fill='#483a36')
            d.rectangle((9, 21+max(-step,0), 12, 22+max(-step,0)), fill='#483a36')
            d.rectangle((4, 11, 12, 17), fill='#76568b' if npc else '#cc754d')
            d.rectangle((6, 12, 10, 18), fill='#d1c58b' if npc else '#4b6b70')
            d.rectangle((3, 13+max(step,0), 4, 17+max(step,0)), fill='#e3ae7c')
            d.rectangle((12, 13+max(-step,0), 13, 17+max(-step,0)), fill='#e3ae7c')
            d.rectangle((5, 5, 12, 11), fill='#e9b984')
            d.rectangle((4, 4, 12, 6), fill='#4a383a')
            d.rectangle((4, 6, 5, 9), fill='#4a383a')
            if row == 3:
                d.rectangle((5, 6, 12, 10), fill='#574038')
            elif row == 1:
                d.point((5, 8), fill='#303836')
                d.rectangle((10, 6, 12, 10), fill='#574038')
            elif row == 2:
                d.point((11, 8), fill='#303836')
            else:
                d.point((7, 8), fill='#303836'); d.point((11, 8), fill='#303836')
            d.rectangle((5, 1, 11, 4), fill='#9480a8' if npc else '#dfbd70')
            d.rectangle((3, 4, 14, 5), fill='#beabd0' if npc else '#f1d38c')
            d.line((6, 2, 10, 2), fill='#e7d5e3' if npc else '#f7dfa0')
            sheet.paste(im, (frame*16, row*24))
    return sheet
save(person(), 'characters/player.png')
save(person(True).crop((0, 0, 16, 24)), 'characters/linya.png')

im, d = canvas(40, 52)
d.ellipse((7, 41, 35, 49), fill='#42543d55')
d.rectangle((18, 26, 23, 46), fill='#77523e')
d.rectangle((19, 26, 20, 44), fill='#a67b4e')
d.polygon([(20,3),(10,9),(5,17),(2,28),(7,35),(16,37),(21,34),(28,36),(37,30),(35,17),(29,8)], fill='#355e48')
d.polygon([(19,3),(10,10),(7,18),(4,25),(9,30),(18,31),(24,28),(32,30),(35,23),(31,12)], fill='#4f8250')
d.polygon([(18,5),(11,12),(10,18),(6,22),(17,25),(25,21),(30,23),(30,14),(25,8)], fill='#6e9d55')
d.rectangle((13,12,16,14), fill='#92b45e'); d.rectangle((23,16,25,18), fill='#92b45e')
save(im, 'tilesets/tree.png')
im,d=canvas(20,16)
d.ellipse((2,10,19,15), fill='#49604755')
d.polygon([(2,11),(4,5),(10,2),(16,4),(19,11),(15,13),(6,13)], fill='#647b76')
d.polygon([(4,8),(6,4),(11,2),(15,5),(12,9)], fill='#a5b0a0')
d.line((4,11,15,11), fill='#82958b',width=2)
save(im, 'tilesets/rock.png')

im,d=canvas(96,84)
d.rectangle((4,74,93,81), fill='#40574744')
d.rectangle((12,30,84,74), fill='#815b46')
d.rectangle((14,34,82,71), fill='#e0c58b')
for y in range(38,72,8): d.line((15,y,81,y),fill='#c9a675')
d.rectangle((12,65,84,71), fill='#a17c59')
d.rectangle((41,48,57,74), fill='#6b4e40')
d.rectangle((44,50,54,72), fill='#946b48'); d.point((52,61),fill='#e8d190')
for x in (21,65):
    d.rectangle((x,44,x+11,57),fill='#805a42')
    d.rectangle((x+2,46,x+9,54),fill='#89bcc0')
    d.line((x+6,46,x+6,54),fill='#e9daa1')
    d.rectangle((x-2,57,x+13,60),fill='#9c6445')
    d.rectangle((x,55,x+3,57),fill='#5b814f'); d.rectangle((x+7,54,x+10,57),fill='#dca16c')
d.rectangle((69,7,76,24),fill='#776353');d.rectangle((67,5,78,9),fill='#a28b6b')
d.polygon([(48,7),(92,35),(91,40),(4,40),(4,35)],fill='#704c3e')
d.polygon([(48,4),(91,32),(4,32)],fill='#b76449')
for y in range(13,33,5):
    half=int((y-4)*1.55)
    d.line((48-half,y,48+half,y),fill='#cf8058')
    for x in range(48-half+5,48+half,12):d.line((x,y,x-2,y+3),fill='#995039')
d.line((4,34,91,34), fill='#e0aa6e',width=2)
d.rectangle((38,74,60,78), fill='#b59b75')
save(im, 'buildings/house.png')

im,d=canvas(64,48)
d.rectangle((4,39,60,45), fill='#45553c44')
d.rectangle((8,13,11,41),fill='#7b5a43');d.rectangle((53,13,56,41),fill='#7b5a43')
d.polygon([(10,4),(54,4),(62,19),(2,19)],fill='#e4c486')
for x in range(7,58,14): d.polygon([(x+4,4),(x+10,4),(x+13,19),(x,19)], fill='#688b79')
d.rectangle((3,19,61,22),fill='#456951')
d.rectangle((7,30,57,40),fill='#9c754c')
d.rectangle((5,28,59,31),fill='#d3ab6d')
for x in (14,29,44):
    d.rectangle((x,24,x+8,28),fill='#dfc68b'); d.rectangle((x+3,21,x+5,25),fill='#769850')
save(im,'buildings/market.png')

im,d=canvas(16,20)
d.rectangle((3,1,5,19),fill='#a78155');d.rectangle((11,1,13,19),fill='#a78155')
d.rectangle((1,6,15,8),fill='#c4a36c');d.rectangle((1,13,15,15),fill='#c4a36c')
save(im,'tilesets/fence.png')

im,d=canvas(64,60)
for row in range(3):
    for stage in range(4):
        ox,oy=stage*16,row*20
        d.ellipse((ox+4,oy+16,ox+12,oy+18),fill='#314c3b55')
        if stage==0:
            d.rectangle((ox+7,oy+13,ox+8,oy+16),fill='#466743')
            d.rectangle((ox+5,oy+12,ox+7,oy+13),fill='#9bc168')
            d.rectangle((ox+9,oy+11,ox+11,oy+12),fill='#a6cb6b')
        else:
            high=oy+11-stage*2
            d.line((ox+8,oy+17,ox+8,high),fill='#4b7445',width=2)
            for y in range(high,oy+15,3):
                d.line((ox+8,y+2,ox+4,y),fill='#72a351',width=2)
                d.line((ox+9,y+1,ox+12,y-1),fill='#a7be61',width=2)
            if stage==3:
                if row==0:
                    d.polygon([(ox+5,oy+12),(ox+11,oy+12),(ox+9,oy+19),(ox+7,oy+17)],fill='#e99542')
                    d.line((ox+7,oy+12,ox+7,oy+16),fill='#f6bd63')
                elif row==1:
                    d.ellipse((ox+3,oy+12,ox+8,oy+17),fill='#cfaa6c'); d.ellipse((ox+8,oy+13,ox+13,oy+18),fill='#e2c080')
                else:
                    for x,h in [(4,4),(8,1),(12,5)]:
                        d.line((ox+x,oy+h,ox+x,oy+16),fill='#d5b35d')
                        for y in range(h,h+7,2):d.rectangle((ox+x-1,oy+y,ox+x+1,oy+y+1),fill='#efcc70')
save(im,'crops/crops.png')

im,d=canvas(16,16)
d.rectangle((2,2,13,13),fill='#a5784b');d.rectangle((3,3,12,12),fill='#d6b774')
d.rectangle((5,5,10,10),fill='#507449');d.rectangle((7,4,8,11),fill='#94b35c')
save(im,'ui/seed.png')

# 简短原创合成音效，不依赖第三方音频素材。
audio=ROOT/'assets/audio';audio.mkdir(parents=True,exist_ok=True)
for name,notes in {'action':[330,440], 'harvest':[523,659,784], 'day':[392,494,587,784], 'click':[660]}.items():
    samples=[]
    for freq in notes:
        for i in range(3300):
            t=i/22050
            envelope=(1-i/3300)**2
            sample=math.sin(2*math.pi*freq*t)*0.16*envelope
            samples.append(struct.pack('<h',int(sample*32767)))
    with wave.open(str(audio/(name+'.wav')),'wb') as f:
        f.setparams((1,2,22050,0,'NONE','not compressed')); f.writeframes(b''.join(samples))
print('Original pixel assets and audio generated.')
