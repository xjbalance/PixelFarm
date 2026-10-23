"""在本工程原创素材上增加建筑、衣着与树冠细节，仍使用整数像素和统一色板。"""
from pathlib import Path
from PIL import Image, ImageDraw
import random

ROOT=Path(__file__).resolve().parents[1]/'assets'

def base(path,size):
    return Image.open(ROOT/path).convert('RGBA').resize(size,Image.NEAREST)

def save(image,path):
    image.resize((image.width*2,image.height*2),Image.NEAREST).save(ROOT/path)

house=base('buildings/house.png',(96,84))
p=ImageDraw.Draw(house)
# 不改变门口和碰撞范围；增加石基、梁柱、窗框、门板与爬藤。
for y in [66,70]:
    for x in range(14+(3 if y==70 else 0),82,9):
        p.rectangle((x,y,min(x+7,82),y+2),fill='#a49375' if x%3 else '#b1a184')
for x in [14,80]:
    p.rectangle((x,41,x+2,64),fill='#a18157')
    p.line((x,41,x,64),fill='#c4a271')
for x in [45,49,53]:p.line((x,51,x,71),fill='#78583f')
p.rectangle((51,60,53,62),fill='#d4bb79')
for x in [21,65]:
    p.line((x+2,50,x+9,50),fill='#d7d9ab')
    p.line((x+3,46,x+3,49),fill='#cae1cb')
    for side in [x-4,x+12]:
        p.rectangle((side,44,side+2,56),fill='#758267')
        for y in [47,50,53]:p.line((side,y,side+2,y),fill='#4f6e59')
    p.line((x-2,60,x+13,60),fill='#ca9d69')
    for px in [x+1,x+8]:
        p.rectangle((px,55,px+2,57),fill='#719365')
        p.point((px+1,54),fill='#e4b190')
for x,y in [(76,62),(78,58),(77,54),(79,50),(78,46),(80,42)]:
    p.rectangle((x,y,x+3,y+2),fill='#658362')
    p.point((x+1,y),fill='#91a86e')
p.rectangle((46,25,51,30),fill='#795c46')
p.rectangle((47,26,50,29),fill='#b8be94')
p.line((48,26,48,29),fill='#6b6049')
save(house,'buildings/house.png')
for name,roof in [('tea_house',('#506f61','#75927a','#3f6157')),('workshop',('#62767b','#89958c','#4e646d'))]:
    image=house.copy();pixels=image.load()
    repl={(183,100,73):roof[0],(207,128,88):roof[1],(153,80,57):roof[2]}
    for y in range(4,34):
        for x in range(96):
            color=pixels[x,y]
            if color[:3] in repl:
                h=repl[color[:3]].lstrip('#');pixels[x,y]=tuple(int(h[i:i+2],16) for i in [0,2,4])+(255,)
    q=ImageDraw.Draw(image)
    if name=='tea_house':
        for x in range(34,65,5):
            q.polygon([(x+2,42),(x+6,42),(x+8,48),(x,48)],fill='#cbb990' if x%2 else '#718c73')
        q.rectangle((32,48,65,49),fill='#57735c')
        q.rectangle((58,62,64,70),fill='#ac8058')
        q.rectangle((59,60,63,63),fill='#76905d')
    else:
        for y in [56,61]:
            q.rectangle((17,y,33,y+3),fill='#9d825b')
            q.line((18,y+1,32,y+1),fill='#d1b483')
        q.line((61,52,69,59),fill='#c8a877',width=2)
        q.line((67,51,62,57),fill='#bbc0a6',width=2)
    save(image,'buildings/'+name+'.png')

tree=base('tilesets/tree.png',(40,52));p=ImageDraw.Draw(tree)
rng=random.Random(889)
for x,y,r in [(10,18,7),(22,11,8),(28,23,8),(14,28,7),(21,23,9)]:
    p.polygon([(x-r,y),(x-r+2,y-r+2),(x+1,y-r),(x+r,y-3),(x+r-1,y+2),(x+2,y+4),(x-r+2,y+2)],fill='#668b55' if y<24 else '#567e50')
    p.line((x-r+2,y-2,x-r+4,y-5),fill='#89a760',width=2)
    for _ in range(5):
        a,b=x+rng.randrange(-r+2,r-1),y+rng.randrange(-4,2)
        p.rectangle((a,b,a+1,b),fill=rng.choice(['#9cb370','#729750','#799a59']))
p.line((21,33,21,43),fill='#b38a5c')
p.line((18,39,15,35),fill='#7a5d45',width=2)
p.line((19,46,14,48),fill='#6c6847',width=2)
save(tree,'tilesets/tree.png')

for name in ['player','linya','zhou','ahe']:
    image=Image.open(ROOT/f'characters/{name}.png').convert('RGBA')
    image=image.resize((image.width//2,image.height//2),Image.NEAREST);p=ImageDraw.Draw(image)
    for oy in range(0,image.height,24):
        for ox in range(0,image.width,16):
            p.line((ox+6,oy+13,ox+6,oy+17),fill='#8b9b88' if name in ['player','zhou'] else '#e1cfa5')
            p.rectangle((ox+8,oy+15,ox+10,oy+16),fill='#677b70' if name in ['player','zhou'] else '#c4ad85')
            p.point((ox+8,oy+12),fill='#f0d19e')
            p.point((ox+6,oy+10),fill='#c98c6b')
            if name=='player':p.line((ox+6,oy+3,ox+11,oy+3),fill='#ae8551')
    save(image,f'characters/{name}.png')
print('Original buildings, foliage and clothing detailed.')
