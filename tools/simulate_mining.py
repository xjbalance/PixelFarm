"""0.5.0 production-data economy model. Activity timings are assumptions, not playtests."""
from collections import deque
from itertools import permutations
from pathlib import Path
import json
import math
import random
import statistics

ROOT = Path(__file__).resolve().parents[1]
DATA = json.loads((ROOT / 'resources/mining/mining.json').read_text())
MAPS = json.loads((ROOT / 'resources/mining/maps.json').read_text())
SEED, N = 505201314, 10000


def floor_cells(area):
    layout = MAPS[area]
    cells = set()
    for x, y, w, h in layout['floors']:
        cells.update((i, j) for i in range(x, x+w) for j in range(y, y+h))
    if area == 'mine_b':
        cells.difference_update((x, y) for x in range(25, 29) for y in range(1, 27))
    for gate in layout['gates']:  # model the already solved endgame map
        x, y, w, h = gate['rect']
        cells.update((i, j) for i in range(x, x+w) for j in range(y, y+h))
    return cells


def distance(area, a, b):
    cells = floor_cells(area)
    queue, seen = deque([(tuple(a), 0)]), {tuple(a)}
    while queue:
        at, length = queue.popleft()
        if at == tuple(b):
            return length
        for dx, dy in ((0, 1), (1, 0), (0, -1), (-1, 0)):
            nxt = at[0]+dx, at[1]+dy
            if nxt in cells and nxt not in seen:
                seen.add(nxt)
                queue.append((nxt, length+1))
    raise AssertionError(f'unreachable {area}: {a} -> {b}')


for area, layout in MAPS.items():
    for obj in layout['objects']:
        distance(area, layout['entry'], obj['cell'])

rare = [o for o in MAPS['mine_c']['objects'] if o.get('ore') in ('diamond', 'starlight')]
entry = MAPS['mine_c']['entry']
points = [tuple(entry)] + [tuple(o['cell']) for o in rare]
distances = {(a, b): distance('mine_c', a, b) for a in points for b in points}
tour = min(sum(distances[a, b] for a, b in zip((tuple(entry),)+order, order+(tuple(entry),)))
           for order in permutations(points[1:]))
surface_transit = 0
for area, exit_id in [('mine_a', 'a_down'), ('mine_b', 'b_down')]:
    layout = MAPS[area]
    target = next(o for o in layout['objects'] if o['id'] == exit_id)
    surface_transit += 2*distance(area, layout['entry'], target['cell'])

diamond_veins = sum(o.get('ore') == 'diamond' for o in rare)
star_veins = sum(o.get('ore') == 'starlight' for o in rare)
raw = star_veins*DATA['ores']['starlight']['amount']
recipe = DATA['recipes']['refine']
batches = raw // recipe['required']['starlight_ore']
refine_yield = batches*recipe['diamonds']
assert batches <= 5 and batches*recipe['required']['crystal'] <= 5*DATA['ores']['crystal']['amount']
period = max(DATA['ores'][kind]['regrow'] for kind in ('diamond', 'starlight'))
ore_energy = sum(DATA['ores'][o['ore']]['hits']*DATA['ores'][o['ore']]['energy'] for o in rare)
assert ore_energy == 108 and ore_energy <= 130  # upgraded bedroom, no free stamina assumed
repeatable_expected = diamond_veins*1.25+refine_yield+DATA['commission']['diamonds']


def simulate(with_commissions=True, very_slow=False):
    rng = random.Random(SEED + int(very_slow) + 2*int(with_commissions))
    hours, cycles_list, active_rates, pieces = [], [], [], []
    for _ in range(N):
        diamonds, counter, cycles = 30, 0, 0  # c_chest12 + seven-memory relic18
        mining = farm = logistics = 0.0
        while diamonds < 1314:
            cycles += 1
            for _vein in range(diamond_veins):
                counter += 1
                diamonds += DATA['ores']['diamond']['amount'] + (counter % 4 == 0)
            diamonds += refine_yield
            if with_commissions:
                diamonds += DATA['commission']['diamonds']
            # Lower bound uses actual 32px grid distances and Player.SPEED145.
            # Extra movement, observation and input delays vary by player; no idle days added.
            walk = (tour+surface_transit)*32/145/60
            mining += walk*rng.uniform(1.4, 2.5) + rng.uniform(1.0, 3.0)
            farm += rng.uniform(6, 12) if with_commissions else rng.uniform(3, 7)
            logistics += rng.uniform(1.5, 4.0)  # fuel, processing collection and surface travel
        # Active campaign/520 plants/relationship/trial time assumption, overlapped once.
        progression = rng.uniform(10, 24)
        multiplier = 1.7 if very_slow else rng.uniform(.85, 1.25)
        total_active = (mining+farm+logistics)*multiplier/60
        hours.append(total_active+progression)
        cycles_list.append(cycles)
        active_rates.append((diamonds-30)/total_active)
        pieces.append((mining*multiplier/60, farm*multiplier/60, logistics*multiplier/60, progression))
    hours.sort()
    return {
        'samples': N, 'p10_hours': round(hours[N//10], 2),
        'p50_hours': round(statistics.median(hours), 2), 'p90_hours': round(hours[9*N//10], 2),
        'mean_cycles': statistics.mean(cycles_list),
        'diamonds_per_active_hour_mean': round(statistics.mean(active_rates), 2),
        'mean_hours_by_activity': dict(zip(('mine', 'farm_and_provisions', 'processing_and_travel', 'campaign_relationships_trials'),
                                          (round(statistics.mean(v), 2) for v in zip(*pieces)))),
        'meets_provisional_80_120': 80 <= statistics.median(hours) <= 120,
    }


report = {
    'version': '0.5.0', 'seed': SEED, 'samples_per_scenario': N,
    'balanced_repeatable': simulate(), 'without_commissions': simulate(False),
    'slow_active_play_sensitivity': simulate(True, True),
    'production_data': {
        'advanced_mine_tool_level': 3, 'diamond_veins': diamond_veins,
        'diamond_vein_mean': 1.25, 'drop_randomness': 'none: one guaranteed, every fourth adds one; counter persists',
        'raw_starlight_per_cycle': raw, 'refined_diamonds_per_cycle': refine_yield,
        'commission_per_3_days': DATA['commission']['diamonds'],
        'diamonds_per_3_day_cycle_mean': repeatable_expected,
        'diamond_per_game_day_mean': round(repeatable_expected/period, 3),
        'harvesting_energy_per_cycle': ore_energy,
        'rare_room_tour_grid_steps_lower_bound': tour,
        'return_surface_transit_grid_steps': surface_transit,
        'shortest_walking_minutes_lower_bound': round((tour+surface_transit)*32/145/60, 2),
        'refresh_days': period, 'processing_days': recipe['days'],
    },
    'worst_luck': 'No rare-drop drought: all advanced diamond veins guarantee one and every fourth grants two. Refining is deterministic. No luck-dependent permanent gate.',
    'dead_end_audit': [
        'All configured objects reachable in solved 32px map layouts (abstract floor BFS; actual collision separately tested in Godot).',
        'Repeatable 3-day regeneration requires no diamond, ore purchase, survey payment or Xiaojing unlock.',
        'Optional survey requires existing farm/iron/crystal inputs and never resets boxes or story rewards.',
        'Ordinary pick can acquire copper and iron needed for reinforced pick; reinforced pick can obtain crystal for star pick.',
        'Refining produces diamonds without spending diamonds; commission is optional.',
        'Queue stays available if output inventory full; wrong puzzle inputs reset, return stairs never lock.',
    ],
    'limitations': [
        'This is a mathematical model, not human playtesting or measured 80-120 hours.',
        'Timings outside minimum grid movement are stated assumptions; novice play, idle play and repeat enjoyment remain unverified.',
        'Total 80-120h target is currently unmet; fixed rooms lack sufficient varied endgame content. Do not extend via waiting or lower drop chances.',
        'No full starlight abyss, generated layers or independent animated wedding implemented.',
    ],
}
output = ROOT / 'docs/MINING-BALANCE-0.5.0.json'
output.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
print(json.dumps(report, ensure_ascii=False, indent=2))
print('PASS: production-data simulation and reachability audit; duration target is NOT achieved.')
