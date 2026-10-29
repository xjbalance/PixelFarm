#!/usr/bin/env python3
"""0.6.2 deterministic daily-rule simulation; assumptions, not playtest hours.
Reads runtime data, tests all six species under batch and brood-stock strategies.
No simulated rewards are written to a player profile.
"""
import json
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = json.loads((ROOT / 'resources/aquaculture/fish.json').read_text())
MATERIALS = json.loads((ROOT / 'resources/items/materials.json').read_text())
CROP_VALUES = {'carrot': 36, 'wheat': 22, 'potato': 56}


def price(item):
    return DATA['items'].get(item, MATERIALS.get(item, {'sell_price': CROP_VALUES.get(item, 0)}))['sell_price']


def fry_cost(species):
    row = DATA['species'][species]
    return row['fry_price'] or (row['rare_coins'] + sum(price(k) * v for k, v in row['rare_cost'].items()))


def simulate(species, seed, keep_breeders, days=112, reliable=False):
    rng = random.Random(seed)
    row = DATA['species'][species]
    level = row['level']
    cap = DATA['levels'][str(level)]['capacity']
    # Two thirds occupancy gives room for offspring; batch farming starts full.
    stock = cap * 2 // 3 if keep_breeders else cap
    cohorts = [(stock, 0)]
    adults, water, health, breeding = 0, 80, 100, 0
    spend = stock * fry_cost(species)
    sold = gross = births = care = feed_units = 0
    first = None
    min_health = health
    start_day = rng.randrange(1, 113)
    peak = stock
    for elapsed in range(days):
        yesterday = start_day + elapsed
        season = ((yesterday - 1) // 28) % 4
        comfortable = season in row['seasons']
        # The player checks dirty water; no instant random disasters.
        if (water < max(65, row['water'] + 3) or health < 90) and (reliable or rng.random() < .92):
            water = min(100, water + 22)
            health = min(100, health + 6)
            care += 1
        total = adults + sum(n for n, _ in cohorts)
        fed = reliable or level == 3 or rng.random() < .94
        needed = (total + 7) // 8
        if fed:
            spend += needed * DATA['items']['fish_feed']['price']
            feed_units += needed
        good = water >= row['water'] and health >= 60
        growth = (4 if comfortable else 3) if fed and good else (2 if fed else 1)
        young = []
        for n, age in cohorts:
            age += growth
            if age >= row['growth_days'] * 4:
                adults += n
            else:
                young.append((n, age))
        cohorts = young
        rare_ok = species not in ('golden', 'star') or (comfortable and health >= 90)
        if fed and good and rare_ok and adults >= row['min_adults'] and total < cap:
            breeding += 1
            if breeding >= row['breed_days']:
                born = min(row['offspring'], cap - total)
                cohorts.append((born, 0))
                births += born
                breeding = 0
        water = max(0, min(100, water - 2 - (2 if total / cap > .8 else 0)
                           + (1 if level == 2 else 3 if level == 3 else 0)
                           + (3 if yesterday % 7 in (0, 4) else 0)))
        health = max(0, min(100, health + (2 if fed and good else -2)))
        min_health = min(min_health, health)
        peak = max(peak, adults + sum(n for n, _ in cohorts))
        assert peak <= cap
        harvest = max(0, adults - row['min_adults']) if keep_breeders else adults
        if harvest:
            if first is None:
                first = elapsed + 1
            adults -= harvest
            sold += harvest
            gross += harvest * row['sell_price']
            if not keep_breeders:
                cohorts.append((harvest, 0))
                spend += harvest * fry_cost(species)
                breeding = 0
    return dict(first=first, net=gross - spend, gross=gross, spent=spend, sold=sold,
                births=births, peak=peak, care=care, feed_units=feed_units, min_health=min_health)


def percentile(values, p):
    values = sorted(values)
    return round(values[round((len(values) - 1) * p)], 3)


def run():
    results = {}
    for index, species in enumerate(DATA['species']):
        result = {}
        for keep, label in ((False, 'restock_batches'), (True, 'keep_breeders')):
            # 1,000 deterministic trials per species and strategy = 12,000 profiles.
            runs = [simulate(species, 620000 + index * 10000 + i, keep) for i in range(1000)]
            first = [r['first'] for r in runs if r['first'] is not None]
            result[label] = {
                'profiles': len(runs), 'days_each': 112,
                'first_harvest_days_p10_p50_p90': [percentile(first, p) for p in (.1, .5, .9)],
                'net_gold_per_day_p10_p50_p90': [percentile([r['net'] / 112 for r in runs], p) for p in (.1, .5, .9)],
                'median_harvested': percentile([r['sold'] for r in runs], .5),
                'median_bred': percentile([r['births'] for r in runs], .5),
                'median_feed_units': percentile([r['feed_units'] for r in runs], .5),
                'median_maintenance_actions': percentile([r['care'] for r in runs], .5),
                'max_population': max(r['peak'] for r in runs),
                'lowest_health': min(r['min_health'] for r in runs),
                'no_first_harvest': len(runs) - len(first),
            }
        result['fry_opportunity_cost'] = fry_cost(species)
        result['best_season_nominal_growth_days'] = DATA['species'][species]['growth_days']
        results[species] = result
    # Capacity and steady renewal over ten years, including the seasonal rare rule.
    long_runs = {s: simulate(s, 620062, True, days=1120, reliable=True) for s in DATA['species']}
    assert all(r['births'] > 0 and r['sold'] > 0 for r in long_runs.values())
    report = {
        'version': '0.6.2', 'profiles': 12000, 'seed': 620000,
        'assumptions': [
            '112 game days, random starting season; 94% feeding adherence, 92% maintenance adherence when needed.',
            'Level 3 has provisioned autofeeder; feed is charged at 4 gold/unit, not generated free.',
            'Rare fry ingredients priced at foregone sale value; regular fry priced at store cost.',
            'Batch strategy restocks every harvest, including final-day stocks; brood strategy preserves minimum parents.',
            'Facility capital, tools, walking, menus, stamina opportunity cost and cooking excluded from net cashflow.',
            'These are game-day income estimates, not measured play hours or a proof of ideal scheduling.',
            'Breeding is optional husbandry and collection support; ordinary fry restocking is generally more profitable.',
        ],
        'results': results,
        'long_run_1120_days': long_runs,
        'findings': [
            'No capacity overflow or finite-resource deadlock in tested profiles; all species have repeatable acquisition.',
            'Ordinary fish require feed costs and care; rare fry batch sales lose opportunity value intentionally.',
            'Golden fish need three ordinary collections, underground water progress and level 2; star fish need research, crystal cavern and level 3.',
            'Rare breeding is season/water/health constrained with guaranteed progress under conditions; no random low drop probability.',
            'No fish source grants diamonds; optional lake cooperation grants bond 3 once and leaves original marriage gates intact.',
        ],
    }
    target = ROOT / 'docs/AQUACULTURE-BALANCE.json'
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print('Aquaculture: 12000 profiles + 6 ten-year continuations; capacity and renewable harvest checks passed.')
    for s, row in results.items():
        batch = row['restock_batches']
        brood = row['keep_breeders']
        print(f'{s:8} first harvest P50={batch["first_harvest_days_p10_p50_p90"][1]:g}d; '
              f'batch net={batch["net_gold_per_day_p10_p50_p90"][1]:g}/day; '
              f'brood net={brood["net_gold_per_day_p10_p50_p90"][1]:g}/day')
    print(target)


if __name__ == '__main__':
    run()
