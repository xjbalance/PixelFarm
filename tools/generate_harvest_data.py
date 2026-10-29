"""Authoritative, reproducible expansion definitions. Existing item IDs remain owned by their catalogs."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'resources/harvest';OUT.mkdir(parents=True,exist_ok=True)
data={'version':1,'crops':{},'orchard':{},'items':{},'stations':{},'processing':{},'recipes':{},'future':[]}
def item(id,name,sell_price,kind='processed',description='',**extra):
    data['items'][id]={'name':name,'sell_price':sell_price,'kind':kind,'description':description,'icon':f'res://assets/harvest/items/{id}.png',**extra}
# id, name, season, growth days, seed cost, harvest value, harvest quantity, unlock, silhouette
rows='''strawberry,草莓,0,4,20,28,2,basic,berry
cabbage,卷心菜,0,4,22,62,1,basic,cabbage
radish,白萝卜,0,3,14,42,1,basic,root
peas,豌豆,0,3,16,25,2,basic,pod
spinach,菠菜,0,2,10,28,1,basic,leaf
rapeseed,油菜,0,4,16,46,1,cooperative,oilflower
garlic_shoot,蒜苗,0,3,12,34,1,basic,stalk
tomato,番茄,1,4,22,31,2,basic,tomato
cucumber,黄瓜,1,3,16,24,2,basic,cucumber
corn,玉米,1,4,20,58,1,basic,corn
chili,辣椒,1,4,24,34,2,cooperative,chili
eggplant,茄子,1,4,20,57,1,basic,eggplant
watermelon,西瓜,1,6,38,110,1,cooperative,melon
blueberry,蓝莓,1,5,24,24,3,cooperative,cluster
sunflower_crop,向日葵,1,5,24,68,1,basic,sunflower
pumpkin,南瓜,2,6,32,94,1,basic,pumpkin
sweet_potato,红薯,2,4,20,56,1,basic,tuber
rice_crop,水稻,2,4,18,52,1,basic,grain
soybean,大豆,2,4,18,50,1,basic,beans
grape,葡萄,2,5,26,25,3,cooperative,grape
peanut,花生,2,4,22,60,1,cooperative,peanut
cotton,棉花,2,5,24,70,1,cooperative,cotton
winter_kale,冬甘蓝,3,4,22,60,1,basic,kale
snow_radish,雪萝卜,3,3,16,44,1,basic,snowroot
winter_onion,冬葱,3,3,14,40,1,basic,onion
frost_peas,耐寒豌豆,3,4,18,26,2,basic,frostpod
winter_cabbage,冬白菜,3,5,26,76,1,basic,lettuce
lavender,薰衣草,0|1,4,18,52,1,basic,lavender
rose,玫瑰,0|1|2,5,26,74,1,cooperative,rose
chamomile,洋甘菊,0|2,3,14,40,1,basic,daisy'''
for line in rows.splitlines():
    id,name,seasons,days,cost,value,yield_,unlock,shape=line.split(',')
    data['crops'][id]={'name':name,'seasons':[int(s) for s in seasons.split('|')],'growth_days':int(days),'seed_price':int(cost),'sell_price':int(value),'harvest_quantity':int(yield_),'watering':'daily','stages':4,'unlock':unlock,'shape':shape,'tags':['flower' if id in ['lavender','rose','chamomile'] else 'crop'],'gift_to':'linya','description':name+'可用于工坊加工、料理或赠送村民；非适种季节暂停生长，植株保留。'}
for id,name,seasons,days,cost,value in [('apple','苹果',[2],10,240,36),('pear','梨',[2],10,240,38),('peach','桃',[1],12,280,42),('orange','橙',[3],12,280,44)]:
    data['orchard'][id]={'name':name+'树','fruit':id,'seasons':seasons,'growth_days':days,'regrow_days':3,'yield':2,'sapling_price':cost,'unlock':'cooperative'}
    item(id,name,value,'fruit',f'成熟{name}树在结果季每三天结两份果实；可加工、烹饪或赠礼。',gift_to='linya')
    item(id+'_sapling',name+'树苗',0,'sapling',f'在建造模式的果园分组栽种；{days}天长成，不需每日浇水。',price=cost)
stations=[('mill','磨坊',{'wood':8,'stone':6},80),('oil_press','榨油机',{'wood':12,'stone':8,'copper_bar':2},180),('pickle_jar','腌制罐',{'stone':8,'wood':4},100),('jam_pot','果酱锅',{'wood':6,'stone':8,'copper_bar':1},100),('juicer','果汁机',{'wood':10,'copper_bar':2},160),('drying_rack','烘干架',{'wood':10,'stone':4},100),('cheese_table','奶制品加工台',{'wood':10,'stone':4,'copper_bar':1},120),('egg_table','蛋制品加工台',{'wood':8,'stone':4},120),('loom','纺织机',{'wood':18,'iron_bar':2},280),('smoker','熏制炉',{'wood':8,'stone':10,'iron_bar':1},160)]
for id,name,required,coins in stations:
    data['stations'][id]={'name':name,'required':required,'coins':coins,'size':[1,1],'icon':f'res://assets/harvest/stations/{id}.png','unlock':'basic','description':'在农场建造模式中摆放；每台设备一次加工一批，完成后留在输出槽。'}
# Existing prices are consulted, never overwritten.
prices={'carrot':36,'potato':56,'wheat':22,'wood':3,'stone':2}
for path,section in [('resources/kitchen/kitchen.json','items'),('resources/livestock/livestock.json','items'),('resources/aquaculture/fish.json','items'),('resources/fishing/fishing.json','items'),('resources/exploration/exploration.json','items')]:
    prices.update({k:int(v['sell_price']) for k,v in json.loads((ROOT/path).read_text())[section].items()})
prices.update({k:v['sell_price'] for k,v in data['crops'].items()})
prices.update({k:v['sell_price'] for k,v in data['items'].items()})
def process(id,name,station,inputs,output=None,quantity=1,minutes=120,shape='jar',color='gold',price=None):
    output=output or id
    value=price if price is not None else max(1,int(sum(prices[k]*v for k,v in inputs.items())*1.22/quantity))
    if output not in prices:
        item(output,name,value,description='可出售或赠礼；在工坊查看后续配方。',shape=shape,color=color,gift_to='ahe');prices[output]=value
    data['processing'][id]={'recipe_id':id,'name':name,'output_item_id':output,'output_quantity':quantity,'input_items':inputs,'processing_station_id':station,'processing_duration':minutes,'unlock_condition':'basic','sell_value':prices[output],'category':station,'description':'按游戏内时间加工，离场与保存不重置进度。'}
process('mill_flour','研磨面粉','mill',{'wheat':1},'flour',minutes=45)
process('rice','精制大米','mill',{'rice_crop':1},minutes=45,shape='sack')
process('cornmeal','玉米粉','mill',{'corn':1},minutes=45,shape='sack')
process('tofu','鲜豆腐','mill',{'soybean':1},minutes=60,shape='tofu',color='cream')
process('corn_feed','玉米饲料','mill',{'corn':1},'hay',8,45)
for crop,out,name in [('rapeseed','canola_oil','菜籽油'),('peanut','peanut_oil','花生油'),('sunflower_crop','sunflower_oil','葵花籽油')]: process(out,name,'oil_press',{crop:2},minutes=180,shape='bottle')
for crop,out,name in [('cucumber','pickled_cucumber','腌黄瓜'),('cabbage','kimchi','泡菜'),('radish','pickled_radish','腌萝卜'),('snow_radish','snow_pickle','雪萝卜泡菜'),('winter_cabbage','winter_pickle','冬白菜泡菜')]: process(out,name,'pickle_jar',{crop:2},minutes=1440,color='leaf')
for crop,out,name,color in [('tomato','tomato_sauce','番茄酱','roof'),('chili','chili_sauce','辣椒酱','roof'),('pumpkin','pumpkin_puree','南瓜泥','gold'),('strawberry','strawberry_jam','草莓果酱','flower'),('blueberry','blueberry_jam','蓝莓果酱','star'),('peach','peach_jam','桃子果酱','flower')]: process(out,name,'jam_pot',{crop:2},minutes=240,color=color)
for crop,out,name,color in [('grape','grape_juice','葡萄汁','star'),('apple','apple_juice','苹果汁','gold'),('pear','pear_juice','梨汁','cream'),('orange','orange_juice','橙汁','roof'),('watermelon','watermelon_juice','西瓜汁','flower')]: process(out,name,'juicer',{crop:2},minutes=90,shape='bottle',color=color)
for crop,out,name,color in [('grape','raisins','葡萄干','star'),('sweet_potato','dried_sweet_potato','红薯干','roof'),('pear','dried_pear','梨干','gold'),('spinach','dried_spinach','菠菜干','leaf'),('winter_kale','dried_kale','甘蓝干','leaf'),('garlic_shoot','soup_herbs','蒜苗汤料','leaf'),('winter_onion','onion_flakes','冬葱干','leaf'),('eggplant','dried_eggplant','茄子干','star'),('peas','dried_peas','豌豆干','leaf'),('frost_peas','frost_pea_flakes','寒豌豆汤料','teal')]: process(out,name,'drying_rack',{crop:2},minutes=180,shape='tray',color=color)
process('lavender_bundle','干薰衣草','drying_rack',{'lavender':2},minutes=180,shape='bundle',color='star')
process('rose_petals','干玫瑰花瓣','drying_rack',{'rose':2},minutes=180,shape='tray',color='flower')
process('chamomile_dried','干洋甘菊','drying_rack',{'chamomile':2},minutes=180,shape='bundle',color='cream')
process('mayonnaise','蛋黄酱','egg_table',{'egg':2},minutes=120,color='cream')
for id,name,inputs,shape in [('butter','黄油',{'milk':1},'butter'),('dairy_cheese','河湾奶酪',{'milk':2},'cheese'),('yogurt','酸奶',{'milk':1},'cup')]: process(id,name,'cheese_table',inputs,'cheese' if id=='dairy_cheese' else id,minutes=360,shape=shape,color='cream')
process('wool_cloth','毛布','loom',{'wool':2},minutes=360,shape='cloth',color='cream')
process('cotton_cloth','棉布','loom',{'cotton':2},minutes=360,shape='cloth',color='teal')
process('sachet','薰衣草香包','loom',{'lavender_bundle':1,'cotton_cloth':1},minutes=180,shape='sachet',color='star')
process('rose_perfume','玫瑰香水','juicer',{'rose_petals':1,'canola_oil':1},minutes=240,shape='perfume',color='flower')
for fish in ['fish_carp','fish_crucian']:
    process('smoke_'+fish,'烟熏湖鲜','smoker',{fish:2,'wood':1},'smoked_fish',minutes=180)
    process('dry_'+fish,'风干湖鲜','drying_rack',{fish:2},'dried_fish',minutes=240)
def dish(id,name,inputs,energy=24,buff='',shape='bowl',color='gold'):
    value=int(sum(prices[k]*v for k,v in inputs.items())*1.12)
    item(id,name,value,'food',f'恢复{energy}体力；已有增益不叠加或刷新。',energy=energy,buff=buff,seconds={'speed':120,'thrift':90,'mining':90,'fishing':120}.get(buff,0),shape=shape,color=color,gift_to='ahe');prices[id]=value
    data['recipes'][id]={'recipe_id':id,'name':name,'required':inputs,'rewards':{id:1},'facility':'','unlock':'basic','hint':'在住宅厨房制作；材料不足时不扣除。','output_item_id':id,'output_quantity':1,'input_items':inputs,'processing_station_id':'kitchen','processing_duration':0,'unlock_condition':'basic','sell_value':value,'category':'drinks' if shape=='cup' else 'baking' if shape in ['bread','cake','pie','cookie'] else 'meals'}
dish('bread','麦香面包',{'flour':2},24,shape='bread')
dish('noodles','手工面条',{'flour':2,'egg':1},26,shape='noodles')
dish('cake','田园蛋糕',{'flour':2,'egg':2,'milk':1},40,'thrift','cake')
dish('pumpkin_pie','南瓜派',{'pumpkin_puree':1,'flour':2,'butter':1},42,'mining','pie')
dish('strawberry_cake','草莓蛋糕',{'strawberry_jam':1,'flour':2,'egg':1,'milk':1},40,'thrift','cake','flower')
dish('tomato_pasta','番茄意面',{'noodles':1,'tomato_sauce':1,'canola_oil':1},38,'speed','noodles','roof')
dish('vegetable_soup','田园蔬菜汤',{'cabbage':1,'spinach':1,'potato':1},28,color='leaf')
dish('tofu_soup','豆腐汤',{'tofu':1,'winter_onion':1},26,color='cream')
dish('cooked_rice','香米饭',{'rice':1},22,shape='rice',color='cream')
dish('fish_rice','湖鲜鱼肉饭',{'rice':1,'fish_carp':1,'soup_herbs':1},36,'fishing','rice')
dish('rice_ball','田园饭团',{'rice':1,'peas':1},26,shape='riceball',color='cream')
dish('corn_cake','玉米饼',{'cornmeal':1,'egg':1},28,shape='pancake')
dish('corn_bread','玉米面包',{'cornmeal':1,'flour':1},28,shape='bread')
dish('cheese_bread','奶酪面包',{'flour':2,'cheese':1},38,'mining','bread')
dish('roast_sweet_potato','烤红薯',{'sweet_potato':1},20,shape='tuber',color='roof')
dish('fruit_salad','水果沙拉',{'apple':1,'pear':1,'blueberry':1},30,shape='salad',color='flower')
dish('cream_stew','奶油炖菜',{'butter':1,'milk':1,'potato':1,'carrot':1},42,'mining')
dish('herbal_tea','香草茶',{'lavender_bundle':1},22,'fishing','cup','star')
dish('rose_tea','玫瑰花茶',{'rose_petals':1},24,shape='cup',color='flower')
dish('chamomile_tea','洋甘菊茶',{'chamomile_dried':1},22,shape='cup',color='cream')
dish('vegetable_pancake','蔬菜煎饼',{'flour':1,'egg':1,'garlic_shoot':1},30,'thrift','pancake','leaf')
dish('mixed_juice','缤纷混合果汁',{'apple_juice':1,'orange_juice':1,'grape_juice':1},34,shape='cup',color='flower')
dish('apple_pie','苹果派',{'apple':2,'flour':2,'butter':1},38,shape='pie')
dish('tofu_vegetables','田园蔬菜豆腐',{'tofu':1,'eggplant':1,'peanut_oil':1},34,'thrift',color='leaf')
dish('winter_soup','暖冬蔬菜汤',{'winter_cabbage':1,'snow_radish':1,'frost_peas':1},30,color='teal')
dish('farm_fish_soup','葱香鲫鱼汤',{'fish_crucian':1,'winter_onion':1,'radish':1},32,'fishing',color='cream')
dish('sunflower_salad','葵香拌蔬菜',{'sunflower_oil':1,'tomato':1,'cucumber':1},30,color='leaf')
data['future']=[{'recipe_id':'salted_duck_egg','source':'duck_egg','reason':'当前只有鸡、牛、羊的实际养殖；鸭尚未实现。'},{'recipe_id':'goat_cheese','source':'goat_milk','reason':'当前没有山羊产奶玩法。'},{'recipe_id':'honey_cookie','source':'honey','reason':'当前没有可生产蜂蜜的蜂箱。'},{'recipe_id':'truffle_sauce','source':'truffle','reason':'当前没有猪与松露生产玩法。'},{'recipe_id':'mushroom_soup','source':'mushroom','reason':'当前没有可食用蘑菇的合法采集来源。'}]
# Resolve actual uses for crop descriptions and validation.
for id,crop in data['crops'].items():
    crop['uses']=[r for r,v in {**data['processing'],**data['recipes']}.items() if id in v['input_items']]
    crop['description']+=' 用途：'+'、'.join(({**data['processing'],**data['recipes']})[r]['name'] for r in crop['uses'])+'。'
(OUT/'harvest.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
print(f"Harvest: {len(data['crops'])} field crops/flowers, {len(data['orchard'])} trees, {len(data['stations'])} stations, {len(data['processing'])} processes, {len(data['recipes'])} dishes, {len(data['items'])} items")
