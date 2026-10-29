"""深化支线及钻石消费敏感性；时长是假定主动操作模型，不是真人试玩。"""
from pathlib import Path
import contextlib
import io
import json
import random
import re
import runpy
import statistics

ROOT = Path(__file__).resolve().parents[1]
with contextlib.redirect_stdout(io.StringIO()):
    base = runpy.run_path(str(ROOT/'tools/simulate_mining.py'))
trials = json.loads((ROOT/'resources/story/star1314.json').read_text())['trial_rules']
# 无共仓折扣也可用48土豆12麦完成；不是依赖夹具的即时成熟。
prices = {}
for crop in ('potato', 'wheat'):
    text = (ROOT/f'resources/crops/{crop}.tres').read_text()
    prices[crop] = {key: int(re.search(rf'^{key} = (\d+)$', text, re.M)[1])
                   for key in ('seed_price', 'sell_price', 'growth_days')}
cost = sum(prices[c]['seed_price']*n for c, n in [('potato', 48), ('wheat', 12)])
sales = sum(prices[c]['sell_price']*n for c, n in [('potato', 48), ('wheat', 12)])
assert cost <= trials['management']['seed_value'] and sales-cost >= trials['management']['profit']
assert max(prices[c]['growth_days'] for c in prices) <= trials['management']['days']
# 购物价格直接读GDScript表，精炼用生产JSON；购买原矿的钻石支出高于加工产出。
source = (ROOT/'scripts/economy/diamond_payments.gd').read_text()
goods = json.loads(re.search(r'const GOODS := (\{.*\})', source)[1])
recipes = base['DATA']['recipes']
for recipe_id, recipe in recipes.items():
    if recipe['diamonds']:
        paid = sum(goods[item]*n for item, n in recipe['required'].items())
        assert paid > recipe['diamonds'], f'profitable shop/refining loop: {recipe_id}'
assert goods['starlight_ore']*5 + goods['stone']*12 > 2  # 旧库存加工接口也不能靠买料获利。


def scenario(spend):
    rng = random.Random(13140508+spend)
    hours, cycles = [], []
    for _ in range(10000):
        diamonds, counter, cycle, minutes = 30, 0, 0, 0.0
        while diamonds-spend < 1314:
            cycle += 1
            for _vein in range(base['diamond_veins']):
                counter += 1
                diamonds += 1 + (counter % 4 == 0)
            diamonds += base['refine_yield'] + base['DATA']['commission']['diamonds']
            walk = (base['tour']+base['surface_transit'])*32/145/60
            minutes += walk*rng.uniform(1.4, 2.5) + rng.uniform(1, 3) + rng.uniform(6, 12) + rng.uniform(1.5, 4)
        # 沿用原主线/关系/播种模型，增加1–3小时主动调查、制作与婚后项目假设；不加挂机等待。
        hours.append(minutes*rng.uniform(.85, 1.25)/60 + rng.uniform(10, 24) + rng.uniform(1, 3))
        cycles.append(cycle)
    hours.sort()
    return {'samples': 10000, 'optional_diamond_spending': spend,
            'p10_hours': round(hours[1000], 2), 'p50_hours': round(statistics.median(hours), 2),
            'p90_hours': round(hours[9000], 2), 'mean_cycles': statistics.mean(cycles)}

report = {
    'not_human_playtest': True,
    'management_feasible_plan': {'potato': 48, 'wheat': 12, 'seed_value': cost, 'sales': sales,
                                 'standard_profit': sales-cost, 'growth_days': 3},
    'shopping_arbitrage': 'PASS: all diamond-output recipes cost more diamonds in purchased inputs than they yield',
    'scenarios': [scenario(n) for n in [0, 100, 300]],
    'no_spending_endless_requirement': 'Buying is optional. Fixed finite spending can always be recovered through three-day rare-vein regeneration without diamond payment. Continued spending faster than income can delay marriage indefinitely by player choice.',
    'timing_limits': 'Active-time assumptions; no verified 80–120 hour duration, no human playtest. Post-marriage day520 is a date boundary, excluded from pre-marriage completion hours.',
    'unchanged_guarantees': base['report']['worst_luck'],
}
(ROOT/'docs/STAR1314-BALANCE.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
print(json.dumps(report, ensure_ascii=False, indent=2))
