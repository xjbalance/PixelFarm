"""Original small pixel livestock sprites, drawn geometrically without external art."""
from pathlib import Path
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[1]/'assets/livestock'
ROOT.mkdir(parents=True,exist_ok=True)
DARK='#4d5747';CREAM='#e1dbbe';WHITE='#eee7cd';BROWN='#ab8a64'
for species in ['chicken','cow','sheep']:
    sheet=Image.new('RGBA',(64,32))
    for frame in range(2):
        image=Image.new('RGBA',(32,32));d=ImageDraw.Draw(image);step=frame
        if species=='chicken':
            d.rectangle((7,12,23,24),fill=DARK);d.rectangle((8,11,21,21),fill=WHITE)
            d.rectangle((17,5,25,15),fill=DARK);d.rectangle((18,5,24,13),fill=WHITE)
            d.rectangle((19,3,21,6),fill='#b76e59');d.rectangle((22,3,24,6),fill='#b76e59')
            d.rectangle((25,8,28,11),fill='#d1aa64');d.point((22,7),fill=DARK)
            d.polygon([(8,14),(3,8),(4,19),(10,22)],fill='#adbc9a')
            d.rectangle((10,15,16,19),fill='#c7c9a4')
            d.line((11,23,11+step,28),fill='#b58d51',width=2);d.line((20,23,20-step,28),fill='#b58d51',width=2)
        elif species=='cow':
            d.rectangle((4,10,26,23),fill=DARK);d.rectangle((5,9,25,21),fill='#d8c6a3')
            d.rectangle((6,11,12,17),fill='#6c725b');d.rectangle((19,10,24,15),fill='#6c725b')
            d.rectangle((2,14,9,23),fill='#bdac86');d.rectangle((2,20,10,24),fill='#c99f87')
            d.rectangle((1,12,4,16),fill=DARK);d.rectangle((8,12,11,16),fill=DARK)
            d.rectangle((3,10,4,13),fill='#dcd2ab');d.rectangle((8,10,9,13),fill='#dcd2ab')
            d.point((4,17),fill=DARK);d.point((8,17),fill=DARK)
            d.rectangle((13,22,19,24),fill='#c6a38b')
            d.rectangle((7+step,23,9+step,29),fill=DARK);d.rectangle((22-step,22,24-step,29),fill=DARK)
            d.line((26,12,28,21),fill=DARK,width=2)
        else:
            d.rectangle((6,9,25,23),fill=DARK)
            for cx,cy in [(9,10),(15,8),(21,10),(9,16),(16,14),(23,16),(11,21),(18,21)]:
                d.ellipse((cx-4,cy-4,cx+4,cy+4),fill=WHITE,outline='#c6ccb2')
            d.rectangle((3,14,10,24),fill='#777d67');d.rectangle((1,14,5,17),fill=DARK)
            d.point((5,18),fill='#e4ddbd');d.rectangle((8+step,24,10+step,29),fill=DARK)
            d.rectangle((21-step,23,23-step,29),fill=DARK)
        sheet.alpha_composite(image,(frame*32,0))
    sheet.save(ROOT/f'{species}.png')
for item in ['hay','egg','milk','wool']:
    image=Image.new('RGBA',(32,32));d=ImageDraw.Draw(image)
    if item=='hay':
        d.rectangle((5,10,26,25),fill='#bdac66');d.rectangle((7,8,24,23),fill='#cbbb73')
        for x in range(8,25,3):d.line((x,9,x-2,24),fill='#9b8e51',width=1)
        d.rectangle((5,14,26,17),fill='#8b7751')
    elif item=='egg':
        d.ellipse((8,6,24,28),fill=DARK);d.ellipse((9,5,23,26),fill=WHITE)
        d.rectangle((12,10,14,17),fill='#fff4d8')
    elif item=='milk':
        d.rectangle((10,8,22,27),fill=DARK);d.rectangle((11,9,21,25),fill='#d5dfcb')
        d.rectangle((13,4,19,9),fill='#c8d3bf');d.rectangle((12,3,20,5),fill='#7f9b90')
        d.rectangle((11,18,21,24),fill='#adc6b9');d.rectangle((14,10,16,16),fill='#f4efd9')
    else:
        for x,y in [(9,12),(16,9),(23,12),(9,20),(16,22),(23,20),(16,16)]:
            d.ellipse((x-5,y-5,x+5,y+5),fill=WHITE,outline='#aab99e')
        d.arc((12,12,21,22),30,280,fill='#aab99e',width=1)
    image.save(ROOT/f'{item}.png')
print('Generated 7 original livestock pixel textures.')
