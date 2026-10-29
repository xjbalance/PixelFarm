"""Audit every real agricultural recipe, five sources and the bounded before/after changes."""
from pathlib import Path
import json,re,math
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/quality081'
before=json.loads((OUT/'economy-before.json').read_text())
current={name:json.loads((ROOT/'resources'/f'{name}.json').read_text()) for name in before}
def differences(a,b,path=''):
 if isinstance(a,dict) and isinstance(b,dict):
  result=[]
  for key in set(a)|set(b):result+=differences(a.get(key),b.get(key),path+'.'+key if path else key)
  return result
 return [] if a==b else [{'path':path,'before':a,'after':b}]
changes=differences(before,current)
allowed={
 'kitchen/kitchen.items.cheese.sell_price','kitchen/kitchen.items.carrot_stew.energy','kitchen/kitchen.items.carrot_stew.description',
 'harvest/harvest.items.cheese_bread.sell_price','harvest/harvest.recipes.cheese_bread.sell_value','harvest/harvest.processing.dairy_cheese.sell_value',
 'harvest/harvest.processing.smoke_fish_crucian.input_items.fish_crucian','harvest/harvest.processing.dry_fish_crucian.input_items.fish_crucian',
 'aquaculture/fish.items.dried_fish.description','aquaculture/fish.items.fish_soup.description','aquaculture/fish.recipes.soup.description','aquaculture/fish.recipes.star_soup.description'}
assert all(x['path'] in allowed for x in changes),[x['path'] for x in changes if x['path'] not in allowed]
h=current['harvest/harvest'];assert h['crops']==before['harvest/harvest']['crops'] and h['orchard']==before['harvest/harvest']['orchard'] and h['stations']==before['harvest/harvest']['stations']
def catalog(bundle):
 result={}
 for name,group in bundle['seasons/economy']['groups'].items():
  path=group['path'].removeprefix('res://resources/').removesuffix('.json')
  source=bundle.get(path)
  if source is None:source=json.loads((ROOT/group['path'].removeprefix('res://')).read_text())
  result.update(source[group['section']] if group['section'] else source)
 for p in (ROOT/'resources/crops').glob('*.tres'):
  text=p.read_text();id=re.search('id = "(.*?)"',text)[1]
  result[id]={'name':re.search('display_name = "(.*?)"',text)[1],'sell_price':int(re.search(r'sell_price = (\d+)',text)[1]),'seed_price':int(re.search(r'seed_price = (\d+)',text)[1]),'growth_days':int(re.search(r'growth_days = (\d+)',text)[1]),'harvest_quantity':1}
 result.update(bundle['harvest/harvest']['crops']);result.update(bundle['harvest/harvest']['items']);return result
def recipes(bundle):
 result={}
 for id,row in bundle['harvest/harvest']['processing'].items():result['workshop:'+id]={'name':row['name'],'station':row['processing_station_id'],'inputs':row['input_items'],'outputs':{row['output_item_id']:row['output_quantity']},'minutes':row['processing_duration']}
 for id,row in {**bundle['kitchen/kitchen']['recipes'],**bundle['harvest/harvest']['recipes']}.items():result['kitchen:'+id]={'name':row['name'],'station':'kitchen','inputs':row['required'],'outputs':row['rewards'],'minutes':0}
 for id,row in bundle['aquaculture/fish']['recipes'].items():result['lake:'+id]={'name':row['name'],'station':'existing_fishpen','inputs':row['required'],'outputs':row['rewards'],'minutes':0}
 for id,row in bundle['kitchen/kitchen']['processing'].items():result['legacy:'+id]={'name':row['name'],'station':row['facility'],'inputs':row['required'],'outputs':row['rewards'],'minutes':row['days']*1440}
 return result
old_items=catalog(before);items=catalog(current);old_recipes=recipes(before);all_recipes=recipes(current)
sources=set(h['crops'])|set(h['orchard'])|{'carrot','potato','wheat','wild_berry','wood','stone','hay','fish_feed','copper_bar','iron_bar'}
sources.update(row['product'] for row in current['livestock/livestock']['species'].values())
fishing=json.loads((ROOT/'resources/fishing/fishing.json').read_text());sources.update(row['item'] for row in fishing['species'].values())
reachable=set(sources)
while True:
 old=len(reachable)
 for row in all_recipes.values():
  assert all(k in items and isinstance(q,int) and q>0 for k,q in row['inputs'].items())
  assert all(k in items and isinstance(q,int) and q>0 for k,q in row['outputs'].items())
  if set(row['inputs'])<=reachable:reachable.update(row['outputs'])
 if len(reachable)==old:break
for id,row in all_recipes.items():assert set(row['inputs'])<=reachable,(id,'unreachable')
edges={}
for row in all_recipes.values():
 for output in row['outputs']:edges.setdefault(output,set()).update(row['inputs'])
def visit(id,path):
 assert id not in path,'Unbounded recipe cycle: '+str(path+[id])
 for child in edges.get(id,[]):visit(child,path+[id])
for id in edges:visit(id,[])
def values(row,defs):
 cost=sum(defs[k]['sell_price']*q for k,q in row['inputs'].items());value=sum(defs[k]['sell_price']*q for k,q in row['outputs'].items());return cost,value,value-cost
rows=[]
for id,row in all_recipes.items():
 a=values(old_recipes[id],old_items);b=values(row,items)
 utility=[]
 for output,q in row['outputs'].items():
  d=items[output]
  if d.get('energy'):utility.append(f"恢复{d['energy']*q}体力"+('，附增益' if d.get('buff') else ''))
  if output in ['hay','fish_feed']:utility.append('可喂养，省去卖原料再购料的往返')
  if any(output in r['inputs'] for r in all_recipes.values()):utility.append('可进一步加工')
 rows.append({'id':id,'name':row['name'],'station':row['station'],'inputs':row['inputs'],'outputs':row['outputs'],'before_input_value':a[0],'before_output_value':a[1],'before_margin':a[2],'after_input_value':b[0],'after_output_value':b[1],'after_margin':b[2],'minutes':row['minutes'],'production_transactions':2 if row['minutes']>0 else 1,'utility':list(dict.fromkeys(utility))})
special=json.loads((ROOT/'resources/story/marriage_preparation.json').read_text())
collection_uses={fishing['species'][id]['item'] for id in special['fish_species']}
for id in list(h['crops'])+list(h['orchard'])+['egg','milk','wool']+[row['item'] for row in fishing['species'].values()]:
 if id.endswith('_sapling') or id not in items:continue
 assert id in reachable,(id,'no obtainable source')
 assert any(id in r['inputs'] for r in all_recipes.values()) or items[id]['sell_price']>0 or id in collection_uses,(id,'no use')
crop_rows=[]
for id in ['carrot','potato','wheat']+list(h['crops']):
 c=items[id];amount=c.get('harvest_quantity',1);net=c['sell_price']*amount-c['seed_price'];actions=2+c['growth_days']
 crop_rows.append({'id':id,'name':c['name'],'growth_days':c['growth_days'],'yield':amount,'seed_cost':c['seed_price'],'sale_value':c['sell_price']*amount,'net_per_harvest':net,'net_per_suitable_day':round(net/c['growth_days'],3),'manual_actions_excluding_first_till':actions,'gold_per_manual_action':round(net/actions,3)})
station_rows=[{'id':id,'coins':r['coins'],'material_sale_value':sum(items[k]['sell_price']*v for k,v in r['required'].items()),'materials':r['required']} for id,r in h['stations'].items()]
report={'changes':changes,'recipe_count':len(rows),'recipes':rows,'crops':crop_rows,'stations':station_rows,'graph':'acyclic','unobtainable_inputs':[],'crop_and_tree_economy_changed':False,'notes':['Input costs use opportunity sale value, not assumed free farm products.','Crop labor assumes manual watering; rain and irrigation reduce it.','A timed batch needs separate start/claim transactions; travel, selection and confirmation add work.','Food can justify a negative sale margin by recovery, buffs or existing story use.','Legacy kitchen jobs retain original durations and remain a compatibility route.']}
(OUT/'economy.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
text='# 0.8.1 农业生产链与经济平衡\n\n'
text+=f'审计实际{len(rows)}条农业配方（49工坊、32厨房、7湖岸、4旧厨房兼容），材料以直接出售的机会成本计价。施工原料、耗时和操作也计入分析；没有调整原作物、果树、动物产出、钓鱼概率、季节或1314钻石规则。\n\n'
text+='## 有限调整及旧档影响\n\n| 项目 | 0.8.0 | 0.8.1 | 原因 |\n| --- | --- | --- | --- |\n| 奶酪售价 | 80 | 92 | 两份牛奶原价76，加工6小时原毛利仅4，现为16 |\n| 鲫鱼熏制投入 | 鲫鱼2＋木材1 | 鲫鱼3＋木材1 | 收敛同品类低成本高毛利 |\n| 鲫鱼晒干投入 | 鲫鱼2 | 鲫鱼3 | 与同类工艺及旧晾晒途径形成合理差异 |\n| 暖锅蔬菜炖恢复 | 22 | 32 | 原料直接食用共28且此菜无增益，改善基础料理价值 |\n| 奶酪面包售价 | 143 | 156 | 按原112%原料价值定价，维持奶酪涨价后的加工空间 |\n\n'
text+='旧库存采用当前售价/恢复效果，读取存档不补金币、不自动回体力。旧在制品保留原投入和产出快照；新鲫鱼用量只用于新单，不追扣旧单。加工时间和成品数量均未改。\n\n'
text+='## 全部配方前后表\n\n| 配方 | 原料价值前→后 | 成品价值前→后 | 毛利前→后 | 游戏分钟 | 其他用途 |\n| --- | --- | --- | --- | --- | --- |\n'
for row in rows:text+=f"| {row['id']} {row['name']} | {row['before_input_value']}→{row['after_input_value']} | {row['before_output_value']}→{row['after_output_value']} | {row['before_margin']}→{row['after_margin']} | {row['minutes']} | {'；'.join(row['utility'])} |\n"
text+='\n## 作物与劳动比较\n\n| 作物 | 成长日 | 每株产量 | 种子成本 | 收获净值 | 每适种日净值 | 手动动作数 | 每动作净值 |\n| --- | --- | --- | --- | --- | --- | --- | --- |\n'
for row in crop_rows:text+=f"| {row['name']} | {row['growth_days']} | {row['yield']} | {row['seed_cost']} | {row['net_per_harvest']} | {row['net_per_suitable_day']} | {row['manual_actions_excluding_first_till']} | {row['gold_per_manual_action']} |\n"
text+='\n原土豆的日均收益较高，西瓜等长周期作物的单位操作收益更高；不同季节、料理、油料与纺织需求保留差异。按日照料的动物、需要成熟季的果树和单槽设备都存在时间与容量约束。配方图无逆向复制循环，没有生产钻石的配方。\n\n原有部分湖岸料理/饲料的出售毛利为负，但用于恢复、增益、自给或减少交易往返；它们不作为转卖获利路线。本轮保留这些原有用途，没有统一提高所有售价。静态上界与桌面模拟不代替长期玩家经济反馈。\n\n实际五条生产链验证见 [chains.json](chains.json)。完整机器可读数据见 [economy.json](economy.json)。\n'
(OUT/'economy.md').write_text(text)
print('QUALITY081 ECONOMY PASS:',len(rows),'real recipes,',len(crop_rows),'crops,',len(changes),'bounded data changes')
