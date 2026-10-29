"""0.6.0生产数据经济/装备死局审查。时间是假设模型，不是真人试玩。"""
from pathlib import Path
import json,math,random,statistics,runpy,contextlib,io
R=Path(__file__).resolve().parents[1]
with contextlib.redirect_stdout(io.StringIO()): check=runpy.run_path(str(R/'tools/check_060_layouts.py'))
floors=check['data'];cfg=json.loads((R/'resources/abyss/legend.json').read_text());mines=json.loads((R/'resources/mining/mining.json').read_text())
first_source={}
for d in floors:
 for item in d['ore_items']: first_source.setdefault(item,d['depth'])
for rank,recipe in cfg['gear'].items():
 for item in recipe['required']:
  if item in ['ancient_shard','star_fragment']: assert first_source[item]<=recipe['depth'],f'gear{rank} deadlock {item}'
assert cfg['gear']['7']['required']['star_fragment']==6
counts={}
for d in floors[20:]:
 for item in d['ore_items']: counts[item]=counts.get(item,0)+1
rare_nodes=counts['starlight_ore']+counts['diamond']
raw=counts['starlight_ore']*2
refined=raw/mines['recipes']['refine']['required']['starlight_ore']*mines['recipes']['refine']['diamonds']
crystal_needed=math.ceil(raw/3)*2
fuel=math.ceil(raw/3)*2
energy=rare_nodes*9+math.ceil(crystal_needed/2)*9+math.ceil(fuel/4)*6
max_daily=130+40+40
one_time_chest=sum(2 for d in floors if d['depth']%4==0)
one_time_deep=counts['diamond']*1.25

def scenario(all_ores=False,spend=0):
 rng=random.Random(6001314+int(all_ores)+spend);hours=[];pieces=[];cycles_out=[]
 for _ in range(10000):
  diamonds=one_time_chest+one_time_deep+30-spend
  rounds=0;actions=0.0
  yield_cycle=(refined+counts['diamond']*1.25) if all_ores else counts['diamond']*1.25
  period=max(3,math.ceil(energy/max_daily)) if all_ores else 3
  while diamonds<1314:
   rounds+=1;diamonds+=yield_cycle
   # 已开闸回访、采矿、加工与补给的主动操作假设。
   actions+=rng.uniform(26,46) if all_ores else rng.uniform(7,13)
  main=rng.uniform(10,24)
  hundred=rng.uniform(3.5,6.5) # 100层首次机关、观察、补给、护具与地面往返假设
  trials=rng.uniform(3,7)
  wedding=rng.uniform(.25,.6)
  active=actions/60+main+hundred+trials+wedding
  calendar=rounds*period*7/60 # P0：最早20点睡，每日最少7现实分钟；仅下界，不当作新增内容。
  hours.append(max(active,calendar));cycles_out.append(rounds);pieces.append((actions/60,main,hundred,trials,wedding,calendar))
 hours.sort()
 return {'samples':10000,'strategy':'all_rare_and_refining' if all_ores else 'deep_diamonds','optional_diamond_spend':spend,
         'p10_hours':round(hours[1000],2),'p50_hours':round(statistics.median(hours),2),'p90_hours':round(hours[9000],2),
         'cycle_days':period,'diamonds_per_cycle':round(yield_cycle,3),'mean_cycles':statistics.mean(cycles_out),
         'mean_hours':dict(zip(['repeatable_active','main_and_relationships','first_100','trials','ceremony','calendar_lower_bound'],[round(statistics.mean(v),2) for v in zip(*pieces)]))}
report={'version':'0.6.0','model_not_playtest':True,'layouts':100,'first_source_depth':first_source,
 'production':{'repeatable_diamond_nodes':counts['diamond'],'guaranteed_mean_per_node':1.25,'raw_starlight_per_full_survey':raw,'refining_diamonds':round(refined,3),'one_time_100_chests':one_time_chest,'one_time_first_diamond_veins_mean':one_time_deep,'full_cycle_minimum_energy':energy,'daily_stamina_model':max_daily,'full_cycle_minimum_days':math.ceil(energy/max_daily)},
 'scenarios':[scenario(False),scenario(True),scenario(False,100)],
 'dead_end_checks':['All 100 closed/open map routes checked; region bosses/gear gates have reachable return ladders.','Ancient/star materials are gatherable before their required gear upgrades; crystal/iron/starlight earlier available in original three mines.','21–100 ores regenerate after three legitimate days, avoid respawning under player; main mine repeatable sources retained.','One-time chest/core/quest/memory flags persist. Purchases cannot create positive diamond refining cycles.','Sleep before20 rejected; no arbitrary day skip. Resource model constrains energy instead of assuming 80 rare ores in a single day.'],
 'limits':['Time inputs are assumptions, not measured human completion. Fixed-fps testing is not playtesting.','Calendar lower bound is not entertaining content. Prior 200–350h target remains unverified and is not achieved by this model.','Phone FPS, input comfort, battery and long-term retention require real devices and playtests.']}
(R/'docs/BALANCE-0.6.0.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps(report,ensure_ascii=False,indent=2))
