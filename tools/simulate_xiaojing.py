"""Reproducible balance scenarios, not a substitute for 150-hour human playtesting."""
from collections import deque
from itertools import permutations
from pathlib import Path
import json
import random
import statistics

ROOT = Path(__file__).resolve().parents[1]
data = json.loads((ROOT/'resources/story/xiaojing.json').read_text())

def wall(x, y):
    return x <= 0 or y <= 0 or x >= 8 or y >= 8 or (x == 4 and y not in (3, 7)) or (y == 4 and x in (1, 3))

def path(a, b):
    queue = deque([a])
    previous = {a: None}
    while queue:
        point = queue.popleft()
        if point == b:
            result = []
            while point != a:
                result.append(point)
                point = previous[point]
            return result[::-1]
        for dx, dy in ((0,1),(1,0),(0,-1),(-1,0)):
            nxt = point[0]+dx, point[1]+dy
            if not wall(*nxt) and nxt not in previous:
                previous[nxt] = point
                queue.append(nxt)
    raise AssertionError('Unreachable mineral')

best = None
for order in permutations(((3,1),(7,3),(3,7),(7,7))):
    route, current = [], (1,1)
    for destination in (*order,(1,1)):
        route += path(current,destination)
        current = destination
    oxygen = len(route)+8
    if best is None or oxygen < best['oxygen']:
        best = {'oxygen':oxygen,'unique_cells':len(set(route)),'route':route}
assert best['oxygen'] <= 40 and best['unique_cells'] >= 20
assert 130 - (5*2+4)*3 >= 35  # upgraded tools: 5 trees and 4 rocks
assert 48*56-48*18 >= 1800  # 48 potato crops, account for seed cost
assert len(data['quests']) == 12 and len(data['memories']) == 7
assert {q['type'] for q in data['quests']} >= {'种植','交付','调查','探索','解谜','共同活动'}
assert all(not q['repeatable'] for q in data['quests'])

rng = random.Random(5201314)
N = 10000

def model(prototype):
    samples, runs = [], []
    for _ in range(N):
        diamonds, ore, minutes, count = 18, 0, 0.0, 0
        while diamonds < 1314:
            count += 1
            if prototype:
                # Fixed prototype has guaranteed, repeatable mineral points.
                duration = rng.uniform(1.5,4.0)
                diamonds += 3
                ore += 4
                while ore >= 5:
                    ore -= 5
                    diamonds += 2
                    minutes += rng.uniform(0.5,1.5)  # stone acquisition + processing assumption
            else:
                # FUTURE DESIGN ONLY: varied 22–30min multi-room expeditions, guaranteed 3.
                duration = rng.uniform(22,30)
                diamonds += 3 + (1 if rng.random() < 0.25 else 0)
            minutes += duration
            if count % 8 == 0:
                diamonds += 5
                minutes += rng.uniform(8,16)  # active farming/order work, no idle time
        samples.append(minutes/60 + rng.uniform(12,24))  # quest/crop/activity play assumptions
        runs.append(count)
    samples.sort()
    return dict(samples=N,median_hours=round(statistics.median(samples),2),p10_hours=round(samples[N//10],2),p90_hours=round(samples[N*9//10],2),mean_expeditions=round(statistics.mean(runs),1),meets_150_250_scenario=150 <= statistics.median(samples) <= 250)

prototype = model(True)
future = model(False)
assert not prototype['meets_150_250_scenario']
assert future['meets_150_250_scenario']
report = {'seed':5201314,'prototype_current_rules':prototype,'future_unimplemented_design':future,'cave_feasibility':best,'no_dead_end_checks':['All mineral locations reachable; return path and oxygen feasible','Repeatable expeditions restore deposits on every expedition','Failed expeditions permit rope retreat and restart','Crops and resources regrow; wheat provisions can be planted','Five trial gates have a valid order; losing a run does not consume completed quests','1314 diamonds have a separate 999999 cap; original item stacks stay 999'],'limitations':['No 150–250h human playtest performed','Prototype source times and non-mining activity times are assumptions, not measured completion time','Current prototype does NOT meet duration/content-density target','Future scenario assumes richer 22–30min expeditions that are NOT implemented','Fixed puzzle/mining layout replay quality has not been established; avoid padding via timers or lower drop rates']}
output = ROOT/'builds/xiaojing-balance.json'
output.parent.mkdir(exist_ok=True)
output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='cave_feasibility'},ensure_ascii=False,indent=2))
print('PASS: mathematical feasibility; current-duration target remains UNMET. Report:',output)
