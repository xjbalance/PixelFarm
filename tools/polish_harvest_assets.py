"""0.8.1 native-pixel finish pass; preserves IDs, canvas sizes and the existing 89-color palette."""
from pathlib import Path
from PIL import Image,ImageDraw
import argparse,json,math
import generate_harvest_assets as old
from world_palette import CONFIG,harmonize,grade
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/harvest';D=old.D;P=old.P
INK=P['outline'][1];DARK=P['wood_earth'][0];LEAF=P['leaf'][2];GREEN=P['leaf'][4];LIGHT=P['leaf'][7];CREAM=P['cream'][-2]

def finish(image):
    """Facet existing flat material regions, using at most one adjacent ramp step."""
    im=harmonize(image);original=im.copy();src=original.load();dst=im.load()
    ramps={tuple(bytes.fromhex(c)): (family,i) for family,colors in CONFIG['ramps'].items() for i,c in enumerate(colors)}
    for y in range(1,im.height-1):
        for x in range(1,im.width-1):
            value=src[x,y]
            if value[3]==0 or value[:3] not in ramps:continue
            family,index=ramps[value[:3]];ramp=CONFIG['ramps'][family]
            if family=='outline' or index<=0 or index>=len(ramp)-1:continue
            # Shade broad contiguous faces only; thin stems, labels and line art stay intact.
            if src[x-1,y]!=value or src[x+1,y]!=value:continue
            target=None
            if src[x,y+1][3]>0 and src[x,y+1][:3]!=value[:3] and y>im.height*.45:target=ramp[index-1]
            elif src[x,y-1][3]>0 and src[x,y-1][:3]!=value[:3] and x<im.width*.65:target=ramp[index+1]
            if target:dst[x,y]=tuple(bytes.fromhex(target))+(value[3],)
    return im

def produce(id):
    if id not in ['carrot','potato','wheat','strawberry']:return finish(old.produce(id))
    im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
    if id=='strawberry':
        for x,y,w,h in [(7,14,12,14),(18,7,9,12)]:
            d.polygon([(x+2,y),(x+w-2,y),(x+w,y+3),(x+w-2,y+8),(x+w//2,y+h),(x+1,y+7),(x,y+3)],fill=P['roof'][0])
            d.polygon([(x+2,y+1),(x+w-3,y+1),(x+w-1,y+3),(x+w-3,y+8),(x+w//2,y+h-2),(x+2,y+6)],fill=P['roof'][3])
            d.line((x+3,y+2,x+2,y+5),fill=P['flower'][-2],width=2)
            for a,b in [(4,5),(7,7),(5,10)]:
                if a<w-1 and b<h-1:d.point((x+a,y+b),fill=P['gold'][-1])
            d.polygon([(x,y),(x+3,y-3),(x+5,y-1),(x+w-1,y-3),(x+w,y+1),(x+5,y+2)],fill=LEAF)
            d.line((x+3,y,x+6,y),fill=LIGHT)
    elif id=='carrot':
        d.polygon([(10,13),(23,10),(24,15),(18,25),(12,29),(8,28),(9,20)],fill=DARK)
        d.polygon([(11,14),(22,12),(22,16),(17,24),(10,27),(11,21)],fill=P['roof'][4])
        d.line((12,16,11,22),fill=P['gold'][-1],width=2);d.line((18,18,21,17),fill=P['roof'][2]);d.line((15,23,17,22),fill=P['roof'][2])
        old.leaf(d,18,12,-1);old.leaf(d,19,11,1);d.line((18,11,19,3),fill=GREEN,width=2)
    elif id=='potato':
        for x,y,w,h in [(5,15,14,12),(15,8,13,14)]:
            d.ellipse((x,y,x+w,y+h),fill=DARK);d.ellipse((x+1,y+1,x+w-1,y+h-1),fill=P['wood_earth'][5]);d.arc((x+2,y+2,x+w-2,y+h-3),190,290,fill=P['gold'][-1],width=2)
            for a,b in [(4,5),(8,8)]:d.point((x+a,y+b),fill=P['wood_earth'][1])
    else:
        for x,top in [(8,7),(16,3),(23,9)]:
            d.line((x,top+3,16,29),fill=P['gold'][0],width=2)
            for y in range(top,top+12,4):
                d.polygon([(x,y),(x-4,y+1),(x-2,y+4),(x+1,y+4),(x+4,y)],fill=P['gold'][2]);d.line((x-2,y+1,x,y+2),fill=P['gold'][-1])
        d.line((12,25,20,25),fill=P['wood_earth'][1],width=2)
    return harmonize(im)

def flour():
    im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
    d.polygon([(8,6),(24,6),(23,12),(27,25),(24,29),(7,29),(4,26),(8,12)],fill=DARK)
    d.polygon([(9,7),(23,7),(21,12),(25,25),(23,27),(8,27),(6,25),(10,12)],fill=P['cream'][4])
    d.polygon([(10,11),(13,12),(10,24),(8,26),(7,24)],fill=P['cream'][-1]);d.polygon([(21,12),(24,24),(22,26),(20,17)],fill=P['cream'][2])
    d.rectangle((8,6,24,9),fill=P['wood_earth'][4]);d.line((9,6,23,6),fill=P['wood_earth'][-2]);d.line((9,11,22,11),fill=P['wood_earth'][0])
    d.rectangle((12,16,21,23),fill=P['cream'][-1]);d.line((16,16,16,22),fill=P['gold'][0])
    for y in [17,20]:d.line((13,y-1,16,y+1),fill=P['gold'][1]);d.line((16,y+1,19,y-1),fill=P['gold'][1])
    return harmonize(im)

def bread(id,info):
    im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
    d.ellipse((3,22,29,29),fill=P['stone'][1]);d.ellipse((4,21,28,27),fill=CREAM);d.line((7,27,25,27),fill=P['cream'][2])
    d.rounded_rectangle((5,7,27,24),radius=6,fill=DARK);d.rounded_rectangle((6,7,26,22),radius=5,fill=P['wood_earth'][2])
    d.rounded_rectangle((7,8,25,19),radius=4,fill=P['gold'][2]);d.line((10,9,22,9),fill=P['gold'][-1]);d.line((8,12,8,17),fill=P['gold'][4])
    for x in [12,18,24]:
        d.line((x,11,x-3,16),fill=P['wood_earth'][0],width=2);d.line((x-1,11,x-4,15),fill=P['cream'][-2])
    if id=='corn_bread':
        for x,y in [(11,18),(15,20),(22,18)]:d.rectangle((x,y,x+2,y+1),fill=P['gold'][-1])
    if id=='cheese_bread':
        d.polygon([(16,8),(25,11),(21,16)],fill=P['gold'][-1]);d.rectangle((20,11,21,12),fill=P['gold'][0]);d.point((21,14),fill=P['gold'][0])
    if id=='potato_bread':d.rectangle((7,19,11,21),fill=P['cream'][3]);d.point((9,20),fill=P['wood_earth'][1])
    return harmonize(im)

def product(id,info):
    if id=='flour':return flour()
    if id in ['bread','corn_bread','cheese_bread','potato_bread']:return bread(id,info)
    if info.get('kind')=='fruit':return produce(id)
    im=finish(old.product(id,info));d=ImageDraw.Draw(im)
    shape=info.get('shape','')
    if shape in ['jar','bottle','perfume']:
        # Clear rim, liquid surface, single reflected light and a weighted glass base.
        x=10 if shape in ['bottle','perfume'] else 7
        d.line((x+1,10,31-x,10),fill=P['cream'][-1]);d.line((x+2,26,30-x,26),fill=P['wood_earth'][1]);d.point((x+3,13),fill=P['cream'][-1])
    elif shape=='cloth':
        d.line((8,23,12,26),fill=P['cream'][2]);d.line((12,25,24,22),fill=P['cream'][-1])
    return harmonize(im)

def bush(d,height,spread,ripe=False):
    base=34;top=base-height
    d.line((16,base,16,top),fill=P['leaf'][0],width=2)
    for y,side in [(base-5,-1),(base-9,1),(top+3,-1),(top,1)]:
        x=16+side*spread
        d.line((16,y+3,x,y),fill=LEAF,width=2)
        d.ellipse((x-4,y-3,x+3,y+1),fill=LEAF);d.line((x-2,y-2,x+2,y-2),fill=LIGHT if ripe else GREEN)

def crop_sheet(id):
    shape=D['crops'].get(id,{}).get('shape',{'carrot':'root','potato':'tuber','wheat':'grain'}.get(id,'leaf'))
    sheet=Image.new('RGBA',(128,40))
    for stage in range(4):
        im=Image.new('RGBA',(32,40));d=ImageDraw.Draw(im)
        d.line((12,35,20,35),fill=P['wood_earth'][0])
        if stage==0:
            d.line((16,34,16,28),fill=LEAF,width=2);d.polygon([(16,29),(11,25),(8,26),(10,29),(16,31)],fill=GREEN);d.polygon([(16,28),(20,24),(23,25),(21,28)],fill=LIGHT)
        elif shape in ['grain','corn','sunflower','oilflower','stalk','onion']:
            height=min(32,10+stage*8)
            if shape=='grain':
                for x in [9,16,23]:
                    top=34-height+(3 if x!=16 else 0);d.line((x,34,x,top),fill=LEAF if stage<3 else P['gold'][1],width=2)
                    if stage==3:
                        for y in range(top,top+12,3):d.line((x-2,y,x+2,y),fill=P['gold'][3],width=2);d.point((x-2,y),fill=P['gold'][-1])
                    else:old.leaf(d,x,top+4,-1)
            elif shape in ['stalk','onion']:
                for x,lean in [(10,-2),(16,1),(22,3)]:
                    d.line((x,34,x+lean,34-height),fill=LEAF,width=3);d.line((x,32,x+lean,36-height),fill=LIGHT)
                    if stage==3:d.rectangle((x-1,29,x+1,34),fill=CREAM)
            else:
                d.line((16,34,16,34-height),fill=LEAF,width=2)
                for y in [29,23,17][:stage+1]:
                    old.leaf(d,16,y,-1);old.leaf(d,17,y-3,1)
                if stage==3 and shape=='corn':
                    d.ellipse((18,16,24,29),fill=P['gold'][0]);d.ellipse((18,16,23,27),fill=P['gold'][3]);d.line((19,18,19,25),fill=P['gold'][-1])
                elif stage>=2 and shape=='sunflower':
                    y=34-height
                    if stage==3:
                        d.ellipse((8,y,24,y+15),fill=P['gold'][1]);d.ellipse((9,y,23,y+13),fill=P['gold'][3]);d.ellipse((12,y+3,20,y+10),fill=DARK);d.point((14,y+5),fill=P['gold'][0])
                    else:d.rectangle((13,y,19,y+5),fill=GREEN)
                elif stage==3 and shape=='oilflower':
                    for x,y in [(10,10),(20,8),(16,3)]:d.rectangle((x-2,y,x+2,y+3),fill=P['gold'][-1]);d.point((x,y+1),fill=P['gold'][1])
        elif shape in ['root','snowroot','tuber','cabbage','kale','lettuce','leaf','melon','pumpkin']:
            if stage<3:
                bush(d,8+stage*3,3+stage*2)
                if shape in ['cabbage','kale','lettuce','leaf']:
                    d.ellipse((9-stage,25-stage*2,23+stage,35),fill=LEAF);d.arc((10-stage,24-stage*2,23,33),190,325,fill=LIGHT,width=2)
            else:
                if shape in ['melon','pumpkin','cabbage','kale','lettuce','leaf']:
                    icon=produce(id);im.alpha_composite(icon,(0,6))
                    # No extra generic stem above low rosettes / ground fruit.
                else:
                    bush(d,17,7,True)
                    col=P['roof'][4] if id=='carrot' else CREAM if shape in ['root','snowroot'] else P['wood_earth'][5] if id=='potato' else P['roof'][2]
                    if id=='carrot':
                        d.polygon([(10,27),(22,27),(19,34),(16,37),(12,33)],fill=DARK);d.polygon([(12,28),(21,28),(18,33),(16,35),(13,32)],fill=col);d.line((13,28,14,32),fill=P['gold'][-1])
                    elif id=='potato':
                        d.ellipse((7,28,18,36),fill=DARK);d.ellipse((8,28,17,34),fill=col);d.ellipse((16,27,25,35),fill=DARK);d.ellipse((17,27,24,33),fill=P['wood_earth'][-2]);d.point((13,31),fill=P['wood_earth'][1])
                    else:
                        d.ellipse((10,28,22,36),fill=DARK);d.ellipse((11,28,21,34),fill=col);d.line((13,29,17,29),fill=P['cream'][-1])
        elif shape in ['lavender','rose','daisy']:
            bush(d,7+stage*5,5)
            if stage==3:im.alpha_composite(produce(id),(0,6))
            elif stage==2:
                for x,y in [(10,19),(20,15)]:d.rectangle((x,y,x+2,y+2),fill=P['star'][2] if shape=='lavender' else P['flower'][1])
        else:
            height=9+stage*5 if shape not in ['berry','cluster','cotton','beans','peanut'] else 7+stage*4
            if shape in ['grape','cucumber','pod','frostpod']:d.line((17,35,17,7),fill=P['wood_earth'][2],width=2)
            bush(d,height,5+stage,stage==3)
            if stage==2:d.rectangle((12,21,14,23),fill=CREAM);d.point((13,22),fill=P['gold'][2])
            if stage==3:
                if shape=='berry':
                    for x,y in [(7,25),(18,27),(14,18)]:
                        d.polygon([(x,y),(x+5,y),(x+6,y+3),(x+3,y+7),(x,y+4)],fill=P['roof'][2]);d.line((x+1,y+1,x+4,y+1),fill=P['roof'][-1]);d.point((x+2,y+4),fill=P['gold'][-1])
                elif shape in ['tomato','cluster','grape','cotton']:
                    col=P['roof'][3] if shape=='tomato' else CREAM if shape=='cotton' else P['star'][2]
                    for x,y in [(6,23),(20,24),(12,16)]:
                        d.ellipse((x,y,x+6,y+6),fill=INK);d.ellipse((x+1,y,x+5,y+4),fill=col);d.point((x+2,y+1),fill=P['cream'][-1])
                elif shape in ['pod','frostpod','cucumber','chili','eggplant']:
                    col=P['roof'][3] if shape=='chili' else P['star'][2] if shape=='eggplant' else P['teal'][2] if shape=='frostpod' else GREEN
                    for x,y in [(7,22),(21,17)]:
                        d.ellipse((x,y,x+5,y+11),fill=INK);d.ellipse((x+1,y,x+4,y+9),fill=col);d.line((x+2,y+2,x+2,y+6),fill=LIGHT if shape not in ['eggplant','chili'] else P['cream'][3])
                else:
                    for x,y in [(7,28),(14,30),(22,27)]:d.ellipse((x-2,y-1,x+3,y+3),fill=P['gold'][2]);d.point((x,y),fill=CREAM)
        sheet.alpha_composite(harmonize(im),(stage*32,0))
    return sheet

def station(id):
    im=finish(old.station(id));d=ImageDraw.Draw(im)
    # Keep the original feet/occupation; refine common workbench perspective and joinery.
    if id not in ['pickle_jar','smoker']:
        d.line((5,38,26,38),fill=DARK);d.line((7,39,7,43),fill=P['wood_earth'][3]);d.line((25,39,25,43),fill=P['wood_earth'][2])
        d.line((5,29,27,29),fill=P['wood_earth'][-2]);d.line((9,33,18,33),fill=P['wood_earth'][2]);d.point((24,34),fill=P['gold'][3])
    if id=='jam_pot':
        d.rectangle((4,12,27,28),fill=(0,0,0,0))
        d.rounded_rectangle((5,12,27,29),radius=5,fill=DARK);d.rounded_rectangle((6,13,26,27),radius=5,fill=P['roof'][2]);d.rounded_rectangle((7,13,25,23),radius=4,fill=P['roof'][4])
        d.ellipse((5,10,27,18),fill=DARK);d.ellipse((6,10,26,16),fill=P['gold'][1]);d.ellipse((8,12,24,16),fill=P['flower'][0]);d.line((8,11,20,11),fill=P['cream'][-2]);d.line((8,19,8,23),fill=P['roof'][-1],width=2)
        d.arc((1,15,9,23),90,270,fill=DARK,width=2);d.arc((24,15,31,23),270,90,fill=DARK,width=2);d.line((22,14,27,4),fill=P['wood_earth'][1],width=2);d.point((26,5),fill=P['wood_earth'][-2])
    elif id=='drying_rack':
        for y in [9,18,27]:d.rectangle((8,y,24,y+3),fill=(0,0,0,0))
        for y in [13,22,30]:d.line((7,y,25,y),fill=P['wood_earth'][3],width=2)
    elif id=='mill':
        d.arc((5,13,27,24),0,180,fill=P['stone'][0],width=2);d.line((8,15,22,15),fill=P['stone'][-2]);d.line((10,8,20,8),fill=DARK)
    elif id=='cheese_table':d.line((9,15,9,23),fill=P['cream'][-1]);d.arc((7,10,18,16),180,310,fill=P['stone'][-1])
    elif id=='smoker':d.line((9,12,9,35),fill=P['stone'][3]);d.line((10,28,23,28),fill=P['stone'][0]);d.point((22,20),fill=P['gold'][3])
    return harmonize(im)

def working_frames():
    atlas=Image.new('RGBA',(128,len(D['stations'])*56));manifest={}
    for row,id in enumerate(D['stations']):
        manifest[id]={'row':row,'frames':4,'fps':4,'frame_size':[32,56],'padding_top':8}
        for frame in range(4):
            im=Image.new('RGBA',(32,56));im.alpha_composite(station(id),(0,8));d=ImageDraw.Draw(im)
            if id=='mill':
                d.rectangle((26,23,30,29),fill=(0,0,0,0))
                d.ellipse((6,21,26,30),fill=P['stone'][3]);d.line((9,23,21,23),fill=P['stone'][-2])
                dx,dy=[(10,0),(0,5),(-9,0),(0,-5)][frame]
                d.line((16,27,16+dx,27+dy),fill=DARK,width=2);d.rectangle((15+dx,25+dy,17+dx,28+dy),fill=P['wood_earth'][3]);d.point((16,27),fill=P['gold'][-1])
            elif id=='oil_press':
                y=27+[0,1,2,1][frame];d.rectangle((11,y,23,y+2),fill=P['gold'][1]);d.line((12,y,22,y),fill=P['gold'][-1]);d.point((17,22+frame),fill=P['gold'][2])
            elif id in ['jam_pot','smoker','pickle_jar']:
                x=23 if id=='smoker' else 15;y=8-frame*2
                color=P['stone'][3] if id=='smoker' else P['cream'][-2]
                d.rectangle((x-1+(frame%2),y,x+1+(frame%2),y+1),fill=color)
                d.point((x-3,y+3),fill=P['cream'][3]);d.point((x+3,9-frame),fill=color)
            elif id=='loom':
                x=[9,14,19,14][frame];d.rectangle((x,28,x+4,30),fill=P['wood_earth'][0]);d.line((x,28,x+3,28),fill=P['cream'][-1]);d.point((13+frame,36),fill=P['teal'][-1])
            elif id=='drying_rack':
                for x,y in [(10,17),(18,17),(10,26),(18,35)]:
                    d.rectangle((x,y,x+4,y+3),fill=P['roof'][3]);d.line((x,y,x+3,y),fill=P['gold'][3]);d.point((x+frame%2,y+4),fill=P['wood_earth'][1])
            elif id=='egg_table':
                x=[22,24,22,20][frame];d.line((15,28,x,17),fill=P['wood_earth'][2],width=2);d.arc((10,25,19,30),frame*90,frame*90+120,fill=P['gold'][2])
            elif id=='juicer':
                d.line((12,25,21,25),fill=P['gold'][-1]);d.point((13+frame*2,27),fill=P['cream'][-1]);d.point((21-frame,30),fill=P['roof'][4])
            else:
                d.point((11+frame%2,24-frame),fill=P['cream'][-1]);d.point((14,20+frame),fill=P['cream'][2]);d.line((10,35,14+frame,35),fill=P['gold'][-1])
            atlas.alpha_composite(harmonize(im),(frame*32,row*56))
    old.save(atlas,OUT/'workshop_work.png')
    (ROOT/'resources/presentation/workshop_visuals.json').write_text(json.dumps({'texture':'res://assets/harvest/workshop_work.png','stations':manifest},ensure_ascii=False,indent=2)+'\n')

def seed(id):
    im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
    d.rectangle((6,3,26,29),fill=DARK);d.rectangle((7,4,25,28),fill=CREAM);d.line((7,4,24,4),fill=P['cream'][-1]);d.rectangle((23,8,25,27),fill=P['cream'][3]);d.rectangle((7,5,25,8),fill=P['wood_earth'][4]);d.line((9,6,23,6),fill=P['wood_earth'][-2])
    im.alpha_composite(produce(id).resize((18,18),Image.NEAREST),(7,9));return harmonize(im)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--sample',action='store_true');args=parser.parse_args()
    crop_ids=['strawberry'] if args.sample else list(D['crops'])+['carrot','potato','wheat']
    for id in crop_ids:
        old.save(produce(id),OUT/'items'/f'{id}.png');old.save(seed(id),OUT/'items'/f'{id}_seed.png')
        if id in D['crops']:old.save(crop_sheet(id),OUT/'crops'/f'{id}.png')
    for id,info in D['items'].items():
        if args.sample and id not in ['bread','mayonnaise']:continue
        if info['kind']=='device':
            image=Image.new('RGBA',(32,32));image.alpha_composite(station(info['station']).resize((20,30),Image.NEAREST),(6,1))
        else:image=product(id,info)
        old.save(image,OUT/'items'/f'{id}.png')
    for id in (['jam_pot'] if args.sample else D['stations']):old.save(station(id),OUT/'stations'/f'{id}.png')
    old.save(flour(),ROOT/'assets/kitchen/flour.png')
    if not args.sample:
        working_frames()
        atlas=Image.new('RGBA',(128,120))
        for row,id in enumerate(['carrot','potato','wheat']):atlas.alpha_composite(crop_sheet(id),(0,row*40))
        old.save(atlas,ROOT/'assets/crops/crops.png')
        reference=Image.open(ROOT/'tools/art_source/agriculture080.png').convert('RGBA');lookup=json.loads((ROOT/'tools/art_source/agriculture080.json').read_text())
        for name,rect in lookup.items():
            if name=='assets/kitchen/flour.png':continue
            x,y,w,h=rect;source=reference.crop((x,y,x+w,y+h));id=Path(name).stem
            image=bread(id,{}) if id=='potato_bread' else harmonize(source) if w>32 else finish(source)
            old.save(image,ROOT/name)
    files=sorted((OUT/'items').glob('*.png'));atlas=Image.new('RGBA',(640,math.ceil(len(files)/16)*48))
    for i,p in enumerate(files):atlas.alpha_composite(Image.open(p).convert('RGBA'),((i%16)*40+4,(i//16)*48+4))
    old.save(atlas,OUT/'item_atlas.png');(OUT/'item_atlas.json').write_text(json.dumps({p.stem:[(i%16)*40+4,(i//16)*48+4,32,32] for i,p in enumerate(files)},indent=2)+'\n')
    print('0.8.1 pixel finish:', 'sample' if args.sample else 'all agriculture assets')

if __name__=='__main__':main()
