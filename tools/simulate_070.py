"""0.7.0经营模型与完整新内容价格审计；模型不是玩家实测。"""
from pathlib import Path
import json
import subprocess
import sys
ROOT=Path(__file__).resolve().parents[1]
subprocess.run([sys.executable,str(ROOT/'tools/simulate_seasons_b.py')],check=True)
base=json.loads((ROOT/'docs/BALANCE-0.7.0-B.json').read_text())
manifest=json.loads((ROOT/'resources/seasons/economy.json').read_text())
prices={}
import re
for crop in (ROOT/'resources/crops').glob('*.tres'):
 text=crop.read_text();key=re.search(r'^id = "([^"]+)"',text,re.M).group(1)
 prices[key]=int(re.search(r'^sell_price = (\d+)',text,re.M).group(1));prices[key+'_seed']=0
for source in manifest['groups'].values():
 raw=json.loads((ROOT/source['path'].removeprefix('res://')).read_text())
 for key,item in (raw[source['section']] if source['section'] else raw).items(): prices[key]=int(item['sell_price'])
value=lambda items:sum(prices[k]*int(n) for k,n in items.items())
world=json.loads((ROOT/'resources/world_progress/development.json').read_text())
orders=[]
for key,row in world['orders'].items():
 cost=value(row['required']);bonus=int(world['branches']['trade']['trade_coins']);best=int(row['coins'])+bonus-cost
 orders.append({'id':key,'input_opportunity_gold':cost,'base_gold':row['coins'],'trade_branch_gold':row['coins']+bonus,'best_incremental_margin':best,'best_margin_per_day_bound_at_3_day_cooldown':round(best/3,3),'requires_new_production':True})
community=[]
for key,row in world['community'].items():
 community.append({'id':key,'input_opportunity_gold':value(row['required']),'gold':row['coins'],'reward_sell_value':value(row['items']),'incremental_sell_margin':int(row['coins'])+value(row['items'])-value(row['required']),'shared_daily_quota':True,'weekly_only':key=='supper'})
for row in orders: assert row['best_incremental_margin']<=32
assert prices['fish_eternal']==0
reward_paths=['fishing','livestock','kitchen','ecology','festivals','housing','exploration','world_progress']
violations=[]
def audit(node,path):
 if isinstance(node,dict):
  for k,v in node.items():
   if k in ['diamond','diamonds'] and isinstance(v,(int,float)) and v>0: violations.append(path+'.'+k)
   audit(v,path+'.'+k)
 elif isinstance(node,list):
  for i,v in enumerate(node):audit(v,f'{path}[{i}]')
for directory in reward_paths:
 for source in (ROOT/'resources'/directory).glob('*.json'):audit(json.loads(source.read_text()),str(source.relative_to(ROOT)))
assert not violations,violations
report={'version':'0.7.0','model_not_playtest':True,'independent_operating_model':base,'trade_orders':orders,'community':community,'new_positive_diamond_config_entries':violations,'eternal_fish_sell_price':prices['fish_eternal'],'notes':['All 10000x28-day operating channels are alternatives, not a simultaneous optimal schedule. Do not sum their medians.','The 8-gold agriculture branch bonus is included in the trade upper bound; exploration/life reward one bait/hay instead.','Order margins require actual new production and delivery, at most one completion every three game days. They are not free gross revenue.','New stamina recovery and cooking buffs improve flexibility; this model excludes their optimal scheduling and does not estimate a fresh Xiaojing completion time.','No real-player long-session or Android performance measurements are inferred from model results.']}
path=ROOT/'docs/BALANCE-0.7.0.json';path.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('0.7.0 PRICE/REWARD AUDIT PASSED; positive new diamond configuration:',len(violations))
for row in orders:print(row['id'],'incremental trade bound',row['best_margin_per_day_bound_at_3_day_cooldown'],'gold/day')
print(path)
