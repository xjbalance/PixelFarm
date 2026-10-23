"""扩展工程原有像素绘制源，统一色板、角色与工具图标，制作原创循环音乐。"""
from pathlib import Path
from PIL import Image, ImageDraw
import random, math, wave, array

ROOT = Path(__file__).resolve().parents[1]
rng = random.Random(347)
ground = Image.new('RGBA',(256,32))
d = ImageDraw.Draw(ground)
palette = ['#829862','#809660','#849b65','#cab388','#ad8c61','#76a6a4','#5f9297','#967b58']
for tile,base in enumerate(palette):
    x = tile*32
    d.rectangle((x,0,x+31,31),fill=base)
    shades = ['#8dA36b','#758d5b'] if tile<3 else (['#d3bd93','#bea67b'] if tile==3 else ['#b99769','#a28259'])
    if tile in (5,6): shades=['#87b5af','#6f9f9e']
    if tile==7: shades=['#a78b63','#846e53']
    for i in range(9 if tile<3 else 6):
        px,py=x+rng.randrange(1,29),rng.randrange(1,30)
        d.rectangle((px,py,px+1,py),fill=rng.choice(shades))
    if tile==7:
        for y in (0,15,31):d.line((x,y,x+31,y),fill='#78664e')
ground.save(ROOT/'assets/tilesets/ground.png')

base=Image.open(ROOT/'assets/characters/linya.png').convert('RGBA').resize((16,24),Image.NEAREST)
for name,coat,hair in [('zhou','#527d83','#4e4d48'),('ahe','#ab7657','#c7c3ae')]:
    person=base.copy()
    p=ImageDraw.Draw(person)
    p.rectangle((0,0,15,10),fill=(0,0,0,0))
    p.rectangle((5,4,12,11),fill='#e9b984')
    p.rectangle((4,2,12,6),fill=hair)
    p.rectangle((4,5,5,9),fill=hair)
    p.rectangle((4,11,12,17),fill=coat)
    p.rectangle((6,14,10,18),fill='#b9a67c')
    p.point((7,8),fill='#35413c');p.point((11,8),fill='#35413c')
    if name=='zhou':p.rectangle((6,10,11,11),fill=hair)
    else:p.rectangle((3,1,6,4),fill=hair);p.line((6,8,12,8),fill='#7b7665')
    person.resize((32,48),Image.NEAREST).save(ROOT/f'assets/characters/{name}.png')

sheet=Image.new('RGBA',(128,16))
for i in range(8):
    icon=Image.new('RGBA',(16,16));p=ImageDraw.Draw(icon)
    if i in (0,6,7):
        p.line((4,13,11,3),fill='#dfba7e',width=2)
        if i==0:p.polygon([(7,3),(9,1),(14,4),(12,7)],fill='#bec8b3')
        elif i==6:p.polygon([(7,2),(11,1),(14,5),(13,8),(10,7)],fill='#b7c8c3')
        else:p.line((5,2,14,7),fill='#bdc9c3',width=3)
    elif i==1:
        p.rectangle((3,6,10,12),fill='#83b6be');p.rectangle((5,3,8,5),outline='#bed5c5')
        p.line((10,9,14,5),fill='#b9d7d0',width=2);p.line((2,6,1,9),fill='#bed5c5',width=2)
    elif i==2:
        p.rectangle((4,7,11,12),fill='#e8c28c');p.rectangle((4,3,5,8),fill='#e8c28c');p.rectangle((7,2,8,8),fill='#e8c28c');p.rectangle((10,4,11,9),fill='#e8c28c')
    else:
        p.rectangle((3,3,12,14),fill='#c6a777');p.rectangle((4,4,11,6),fill='#f1d8a1')
        color=['#ed9951','#d8bc82','#e8ce81'][i-3]
        p.ellipse((6,8,10,12),fill=color);p.line((8,8,9,6),fill='#628b5c',width=2)
    sheet.paste(icon,(i*16,0))
sheet.resize((256,32),Image.NEAREST).save(ROOT/'assets/ui/tools.png')

# 室内、林间共用的 48 秒原创木琴/柔和弦乐主题，采样为 22050 Hz 单声道。
rate=22050; duration=48.0
music=[0.0]*int(rate*duration)
def note(start, midi, length, volume, soft=False):
    freq=440*2**((midi-69)/12)
    count=int(length*rate)
    for j in range(count):
        t=j/rate
        envelope=min(1,t/0.035)*math.exp(-t/(length*0.32))
        if soft:envelope=math.sin(math.pi*j/count)**2*0.55
        tone=math.sin(2*math.pi*freq*t)+0.22*math.sin(4*math.pi*freq*t)*math.exp(-t*4)
        index=(int(start*rate)+j)%len(music)
        music[index]+=tone*volume*envelope
chords=[(50,57,62,66),(55,59,62,67),(47,54,59,62),(45,52,57,61)]
melody=[74,73,69,66,67,71,74,71,69,66,62,66,64,69,73,69]
for bar in range(16):
    chord=chords[bar%4];start=bar*3.0
    for key in chord:note(start,key,3.05,0.045,True)
    for beat,key in enumerate([chord[0]+12,chord[2],chord[1]+12,chord[3]]):note(start+beat*0.75,key,1.4,0.075)
    for n in range(2):note(start+n*1.5+0.06,melody[(bar*2+n)%16],1.8,0.09)
data=array.array('h',(int(max(-0.9,min(0.9,v))*32767) for v in music))
with wave.open(str(ROOT/'assets/audio/river_theme.wav'),'wb') as out:
    out.setparams((1,2,rate,0,'NONE','not compressed'));out.writeframes(data.tobytes())
wind=0.0;rain=array.array('h')
for i in range(rate*8):
    wind=wind*0.93+rng.uniform(-1,1)*0.07
    rain.append(int((wind*0.23+rng.uniform(-1,1)*0.035)*32767))
with wave.open(str(ROOT/'assets/audio/rain.wav'),'wb') as out:
    out.setparams((1,2,rate,0,'NONE','not compressed'));out.writeframes(rain.tobytes())
print('Polished original assets and looping audio generated.')
