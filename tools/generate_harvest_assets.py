"""Extend the existing hand-drawn pixel system at native resolution, using its shared ramps."""
from pathlib import Path
import json, argparse, math
from PIL import Image, ImageDraw
from world_palette import harmonize, CONFIG
ROOT=Path(__file__).resolve().parents[1]
D=json.loads((ROOT/'resources/harvest/harvest.json').read_text())
OUT=ROOT/'assets/harvest'
for folder in ['items','crops','stations','orchard']:(OUT/folder).mkdir(parents=True,exist_ok=True)
P={k:['#'+x for x in v] for k,v in CONFIG['ramps'].items()}
INK=P['outline'][1];GREEN=P['leaf'][4];LEAF=P['leaf'][2];LIGHT=P['leaf'][7];CREAM=P['cream'][-2];WOOD=P['wood_earth'][3]
def save(im,path):harmonize(im).save(path)
def leaf(d,x,y,dx=1,color=GREEN):
    d.polygon([(x,y),(x+dx*6,y-4),(x+dx*8,y-3),(x+dx*6,y+1)],fill=LEAF)
    d.line((x+dx,y-1,x+dx*6,y-3),fill=color,width=2)
def produce(id,shape=None):
    im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
    shape=shape or D['crops'].get(id,{}).get('shape',id)
    if shape=='berry':
        for x,y,s in [(7,13,10),(17,7,9)]:
            d.polygon([(x,y),(x+s,y),(x+s-1,y+7),(x+4,y+12),(x,y+7)],fill=P['roof'][1]);d.polygon([(x+1,y+1),(x+s-1,y+1),(x+s-2,y+6),(x+4,y+10),(x+1,y+6)],fill=P['roof'][3])
            for a,b in [(2,3),(6,4),(4,7)]:d.point((x+a,y+b),fill=P['gold'][-1])
            d.polygon([(x-1,y),(x+3,y-3),(x+5,y-1),(x+8,y-3),(x+s+1,y),(x+5,y+2)],fill=LEAF)
    elif shape in ['cabbage','kale','lettuce']:
        w=20 if shape!='lettuce' else 15;h=19 if shape!='lettuce' else 24
        d.ellipse((16-w//2,28-h,16+w//2,28),fill=LEAF);d.ellipse((18-w//2,29-h,15+w//2,25),fill=GREEN)
        for x,y in [(7,19),(13,13),(20,17)]:
            d.arc((x,y,x+9,y+9),40,290,fill=LIGHT,width=2)
        d.line((15,27,16,10),fill=CREAM if shape=='lettuce' else LIGHT,width=2)
        if shape=='kale':
            for x,y in [(6,18),(10,11),(22,13),(24,22)]:d.rectangle((x,y,x+3,y+3),fill=LIGHT)
    elif shape in ['root','snowroot','tuber','onion']:
        col=CREAM if shape in ['root','snowroot','onion'] else P['roof'][2]
        d.polygon([(12,10),(22,10),(24,17),(18,26),(11,28),(9,21),(9,15)],fill=INK)
        d.polygon([(13,11),(21,11),(22,17),(17,25),(12,26),(10,20),(11,15)],fill=col)
        d.line((13,14,12,20),fill=P['cream'][-1],width=2)
        if shape=='snowroot':d.line((20,14,21,19),fill=P['water'][-2],width=2)
        if shape=='onion':d.line((11,10,9,2),fill=GREEN,width=3);d.line((17,11,18,3),fill=LEAF,width=3)
        else:leaf(d,16,11,-1);leaf(d,16,10,1)
    elif shape in ['pod','frostpod','cucumber','chili','eggplant']:
        col={'pod':GREEN,'frostpod':P['teal'][2],'cucumber':LEAF,'chili':P['roof'][3],'eggplant':P['star'][1]}[shape]
        points=[(8,24),(8,17),(12,10),(22,5),(26,8),(24,15),(17,23),(10,27)]
        if shape=='chili':points=[(6,27),(14,15),(16,9),(24,8),(26,12),(20,22),(12,27)]
        d.polygon(points,fill=INK);d.polygon([(x+(-1 if x>17 else 1),y+(-1 if y>16 else 1)) for x,y in points],fill=col)
        d.line((12,21,20,10),fill=LIGHT if shape!='eggplant' else P['star'][3],width=2)
        if shape in ['pod','frostpod']:
            for x,y in [(12,21),(16,16),(20,11)]:d.ellipse((x-1,y-1,x+2,y+2),fill=LIGHT)
        if shape=='cucumber':
            for x,y in [(11,20),(16,15),(21,10)]:d.point((x+3,y),fill=LIGHT)
        leaf(d,23,8,1)
    elif shape in ['tomato','melon','pumpkin','apple','orange','peach','pear']:
        col={'tomato':P['roof'][3],'melon':GREEN,'pumpkin':P['roof'][4],'apple':P['roof'][3],'orange':P['gold'][2],'peach':P['flower'][2],'pear':P['gold'][3]}[shape]
        box=(5,10,27,28) if shape!='pear' else (8,14,25,28)
        d.ellipse(box,fill=INK);d.ellipse((box[0]+1,box[1]+1,box[2]-1,box[3]-1),fill=col)
        if shape=='pear':d.ellipse((13,7,21,22),fill=col)
        d.line((9,17,11,13),fill=P['cream'][-2],width=2)
        if shape in ['melon','pumpkin']:
            for x in [11,17,23]:d.arc((x-4,11,x+4,27),270,90,fill=LEAF if shape=='melon' else P['roof'][2],width=2)
        if shape=='peach':d.arc((9,11,19,27),270,90,fill=P['flower'][0])
        d.line((16,11,18,6),fill=P['wood_earth'][0],width=2);leaf(d,18,8,1)
    elif shape in ['cluster','grape','beans','peanut']:
        col=P['star'][2] if shape in ['cluster','grape'] else P['gold'][3]
        coords=[(10,11),(20,10),(15,18),(9,22),(23,21)] if shape!='grape' else [(10,10),(18,10),(8,16),(16,16),(21,16),(12,22),(18,22),(15,26)]
        for x,y in coords:
            d.ellipse((x-3,y-3,x+3,y+3),fill=INK);d.ellipse((x-2,y-2,x+2,y+2),fill=col);d.point((x-1,y-1),fill=CREAM)
            if shape=='peanut':d.line((x,y-2,x,y+2),fill=WOOD)
        if shape in ['cluster','grape']:leaf(d,17,7,1)
    elif shape in ['stalk','grain','corn','cotton']:
        d.line((15,28,16,6),fill=LEAF,width=2)
        if shape=='stalk':
            for x in [10,16,22]:d.line((x,27,x-2,7),fill=GREEN,width=3);d.line((x,27,x,22),fill=CREAM,width=2)
        elif shape=='corn':
            d.ellipse((10,5,22,26),fill=LEAF);d.ellipse((12,5,21,22),fill=P['gold'][3])
            for y in range(8,22,4):d.line((13,y,20,y),fill=P['gold'][0]);d.line((16,6,16,22),fill=P['gold'][-1])
            leaf(d,15,26,-1);leaf(d,16,27,1)
        elif shape=='cotton':
            for x,y in [(9,14),(20,12),(15,21)]:d.ellipse((x-4,y-4,x+4,y+4),fill=P['cream'][3]);d.ellipse((x-3,y-4,x+3,y+2),fill=CREAM)
            leaf(d,15,27,1)
        else:
            for y in [10,15,20]:
                d.line((16,y+2,8,y-3),fill=P['gold'][3],width=3);d.line((16,y,24,y-5),fill=P['gold'][-1],width=3)
    else:
        # Flower silhouettes differ in petals and stem organization, not merely tint.
        for x in ([10,16,22] if shape=='lavender' else [13,20]):
            d.line((16,29,x,10),fill=LEAF,width=2);leaf(d,15,24,-1)
        if shape=='lavender':
            for x in [10,16,22]:
                for y in [6,10,14]:d.rectangle((x-2,y,x+2,y+3),fill=P['star'][2]);d.point((x-1,y),fill=P['star'][4])
        elif shape in ['daisy','oilflower']:
            for x,y in [(10,10),(22,15),(17,6)]:
                d.rectangle((x-4,y-1,x+4,y+1),fill=CREAM if shape=='daisy' else P['gold'][-1]);d.rectangle((x-1,y-4,x+1,y+4),fill=CREAM if shape=='daisy' else P['gold'][3]);d.rectangle((x-1,y-1,x+1,y+1),fill=P['gold'][0])
        elif shape=='sunflower':
            for a in range(8):
                x=16+round(math.cos(a*math.pi/4)*7);y=12+round(math.sin(a*math.pi/4)*7);d.ellipse((x-3,y-3,x+3,y+3),fill=P['gold'][3])
            d.ellipse((11,7,21,17),fill=P['wood_earth'][1]);d.point((14,10),fill=P['gold'][0]);d.point((17,13),fill=P['gold'][0])
        else:
            d.ellipse((6,6,23,20),fill=P['flower'][0]);d.ellipse((7,6,21,17),fill=P['flower'][2]);d.arc((10,8,21,17),0,280,fill=P['flower'][0],width=2);d.rectangle((13,10,16,12),fill=P['flower'][3])
    return im

def product(id,info):
    shape=info.get('shape','sack');ramp=P[info.get('color','gold')];c=ramp[len(ramp)//2];hi=ramp[-1]
    if info['kind']=='fruit':return produce(id)
    if info['kind']=='sapling':
        im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im);d.line((16,27,16,7),fill=WOOD,width=3);leaf(d,16,13,-1);leaf(d,16,10,1);d.rectangle((10,25,22,29),fill=P['wood_earth'][0]);return im
    im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
    if shape in ['jar','bottle','perfume','cup']:
        x=10 if shape in ['bottle','perfume'] else 7
        d.rounded_rectangle((x,10,32-x,28),radius=2,fill=INK);d.rectangle((x+2,12,30-x,26),fill=c);d.line((x+3,13,x+3,22),fill=hi,width=2)
        d.rectangle((x-1,6,33-x,10),fill=WOOD);d.line((x,6,32-x,6),fill=P['wood_earth'][-2]);d.rectangle((x+4,17,28-x,23),fill=CREAM)
        if shape=='bottle':d.rectangle((13,3,19,9),fill=WOOD)
        if shape=='perfume':d.rectangle((13,2,19,6),fill=P['gold'][3]);d.rectangle((15,17,17,20),fill=P['flower'][2])
        if shape=='cup':
            d.rectangle((23,13,28,22),outline=INK,width=2);d.rectangle((7,9,24,12),fill=CREAM);d.line((13,3,11,6),fill=P['cream'][2]);d.line((19,2,17,6),fill=P['cream'][2])
        if id=='mayonnaise':d.ellipse((13,18,19,23),fill=P['gold'][3])
    elif shape in ['sack','sachet']:
        d.polygon([(8,8),(24,8),(27,27),(5,27)],fill=INK);d.polygon([(9,10),(23,10),(25,25),(7,25)],fill=CREAM if shape=='sack' else c);d.rectangle((8,6,24,9),fill=WOOD);d.line((10,12,8,23),fill=P['cream'][-1])
        d.rectangle((13,15,20,21),fill=c);d.line((16,14,16,22),fill=hi)
    elif shape in ['cloth','bundle']:
        if shape=='cloth':
            d.polygon([(5,8),(24,8),(27,24),(10,28),(5,24)],fill=INK);d.polygon([(6,9),(23,9),(25,23),(10,26),(6,23)],fill=c);d.line((9,11,22,11),fill=hi,width=2);d.line((10,15,24,15),fill=ramp[0]);d.line((11,21,24,21),fill=hi)
        else:
            for x in [9,15,21]:d.line((16,27,x,8),fill=LEAF,width=2);d.rectangle((x-2,6,x+2,17),fill=c);d.point((x-1,7),fill=hi)
            d.line((11,22,21,22),fill=WOOD,width=2)
    elif shape in ['tofu','butter','cheese']:
        d.polygon([(5,13),(13,8),(27,12),(27,23),(8,26),(5,22)],fill=INK);d.polygon([(7,14),(14,10),(25,13),(25,21),(9,24),(7,21)],fill=c);d.polygon([(7,14),(14,10),(25,13),(17,17)],fill=hi)
        if shape=='butter':d.line((17,18,17,23),fill=ramp[0])
    elif shape in ['bread','cake','pie','cookie','pancake','riceball','tuber']:
        d.ellipse((3,23,29,29),fill=P['cream'][3]);d.line((6,27,26,27),fill=CREAM)
        if shape=='bread':
            d.rounded_rectangle((5,8,27,24),radius=6,fill=P['wood_earth'][1]);d.rounded_rectangle((6,8,26,21),radius=5,fill=P['gold'][2]);d.line((9,10,22,10),fill=P['gold'][-1])
            for x in [12,18,24]:d.line((x,12,x-3,18),fill=P['wood_earth'][1],width=2)
        elif shape=='cake':
            d.polygon([(7,23),(7,12),(18,5),(27,12),(27,23)],fill=INK);d.rectangle((8,14,26,22),fill=P['gold'][3]);d.line((8,18,26,18),fill=c,width=3);d.polygon([(7,12),(18,6),(27,12),(26,15),(8,15)],fill=CREAM);d.ellipse((16,5,21,9),fill=P['roof'][3])
        elif shape in ['pie','cookie','pancake']:
            d.ellipse((5,9,27,25),fill=P['wood_earth'][1]);d.ellipse((6,9,26,23),fill=P['gold'][2]);d.ellipse((9,12,23,21),fill=c)
            if shape=='pie':
                for x in [10,16,22]:d.line((x,12,x-2,22),fill=P['gold'][-1],width=2)
            else:
                for x,y in [(10,14),(18,12),(21,19),(12,21)]:d.rectangle((x,y,x+2,y+1),fill=hi)
        elif shape=='riceball':
            d.polygon([(6,24),(15,6),(20,7),(28,24)],fill=INK);d.polygon([(8,22),(16,8),(19,9),(25,22)],fill=CREAM);d.rectangle((14,18,22,24),fill=LEAF)
        else:im.alpha_composite(produce('roast','tuber'))
    else:
        d.ellipse((4,13,28,28),fill=INK);d.ellipse((5,11,27,23),fill=P['cream'][3]);d.ellipse((7,12,25,21),fill=c);d.line((10,26,22,26),fill=CREAM)
        if shape=='noodles':
            for y in [14,17,20]:d.arc((9,y-2,23,y+4),5,180,fill=CREAM,width=2)
        elif shape=='rice':
            for x,y in [(10,15),(14,13),(19,17),(13,19),(22,14)]:d.line((x,y,x+2,y),fill=CREAM)
        elif shape=='tray':
            for x,y in [(10,14),(17,17),(22,14),(13,20)]:d.rectangle((x-2,y-1,x+2,y+1),fill=hi)
        else:
            for x,y in [(10,15),(19,14),(16,19)]:d.rectangle((x,y,x+3,y+2),fill=GREEN if shape=='salad' else P['roof'][4]);d.point((x,y),fill=hi)
    return im

def crop_sheet(id):
    sheet=Image.new('RGBA',(128,40));ripe=produce(id)
    for stage in range(4):
        im=Image.new('RGBA',(32,40));d=ImageDraw.Draw(im)
        d.line((16,33,16,27-stage*5),fill=LEAF,width=2)
        if stage==0:leaf(d,16,29,-1);leaf(d,16,28,1)
        else:
            for y in range(27,20-stage*4,-6):leaf(d,16,y,-1);leaf(d,16,y-2,1)
            if stage==2:
                d.rectangle((13,14,17,17),fill=P['gold'][-1]);d.point((14,15),fill=P['gold'][1])
            if stage==3:im.alpha_composite(ripe,(0,3))
        sheet.alpha_composite(im,(stage*32,0))
    return sheet

def station(id):
    im=Image.new('RGBA',(32,48));d=ImageDraw.Draw(im)
    d.rectangle((4,29,28,40),fill=P['wood_earth'][0]);d.rectangle((5,29,27,36),fill=WOOD);d.line((5,29,27,29),fill=P['wood_earth'][-2]);d.rectangle((5,39,8,44),fill=P['wood_earth'][0]);d.rectangle((24,39,27,44),fill=P['wood_earth'][0])
    if id=='mill':
        d.rectangle((6,18,26,29),fill=P['stone'][0]);d.ellipse((5,13,27,24),fill=P['stone'][3]);d.ellipse((8,15,24,21),fill=P['stone'][4]);d.rectangle((10,5,23,15),fill=WOOD);d.polygon([(9,4),(24,4),(20,12),(13,12)],fill=P['wood_earth'][1]);d.line((16,19,28,19),fill=P['wood_earth'][0],width=2);d.rectangle((27,15,29,20),fill=WOOD)
    elif id=='jam_pot':
        d.rectangle((7,27,25,37),fill=P['stone'][1]);d.rectangle((12,30,21,35),fill=P['roof'][1]);d.polygon([(13,35),(16,29),(19,35)],fill=P['gold'][3]);d.rounded_rectangle((5,12,27,29),radius=5,fill=P['wood_earth'][0]);d.rounded_rectangle((7,13,25,26),radius=4,fill=P['roof'][4]);d.ellipse((5,10,27,17),fill=P['wood_earth'][0]);d.ellipse((8,11,24,15),fill=P['flower'][1]);d.line((22,13,27,4),fill=WOOD,width=2);d.rectangle((2,16,6,20),fill=INK)
    elif id=='oil_press':
        d.rectangle((5,7,8,30),fill=P['wood_earth'][0]);d.rectangle((24,7,27,30),fill=P['wood_earth'][0]);d.rectangle((4,5,28,9),fill=WOOD);d.rectangle((15,4,18,20),fill=P['stone'][1]);d.line((9,3,24,3),fill=WOOD,width=2);d.rectangle((10,21,24,29),fill=P['gold'][0]);d.line((10,23,24,23),fill=P['gold'][3],width=2);d.rectangle((20,34,25,39),fill=P['gold'][3])
    elif id=='pickle_jar':
        d.rounded_rectangle((7,10,26,39),radius=5,fill=P['wood_earth'][0]);d.rounded_rectangle((8,11,24,37),radius=4,fill=P['roof'][3]);d.rectangle((7,9,26,13),fill=P['wood_earth'][2]);d.rectangle((11,22,21,31),fill=CREAM);d.rectangle((14,24,18,28),fill=GREEN);d.line((10,15,10,21),fill=P['roof'][-1],width=2)
    elif id=='juicer':
        d.rectangle((8,8,25,29),fill=P['stone'][0]);d.rectangle((10,10,23,25),fill=P['water'][-2]);d.rectangle((11,17,22,24),fill=P['gold'][2]);d.rectangle((7,6,26,10),fill=WOOD);d.line((24,11,29,11),fill=INK,width=2);d.line((28,11,28,20),fill=WOOD,width=2);d.rectangle((9,27,24,31),fill=P['stone'][1])
    elif id in ['drying_rack','loom']:
        d.rectangle((4,4,7,40),fill=P['wood_earth'][0]);d.rectangle((25,4,28,40),fill=P['wood_earth'][0]);d.rectangle((3,5,29,8),fill=WOOD)
        for y in [13,22,30]:d.line((7,y,25,y),fill=WOOD,width=2)
        if id=='loom':
            for x in range(9,25,3):d.line((x,9,x,32),fill=CREAM)
            d.rectangle((8,22,24,29),fill=P['teal'][2]);d.line((8,25,24,25),fill=P['teal'][-1],width=2)
        else:
            for x,y in [(9,9),(18,9),(9,18),(18,27)]:d.rectangle((x,y,x+5,y+3),fill=P['roof'][4]);d.line((x,y,x+4,y),fill=P['gold'][3])
    elif id=='cheese_table':
        d.rectangle((6,12,18,28),fill=P['stone'][0]);d.rectangle((8,13,16,26),fill=P['cream'][4]);d.ellipse((6,10,18,15),fill=P['stone'][3]);d.polygon([(19,22),(27,18),(28,28),(19,28)],fill=P['gold'][3]);d.rectangle((23,23,25,24),fill=P['gold'][0])
    elif id=='egg_table':
        d.ellipse((5,17,22,29),fill=P['teal'][0]);d.ellipse((6,16,21,23),fill=P['cream'][-1]);d.ellipse((10,18,16,22),fill=P['gold'][3]);d.line((17,20,24,8),fill=WOOD,width=2);d.ellipse((23,22,28,28),fill=CREAM)
    else:
        d.rectangle((6,9,27,40),fill=P['stone'][0]);d.rectangle((8,10,25,37),fill=P['stone'][2]);d.rectangle((21,3,26,10),fill=P['stone'][1]);d.rectangle((11,15,22,27),fill=P['wood_earth'][0]);d.line((12,18,20,18),fill=WOOD);d.line((12,23,20,23),fill=WOOD);d.rectangle((12,30,21,35),fill=P['roof'][1]);d.rectangle((15,32,19,34),fill=P['gold'][3])
    return im

def trees(id):
    source=Image.open(ROOT/'assets/world_scheme_c/bright/sprites/apple_tree.png').convert('RGBA')
    # Preserve the existing native tree silhouette and bark. Remove old red fruit from the crown.
    px=source.load()
    for y in range(70):
        for x in range(source.width):
            r,g,b,a=px[x,y]
            if a and r>g*1.23 and r>b*1.25:px[x,y]=tuple(bytes.fromhex(CONFIG['ramps']['leaf'][4]))+(a,)
    for stage in ['young','growing','mature','fruit']:
        im=Image.new('RGBA',(96,96))
        if stage in ['young','growing']:
            size=32 if stage=='young' else 64;small=source.resize((size,size),Image.NEAREST);im.alpha_composite(small,((96-size)//2,96-size))
        else:im=source.copy()
        if stage=='fruit':
            fruit=produce(id).resize((12,12),Image.NEAREST)
            for x,y in [(24,28),(53,19),(66,45),(36,53)]:im.alpha_composite(fruit,(x,y))
        save(im,OUT/'orchard'/f'{id}_{stage}.png')

p=argparse.ArgumentParser();p.add_argument('--sample',action='store_true');args=p.parse_args()
crop_ids=['strawberry'] if args.sample else list(D['crops'])
for id in crop_ids:
    icon=produce(id);save(icon,OUT/'items'/f'{id}.png');save(crop_sheet(id),OUT/'crops'/f'{id}.png')
    bag=Image.new('RGBA',(32,32));d=ImageDraw.Draw(bag);d.rectangle((6,3,26,29),fill=INK);d.rectangle((7,4,25,28),fill=CREAM);d.rectangle((7,4,25,7),fill=WOOD);bag.alpha_composite(icon.resize((18,18),Image.NEAREST),(7,9));save(bag,OUT/'items'/f'{id}_seed.png')
for id,info in D['items'].items():
    if not args.sample or id in ['bread','mayonnaise']:save(product(id,info),OUT/'items'/f'{id}.png')
for id in (['jam_pot'] if args.sample else D['stations']):save(station(id),OUT/'stations'/f'{id}.png')
if not args.sample:
    for id in D['orchard']:trees(id)
images=sorted((OUT/'items').glob('*.png'));sheet=Image.new('RGBA',(16*40,math.ceil(len(images)/16)*48))
for i,path in enumerate(images):sheet.alpha_composite(Image.open(path).convert('RGBA'),((i%16)*40+4,(i//16)*48+4))
save(sheet,OUT/'item_atlas.png')
(OUT/'item_atlas.json').write_text(json.dumps({p.stem:[(i%16)*40+4,(i//16)*48+4,32,32] for i,p in enumerate(images)},indent=2)+'\n')
print('Generated native pixel assets:',len(images),'items')
