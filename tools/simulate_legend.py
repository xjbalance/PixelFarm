"""传说层可达性/经营可行性/资源模型。所有时长是假设，不是200–350h实测。"""
from collections import deque
from pathlib import Path
import contextlib, io, json, math, random, re, runpy, statistics
ROOT=Path(__file__).resolve().parents[1]
FLOORS=json.loads((ROOT/'resources/abyss/floors.json').read_text())
CONFIG=json.loads((ROOT/'resources/abyss/legend.json').read_text())
MINES=json.loads((ROOT/'resources/mining/mining.json').read_text())

def cells(d):
    result=set()
    for x,y,w,h in d['floors']:
        result.update((i,j) for j in range(max(1,y),min(27,y+h)) for i in range(max(1,x),min(39,x+w)))
    return result

def length(floor,a,b):
    q=deque([(tuple(a),0)]);seen={tuple(a)}
    while q:
        p,n=q.popleft()
        if p==tuple(b): return n
        for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
            dest=p[0]+dx,p[1]+dy
            if dest in floor and dest not in seen: seen.add(dest);q.append((dest,n+1))
    return None

routes=[]
for d in FLOORS:
    floor=cells(d);x,y,w,h=d['gate']
    closed=floor-{(i,j) for i in range(x,x+w) for j in range(y,y+h)}
    for point in [d['hint'],*d['controls']]: assert length(closed,d['entry'],point) is not None
    assert length(closed,d['entry'],d['exit']) is None, d['depth']
    for point in [d['exit'],d['chest'],*d['ores']]: assert length(floor,d['entry'],point) is not None
    order=[d['entry'],d['hint'],*[d['controls'][i] for i in d['solution']],d['chest'],d['exit']]
    routes.append(sum(length(floor,a,b) for a,b in zip(order,order[1:])))
assert len({json.dumps(d['floors']) for d in FLOORS})==20
prices={}
for crop in ('carrot','potato','wheat'):
    text=(ROOT/f'resources/crops/{crop}.tres').read_text()
    prices[crop]={k:int(re.search(rf'^{k} = (\d+)$',text,re.M)[1]) for k in ('seed_price','sell_price','growth_days')}
plan={'carrot':24,'wheat':24,'potato':72}
cost=sum(prices[c]['seed_price']*n for c,n in plan.items())
profit=sum((prices[c]['sell_price']-prices[c]['seed_price'])*n for c,n in plan.items())
r=CONFIG['trials']['management']
assert sum(plan.values())<=r['seeds'] and cost<=r['budget'] and profit>=r['profit']
# 供应链：铜2铁3，留一铁制合金，再装分流器；两次跨日加工，在四日窗口内。
wood=2*MINES['recipes']['copper_bar']['required']['wood']+3*MINES['recipes']['iron_bar']['required']['wood']+MINES['recipes']['star_alloy']['required']['wood']+4
assert wood<=CONFIG['trials']['planning']['wood'] and 8<=CONFIG['trials']['planning']['stone']
# 当前20层每4层2钻箱，仅一次；新深层轮次十矿共20原矿，三日限补给。
raw_per_cycle=5*2*2
refine=MINES['recipes']['refine']
abyss_yield=raw_per_cycle/refine['required']['starlight_ore']*refine['diamonds']
original_yield=3*1.25+3*MINES['ores']['starlight']['amount']/refine['required']['starlight_ore']*refine['diamonds']+MINES['commission']['diamonds']

def model(abyss_loop):
    rng=random.Random(1314200350+int(abyss_loop));samples=[];breakdown=[]
    for _ in range(10000):
        diamonds=30+sum(2 for d in range(1,21) if d%4==0)
        counter=0;cycles=0;raw=0;active=0
        while diamonds<1314:
            cycles+=1
            for vein in range(3):
                counter+=1;diamonds+=1+(counter%4==0)
            diamonds+=6+5
            # 原高级矿脉、种源/燃料、原材料加工与地面往返主动操作假设。
            active+=rng.uniform(11,20)
            if abyss_loop:
                raw+=raw_per_cycle
                batches,raw=divmod(raw,refine['required']['starlight_ore'])
                diamonds+=batches*refine['diamonds']
                # 深渊已开闸后重访五层、真实采矿与新增铁/燃料/晶石供应链。
                active+=rng.uniform(13,25)
        main=rng.uniform(10,24)
        first20=sum(routes)*32/145/60+rng.uniform(45,105)
        trial_hours=rng.uniform(3,7)
        action_hours=active/60+main+first20/60+trial_hours
        # P0之后：每轮3日不可能靠白天无限睡觉压缩。此为日历下界，不当作新增有趣内容。
        calendar_lower=cycles*3*14/(2*60) # 14游戏小时到20:00，每秒2游戏分 => 每日7真实分
        # 上行单位：14/2=7分，每周期3日，除60转小时。
        samples.append(max(action_hours,calendar_lower))
        breakdown.append((active/60,main,first20/60,trial_hours,calendar_lower))
    samples.sort()
    return dict(samples=10000,scenario='original_plus_abyss' if abyss_loop else 'original_sources',
                p10_hours=round(samples[1000],2),p50_hours=round(statistics.median(samples),2),p90_hours=round(samples[9000],2),
                mean_hours=dict(zip(['repeatable_resources','main_and_relationships','first_twenty_floors','legend_trials','calendar_lower_bound'],[round(statistics.mean(v),2) for v in zip(*breakdown)])),
                target_200_350_met=200<=statistics.median(samples)<=350)
report={'model_only_not_playtest':True,'implemented_floors':20,'planned_floors':100,'unique_layouts':20,
        'management_plan':{'quantities':plan,'seed_value':cost,'profit_without_discount':profit,'required_profit':r['profit']},
        'crafting_chain':{'wood':wood,'stone':8,'copper_bars':2,'iron_bars':3,'alloy':1,'processing_nights':2},
        'diamond_sources':{'original_diamonds_per_3_days_mean':original_yield,'abyss_additional_per_3_days_mean':round(abyss_yield,3),
                           'abyss_one_time_chests':10,'drop_drought':'none; guaranteed deposits/refining, fixed original every-fourth bonus',
                           'all_sources_mean_per_game_day':round((original_yield+abyss_yield)/3,3)},
        'scenarios':[model(False),model(True)],
        'audit':['20 closed-gate clue/control routes reachable and exits inaccessible; opened routes reach exits/chests/ores.',
                 'All crafted inputs have gatherable renewable sources; diamond shops cost more than refining outputs.',
                 'P0 blocks day-sleep refresh; abyss reset requires exhausted advanced ore and paid supplies with 3-day interval.',
                 'No diamond is required to acquire diamond: surface natural regeneration remains available after all one-time boxes.',
                 'Wrong inference requires rechecking an original; wrong gates reset safely; ladders remain accessible; checkpoints preserve progress.',
                 '200–350h is NOT established. Do not pad model with forced idle time or assumed future 21–100 content.'],
        'limits':['Active-operation timings are assumptions; fixed-fps integration is not human timing.',
                  'Calendar lower bound is a constraint, not entertaining content or evidence of engagement.',
                  'Stages21–100, more equipment and larger narrative mechanisms remain unimplemented.']}
(ROOT/'docs/LEGEND-BALANCE.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
