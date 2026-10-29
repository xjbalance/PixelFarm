"""0.6.1流水线/DAG经济模型。生产规则来自工程，操作/行为参数是假设。
不将并行项简单求和：报告依赖关键路径、单玩家主动工时下界及日历下界。
"""
from pathlib import Path
from collections import deque,Counter
from itertools import permutations
import json,math,random,statistics,re
R=Path(__file__).resolve().parents[1]
F=json.loads((R/'resources/abyss/floors.json').read_text());M=json.loads((R/'resources/mining/mining.json').read_text());L=json.loads((R/'resources/abyss/legend.json').read_text());X=json.loads((R/'resources/story/xiaojing.json').read_text())
C={}
for p in (R/'resources/crops').glob('*.tres'):
 t=p.read_text();id=re.search(r'^id = "(.+)"',t,re.M)[1]
 C[id]={k:int(re.search(rf'^{k} = (\d+)$',t,re.M)[1]) for k in ('seed_price','sell_price','growth_days')}
def terrain(d):
 return {(x,y) for a,b,w,h in d['floors'] for x in range(max(1,a),min(39,a+w)) for y in range(max(1,b),min(27,b+h))}
def distance(s,a,b):
 q=deque([(tuple(a),0)]);seen={tuple(a)}
 while q:
  p,n=q.popleft()
  if p==tuple(b): return n
  for dx,dy in [(1,0),(-1,0),(0,1),(0,-1)]:
   c=p[0]+dx,p[1]+dy
   if c in s and c not in seen: seen.add(c);q.append((c,n+1))
 raise AssertionError((a,b))
routes=[];diamond_steps=0;all_steps=0;layer_rates=[]
for d in F:
 s=terrain(d);a,b,w,h=d['gate'];closed=s-{(x,y) for x in range(a,a+w) for y in range(b,b+h)}
 order=[d['entry'],d['hint']]
 actions=1
 for round_id in range(d['rounds']):
  if d['depth']>20:
   order.extend(d['utility'] if d['rule']!='prism' else ([d['utility'][0]]*2+[d['utility'][1]] if round_id else [d['utility'][1]]));actions+=len(order) # final action count is recomputed below
  order.extend(d['controls'][int(i)] for i in d['solution'])
 pre=sum(distance(closed,p,q) for p,q in zip(order,order[1:]))
 post=distance(s,order[-1],d['chest'])+distance(s,d['chest'],d['exit'])
 actions=len(order)+2
 side=pre+post
 if d.get('passage_cells'):
  opened=s|{tuple(v) for v in d['passage_cells']}
  side=pre+distance(s,order[-1],d['passage_switch'])+distance(opened,d['passage_switch'],d['chest'])+distance(opened,d['chest'],d['exit'])
 routes.append({'depth':d['depth'],'steps':pre+post,'side_steps':side,'actions':actions,'boss':d['depth']%20==0})
 for i,item in enumerate(d['ore_items']):
  walk=distance(s,d['entry'],d['ores'][i])+distance(s,d['ores'][i],d['exit'])
  potential=1.25 if item=='diamond' else 4/3 if item=='starlight_ore' else 0
  layer_rates.append({'floor':d['depth'],'ore':item,'hits':3,'energy':9,'output':1.25 if item=='diamond' else 2,'renewal_days':3 if d['depth']>20 else 'paid survey / earlier mining', 'grid_steps':walk,'diamond_equivalent_per_game_day':round(potential/3,4) if d['depth']>20 else None,'walking_seconds':round(walk*32/145,2),'diamond_equivalent_per_active_game_hour':round(potential*30/(walk*32/145+3*.9),4)})
 if d['depth']>=81: diamond_steps+=distance(s,d['entry'],d['ores'][1])+distance(s,d['ores'][1],d['exit'])
 if d['depth']>=41: all_steps+=distance(s,d['entry'],d['ores'][0])+distance(s,d['ores'][0],d['ores'][1])+distance(s,d['ores'][1],d['exit'])
layouts=json.loads((R/'resources/mining/maps.json').read_text())
def original_cells(area):
 d=layouts[area];s=terrain(d)
 if area=='mine_b': s-={(x,y) for x in range(25,29) for y in range(1,27)}
 for g in d['gates']:
  a,b,w,h=g['rect'];s|={(x,y) for x in range(a,a+w) for y in range(b,b+h)}
 return s
paid_steps=220
for area,target in [('mine_a','a_down'),('mine_b','b_down')]:
 d=layouts[area];at=next(o['cell'] for o in d['objects'] if o['id']==target);paid_steps+=2*distance(original_cells(area),d['entry'],at)
c=layouts['mine_c'];points=[tuple(c['entry'])]+[tuple(o['cell']) for o in c['objects'] if o.get('ore') in ['diamond','starlight']]
dists={(a,b):distance(original_cells('mine_c'),a,b) for a in points for b in points}
paid_steps+=min(sum(dists[a,b] for a,b in zip((points[0],)+seq,seq+(points[0],))) for seq in permutations(points[1:]))
profiles={
 'efficient':{'action':(.35,.65),'travel':(1.05,1.4),'read':(7,14),'well':(5,7),'plots':60,'farm_energy':.98,'day':7,'contact':.95,'gift':.8,'search':(12,22),'collection':.85},
 'normal':{'action':(.7,1.2),'travel':(1.5,2.2),'read':(17,30),'well':(8,11),'plots':55,'farm_energy':.85,'day':8,'contact':.7,'gift':.55,'search':(25,45),'collection':.65},
 'explorer':{'action':(1.0,1.7),'travel':(2.1,3.2),'read':(30,55),'well':(11,16),'plots':45,'farm_energy':.70,'day':9,'contact':.55,'gift':.4,'search':(45,80),'collection':.98}}
def farm520(rng,p):
 coins=120;seeds=Counter(carrot=12,potato=6,wheat=6);plots=[];sown=0;actions=0;harvests=Counter();well=rng.randint(*p['well']);build=False;build_day=999;gather_energy=0
 for day in range(1,201):
  rain=day%7 in [0,4]
  if day>=well and not build and coins>=260 and gather_energy>=123: coins-=260;gather_energy-=123;build=True;build_day=day
  auto=build
  energy=int((130 if day>build_day else 100)*p['farm_energy'])
  for plot in plots:
   if plot['crop'] and plot['water']: plot['age']+=1
   plot['water']=rain or auto
  for plot in plots:
   crop=plot['crop']
   if crop and plot['age']>=C[crop]['growth_days'] and energy:
    energy-=1;actions+=1;harvests[crop]+=1;coins+=int(C[crop]['sell_price']*.9);plot['crop']=''
  # Wet growing crops first; avoid sowing land that cannot be watered today.
  for plot in plots:
   if plot['crop'] and not plot['water'] and energy: plot['water']=True;energy-=1;actions+=1
  for i in range(p['plots']):
   if i<len(plots) and plots[i]['crop']: continue
   cost_energy=(2 if i>=len(plots) else 0)+1+(0 if rain or auto else 1)
   if energy<cost_energy: break
   crop=next((c for c in ['carrot','potato','wheat'] if seeds[c]>0),None)
   if crop is None:
    crop='wheat' if p['plots']==60 else rng.choice(['carrot','wheat','potato'])
    price=math.ceil(C[crop]['seed_price']*(.8 if auto else 1))
    if coins<price: break
    coins-=price;seeds[crop]+=1
   seeds[crop]-=1;energy-=cost_energy;actions+=2 if i>=len(plots) else 1
   if not (rain or auto): actions+=1
   if i>=len(plots): plots.append({})
   plots[i].update(crop=crop,age=0,water=True);sown+=1
   if sown==520: return day,actions,coins,dict(harvests)
  gather_energy+=energy # 前几日未用于农活的体力可实际用于桥/井/共仓/床铺材料，不凭空获得设施。
 raise AssertionError('farm starvation')
reward={k:sum(q['reward'][k] for q in X['quests']) for k in ['affection','trust','bond']}
unique={'affection':reward['affection']+10,'trust':reward['trust']+15+2+3+1,'bond':reward['bond']+15+2+2+6+1}
def rel_days(rng,p):
 stats=unique.copy();history=[]
 for day in range(0,201):
  if min(stats.values())>=100: return day
  if rng.random()<p['contact']: stats['affection']+=1
  if rng.random()<p['gift']:
   gift=['wheat','carrot','potato','crystal'][day%4] if p['plots']==60 else rng.choice(['wheat','carrot','potato','crystal','stone'])
   if gift not in history[-3:]: stats['affection']+=2 if gift=='wheat' else 0 if gift=='stone' else 1
   history.append(gift)
  if rng.random()<p['contact']: stats['trust']+=1;stats['bond']+=1
 return 200

def sample(rng,p):
 action=rng.uniform(*p['action']);travel=rng.uniform(*p['travel']);read=rng.uniform(*p['read']);daymin=p['day']
 farmdays,farmacts,coins,crops=farm520(rng,p)
 work={};end={};edges={}
 def node(id,parents,active,calendar=0,parallel_origin=False):
  work[id]=active;edges[id]=parents
  start=max((end[x] for x in parents),default=0)
  end[id]=start+max(active,calendar)
 node('plants520',[],farmacts*action/60+farmdays*travel*.65,farmdays*daymin)
 # Farming in tutorial and chapter2 overlaps the 520/management cycles; only travel, gathering, processing, dialogue charged here.
 node('chapter1',[],(7200/145/60*travel)+36*read/60+40*action/60+rng.uniform(15,30),3*daymin)
 node('mines', ['chapter1'], 22000/145/60*travel+32*read/60+110*action/60+rng.uniform(20,40),3*daymin)
 basework=[min(r['steps'],r['side_steps'])*32/145/60*travel+(r['actions']*action+read)/60 for r in routes]
 gear_travel=rng.uniform(15,30)*travel
 node('abyss20',['mines'],sum(basework[:20])+gear_travel*.3)
 node('abyss40',['abyss20'],sum(basework[20:40])+gear_travel*.2)
 node('abyss60',['abyss40'],sum(basework[40:60])+gear_travel*.25)
 node('abyss80',['abyss60'],sum(basework[60:80])+gear_travel*.25)
 node('memories7',['plants520','chapter1'],rng.uniform(*p['search'])+7*read/60+15*action/60)
 # Plant30 is a subset of management120. Six-hour fixed guesses from 0.6 are replaced by production-operation counts.
 node('management',['plants520'],(120*4+60)*action/60+8*travel,8*daymin)
 node('planning',['management','mines'],12*travel+15*action/60,2*daymin)
 node('abyss100',['abyss80','planning'],sum(basework[80:])+8*travel)
 node('chapter2_farm',['abyss20'],5*travel+8*read/60,2*daymin)
 node('chapter2_prototype',['abyss40','chapter2_farm'],8*travel+8*read/60+18*action/60,2*daymin)
 node('chapter2_tail',['abyss60','chapter2_prototype'],9*travel+8*read/60)
 node('mechanism',['abyss100','memories7'],(9000/145/60)*travel+12*action/60+5*read/60)
 node('joint',['mechanism','management','planning'],36*4*action/60+18*travel,4*daymin)
 node('quests12',['joint','memories7'],12*read/60+12*action/60)
 relation_duration=rel_days(rng,p)*daymin
 node('social',['plants520'],relation_duration/daymin*.5*travel,relation_duration)
 node('relationship100',['quests12','social'],0)
 # Materials can be gathered while exploring; final install gated by quests12. Farm/forge supply effort is charged only once.
 node('materials',['mines'],rng.uniform(25,45)*travel+150*action/60,3*daymin)
 node('greenhouse5_ready',['quests12','materials'],5*travel+4*action/60)
 collect=p['collection'];initial=18+12*collect+50*collect+25*collect
 # Full cycle: 60 rare deposits + 27 crystal nodes +14 trees for refining fuel =>867 stamina, >=5 productive days even with tea/camp.
 use_refining=p['plots']!=60
 cycle_yield=78+1/3 if use_refining else 25
 energy=867 if use_refining else 180
 daily_energy=130+40*p['contact']+40*.8
 cycle_days=max(3,math.ceil(energy/daily_energy))
 cycles=math.ceil((1314-initial)/cycle_yield)
 steps=all_steps if use_refining else diamond_steps
 loop_active=(steps*32/145/60*travel+(87*3 if use_refining else 20*3)*action/60+(10 if use_refining else 4)*travel)
 strategy='all_rare' if use_refining else 'deep_diamond'
 if p['plots']==60:
  # 合法付费重勘：旧六矿9.75钻/轮，另每三日委托5；补给/燃料/作物与采矿约216体力/日。
  paid_yield=9.75+5/3;paid_period=max(1,216/daily_energy);paid_cycles=math.ceil((1314-initial)/paid_yield)
  paid_active=paid_steps*32/145/60*travel+62*action/60+3*travel
  old_score=max(sum(work.values())+cycles*loop_active,end['abyss100']+max(cycles*loop_active,cycles*cycle_days*daymin))
  paid_score=max(sum(work.values())+paid_cycles*paid_active,end['abyss100']+max(paid_cycles*paid_active,paid_cycles*paid_period*daymin))
  if paid_score<old_score: strategy='paid_original';cycles=paid_cycles;loop_active=paid_active;cycle_days=paid_period
 node('diamonds',['abyss100'],cycles*loop_active,cycles*cycle_days*daymin)
 node('wedding',['relationship100','greenhouse5_ready','diamonds','chapter2_tail'],8*travel+6*read/60)
 # Single player cannot execute simultaneous active tasks. Critical path includes farm growth/queue/regen waits, not summed overlaps.
 active_lower=sum(work.values());critical=end['wedding'];total=max(active_lower,critical)
 milestones={k: {'active_h':work[k]/60,'finish_h':end[k]/60} for k in work}
 milestones['abyss_active_all_h']=sum(work[k] for k in ['abyss20','abyss40','abyss60','abyss80','abyss100'])/60
 milestones['greenhouse_active_h']=(work['materials']+work['greenhouse5_ready'])/60
 milestones['greenhouse_complete_h']=total/60
 milestones['relationships_after_unlock_h']=(end['relationship100']-end['plants520'])/60
 milestones['quests_memories_after_unlock_h']=(end['quests12']-end['plants520'])/60
 milestones['trials_span_h']=(end['joint']-end['plants520'])/60
 milestones['trials_active_shared_with_abyss_h']=(work['management']+work['planning']+work['mechanism']+work['joint']+work['abyss100'])/60
 return total/60, milestones, farmdays,active_lower/60,critical/60,edges,strategy

def qs(values):
 v=sorted(values);return {'p10':round(v[len(v)//10],3),'p50':round(statistics.median(v),3),'p90':round(v[len(v)*9//10],3)}
results={}
for name,p in profiles.items():
 rng=random.Random(610520+list(profiles).index(name));runs=[sample(rng,p) for _ in range(10000)]
 parts={}
 for id in runs[0][1]:
  if isinstance(runs[0][1][id],dict): parts[id]={k:qs([r[1][id][k] for r in runs]) for k in ['active_h','finish_h']}
  else: parts[id]=qs([r[1][id] for r in runs])
 results[name]={'samples':10000,'total_hours':qs([r[0] for r in runs]),'days_to_520':qs([r[2] for r in runs]),'single_player_active_lower_h':qs([r[3] for r in runs]),'dependency_path_h':qs([r[4] for r in runs]),'parts':parts,'dependencies':runs[0][5],'chosen_diamond_strategies':dict(Counter(r[6] for r in runs))}
tools=[]
for rank in [1,2,3]:
 for id,o in M['ores'].items():
  if rank<o['level']: continue
  hits=math.ceil(o['hits']/(2 if rank>o['level'] else 1));amount=1.25 if o['item']=='diamond' else o['amount']
  tools.append({'pick':rank,'ore':id,'hits':hits,'energy':hits*o['energy'],'expected_output':amount,'energy_per_unit':round(hits*o['energy']/amount,3)})
chapter1=json.loads((R/'resources/story/wind_lantern.json').read_text())
chapter2=json.loads((R/'resources/mining/chapter_two.json').read_text())
farmquests=json.loads((R/'resources/progression/quests.json').read_text())
reward_audit={'chapter1_coins':sum(int(s.get('coins',0)) for s in chapter1['scenes'].values()),'chapter2_coins':sum(int(q['reward'].get('coins',0)) for q in chapter2),'farm_quest_coins':sum(int(q.get('coins',0)) for q in farmquests.values()),'direct_quest_diamonds_once':18,'all_once_chests_and_relic':80,'share_of_1314_percent':round(80/1314*100,2)}
report={'version':'0.6.1','model_only':True,'method':'DAG critical path plus single-player active-work lower bound; shared farm/cave/quest activities counted once; not an exact optimal scheduler or human playtest','profiles':profiles,'results':results,'reward_audit':reward_audit,'relationship_one_time':unique,'tools':tools,'floors':layer_rates,
 'sources':[{'id':'original_veins','expected_per_3_days':3.75},{'id':'original_refining','expected_per_3_days':6},{'id':'commission','expected_per_3_days':5},{'id':'original_paid_survey','diamond_per_paid_cycle':9.75,'commission_extra_per_3_days':5,'supply_and_energy_budget_per_day_approx':216},{'id':'abyss_paid16_20','expected_per_3_days':40/3},{'id':'deep_diamond81_100','expected_per_3_days':25},{'id':'deep_starlight41_80','expected_refined_per_refresh':160/3,'energy_limited_full_cycle_days_at_least':5},{'id':'chests_and_relic','once_only_max':80}],
 'fixes_modeled':['Non-festival bench can no longer skip 12 hours every day. One chapter7 fast-forward remains.','Arrival air proof cannot be replaced by checkpoint air refill.','No diamond drop-rate nerf; rare veins fixed guaranteed outputs. Paid original-mine surveys remain a legal faster route with actual supplies, energy and processing queues.','Recent gift history window3 allows four useful gifts to rotate; repeated identical gifts still zero.'],
 'assumptions':['Operation seconds, walking detours, reading time, well acquisition day and visit frequency are explicit sampled assumptions, not measured players.','The farm model starts with120 coins/24 seeds, 60 max plots, actual crop prices/growth, stamina, deterministic rain and later irrigation access. Village material collection uses accumulated spare farming energy (123 stamina budget before early facilities) and is charged in main/supply work, not invented free crops.','Relation100 depends on quests12/trials; it is not added as an independent 100-day grind. Management120 includes quest30. Cave80–100 is shared with first abyss descent.','Concurrent waiting windows use max(), with sum of unique active work as a one-player lower bound; travel/task ordering conflicts may add more time. New local diagnostics are required to calibrate.','Farm/queue/ore day constraints use ordinary7–9 minute days. Calendar waiting is not counted as entertaining content.','Floor active-game-hour yield uses an ideal entry/ore/exit route,0.9s per hit and30 real seconds per game hour; it excludes inter-floor/processing/logistics and is not a global farming rate.','Parts.finish_h is the dependency earliest finish; total also respects the one-player active-work bound. It is not a proven feasible optimal schedule.','No claimed 200–350h attainment; extending current content to that range would predominantly add repetition/waiting.']}
(R/'docs/BALANCE-0.6.1.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:{'total':v['total_hours'],'farm520':v['parts']['plants520'],'relationship':v['parts']['relationships_after_unlock_h'],'trials':v['parts']['trials_span_h']} for k,v in results.items()},ensure_ascii=False,indent=2))
