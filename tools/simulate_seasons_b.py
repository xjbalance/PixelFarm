"""0.7.0 stage B operating models; explicit assumptions, not measured playtime.

Channels are simulated independently. Their income must not be added as though one
player sold and processed the same inputs or had unlimited stamina and time.
"""
from __future__ import annotations
import json
import math
from pathlib import Path
import random
import re
import statistics

ROOT = Path(__file__).resolve().parents[1]
SAMPLES = 10000
HORIZON = 28
SEED = 707020
load = lambda name: json.loads((ROOT/name).read_text())
CLIMATE = load('resources/seasons/climate.json')
FISHING = load('resources/fishing/fishing.json')
LIVESTOCK = load('resources/livestock/livestock.json')
KITCHEN = load('resources/kitchen/kitchen.json')
ECOLOGY = load('resources/ecology/config.json')
AQUA = load('resources/aquaculture/fish.json')
ECONOMY = load('resources/seasons/economy.json')
CROPS = {}
PRICES = {}
for path in (ROOT/'resources/crops').glob('*.tres'):
    raw = path.read_text()
    crop_id = re.search(r'^id = "([^"]+)"', raw, re.M).group(1)
    row = {key: int(re.search(r'^'+key+r' = (\d+)', raw, re.M).group(1))
           for key in ['seed_price', 'sell_price', 'growth_days']}
    CROPS[crop_id] = row
    PRICES[crop_id] = row['sell_price']
for row in ECONOMY['groups'].values():
    raw = load(row['path'].removeprefix('res://'))
    entries = raw[row['section']] if row['section'] else raw
    for key, value in entries.items():
        PRICES[key] = int(value['sell_price'])

def percentile(values, fraction):
    values = sorted(values)
    at = (len(values)-1)*fraction
    low = math.floor(at)
    high = math.ceil(at)
    return values[low]+(values[high]-values[low])*(at-low)

def quantiles(values):
    return {name: round(percentile(values, frac), 3)
            for name, frac in [('p10', .1), ('p50', .5), ('p90', .9)]}

def season(day):
    return ((day-1)//28) % 4

def weather(day):
    if day <= 28:
        return 'rain' if day % 7 in [4, 0] else ('cloudy' if day % 7 == 5 else 'clear')
    index = season(day)
    season_id = CLIMATE['seasons'][index]['id']
    anchor = CLIMATE['anchors'][season_id]
    local = (day-1) % 28+1
    if str(local) in anchor:
        return anchor[str(local)]
    world_seed = CLIMATE['default_seed']
    value = (day*1103515245+world_seed*2654435761+((day-1)//112+1)*12345) & 0x7fffffff
    roll = value % 100
    for key, weight in CLIMATE['seasons'][index]['weights'].items():
        roll -= weight
        if roll < 0:
            return key
    return 'clear'

def farm_profile(rng, start):
    allowed = [key for key in CROPS if season(start) in ECONOMY['crop_seasons'][key]]
    crop_id = rng.choice(allowed)
    crop = CROPS[crop_id]
    count = rng.randint(12, 30)
    irrigated = rng.random() < .6
    adherence = rng.uniform(.90, .99)
    age = [0]*count
    wet = [False]*count
    net = -crop['seed_price']*count
    seconds = 0.0
    energy = 0
    for offset in range(HORIZON):
        day = start+offset
        rain = weather(day) in ['rain', 'heavy_rain', 'storm']
        actions = 0
        for index in range(count):
            if wet[index]:
                age[index] += 1
            if age[index] >= crop['growth_days']:
                net += crop['sell_price']-crop['seed_price']
                age[index] = 0
                actions += 2
                energy += 2
            wet[index] = rain or irrigated or rng.random() < adherence
            if not rain and not irrigated and wet[index]:
                actions += 1
                energy += 1
        seconds += actions*2.0+20+(5 if irrigated and not rain else 0)
    return {'income': net/HORIZON, 'seconds': seconds/HORIZON,
            'energy': energy/HORIZON, 'crop': crop_id, 'plots': count}

def fishing_profile(rng, start):
    rod = rng.choices([1, 2, 3], [.35, .40, .25])[0]
    habitat = rng.choice(['lake', 'river', 'cavern'])
    ecology = rng.randint(20, 100)
    advanced = rod >= 2 and rng.random() < .6
    cooperation = rng.random() < .35
    skill = rng.uniform(.60, .93)
    net = 0.0
    seconds = 0.0
    attempts = 0
    landed = 0
    rare = 0
    legend = False
    pity = 0
    for offset in range(HORIZON):
        day = start+offset
        climate = weather(day)
        minute = 1260 if rng.random() < .25 else rng.randint(600, 1080)
        available = []
        weights = []
        for key, row in FISHING['species'].items():
            if rod < row['rod'] or habitat not in row['habitats'] or season(day) not in row['seasons']:
                continue
            if row['weather'] and climate not in row['weather']:
                continue
            if not row['hours'][0] <= minute < row['hours'][1]:
                continue
            if key in ['golden', 'star'] and not advanced:
                continue
            if key == 'eternal' and not (ecology >= 90 and cooperation and climate == 'meteor' and minute >= 1200 and not legend):
                continue
            weight = float(row['weight'])
            if habitat == 'lake' and key in ['golden', 'star', 'eternal']:
                weight *= min(1.5, max(.5, 1+(ecology-70)/60))
            available.append(key)
            weights.append(max(1, math.floor(weight+.5)))
        if not available:
            continue
        cap = min(FISHING['daily_casts'], 8 if habitat == 'lake' and ecology < 40 else FISHING['daily_casts'])
        casts = rng.randint(4, cap)
        seconds += {'lake': 30, 'river': 50, 'cavern': 80}[habitat]
        for _ in range(casts):
            species = 'eternal' if 'eternal' in available and pity >= 3 else rng.choices(available, weights)[0]
            if 'eternal' in available:
                pity = min(4, pity+1)
            row = FISHING['species'][species]
            net -= FISHING['bait_price']
            attempts += 1
            probability = min(.96, max(.20, skill-(row['difficulty']-1)*.11+(rod-1)*.035))
            seconds += rng.uniform(1.5, 3.1)+rng.uniform(7, 14)+2
            if rng.random() < probability:
                net += PRICES[row['item']]
                landed += 1
                if species in ['golden', 'star', 'eternal']:
                    rare += 1
                if species == 'eternal':
                    legend = True
                    pity = 0
                    index = available.index('eternal')
                    available.pop(index)
                    weights.pop(index)
    return {'income': net/HORIZON, 'seconds': seconds/HORIZON,
            'energy': attempts*FISHING['energy_per_cast']/HORIZON,
            'attempts': attempts/HORIZON, 'landed': landed/HORIZON,
            'rare': rare, 'rod': rod, 'habitat': habitat, 'ecology': ecology}

def livestock_profile(rng, start):
    occupants = []
    for key in LIVESTOCK['species']:
        for _ in range(2):
            occupants.append({'species': key, 'hunger': 15, 'mood': 85, 'progress': 0, 'product': 0})
    adherence = rng.uniform(.90, .99)
    net = 0.0
    seconds = 0.0
    energy = 0
    feed = 0
    output = {'egg': 0, 'milk': 0, 'wool': 0}
    for offset in range(HORIZON):
        day = start+offset
        grazing = {key: season(day) != 3 and weather(day) in ['clear', 'cloudy', 'meteor'] and rng.random() < .8
                   for key in LIVESTOCK['species']}
        actions = sum(grazing.values())
        for entry in occupants:
            row = LIVESTOCK['species'][entry['species']]
            grass = grazing[entry['species']]
            fed = grass or rng.random() < adherence
            if fed and not grass:
                units = row['feed']
                feed += units
                net -= units*LIVESTOCK['items']['hay']['price']
                actions += 1
                entry['hunger'] = max(0, entry['hunger']-60)
                entry['mood'] = min(100, entry['mood']+4)
            if fed:
                entry['hunger'] = 15 if grass else min(100, entry['hunger']+15)
                entry['mood'] = min(100, entry['mood']+3)
            else:
                entry['hunger'] = min(100, entry['hunger']+25)
                entry['mood'] = max(0, entry['mood']-5)
            if rng.random() < .2:
                entry['mood'] = min(100, entry['mood']+7)
                energy += 1
                actions += 1
            if fed and entry['hunger'] <= 65 and entry['mood'] >= 35 and entry['product'] < 3:
                entry['progress'] += 1
                if entry['progress'] >= row['cycle']:
                    entry['product'] += 1
                    entry['progress'] = 0
            if entry['product'] and rng.random() < .94:
                output[row['product']] += entry['product']
                net += PRICES[row['product']]*entry['product']
                entry['product'] = 0
                actions += 1
        seconds += actions*1.8+45
    return {'income': net/HORIZON, 'seconds': seconds/HORIZON,
            'energy': energy/HORIZON, 'hay': feed/HORIZON,
            'output': output}

def processing_profile(rng, start):
    stock = {key: 0 for key in ['wheat', 'milk', 'fish_carp', 'wild_berry', 'wood']}
    queue = []
    margin = 0.0
    seconds = 0.0
    completed = 0
    peak = 0
    inputs = {'wheat': 6, 'milk': 2, 'fish_carp': 3, 'wild_berry': 2, 'wood': 2}
    for offset in range(HORIZON):
        day = start+offset
        actions = 0
        for key, amount in inputs.items():
            stock[key] += 1 if key == 'wild_berry' and season(day) == 3 else amount
        for job in list(queue):
            if job['ready'] <= offset and rng.random() < .94:
                row = KITCHEN['processing'][job['recipe']]
                margin += job['batches']*(value(row['rewards'])-value(row['required']))
                completed += job['batches']
                actions += 1
                queue.remove(job)
        options = list(KITCHEN['processing'])
        rng.shuffle(options)
        for key in options:
            if len(queue) >= 4:
                break
            row = KITCHEN['processing'][key]
            batches = min([rng.randint(1, 8)]+[stock[item]//amount for item, amount in row['required'].items()])
            if batches < 1:
                continue
            for item, amount in row['required'].items():
                stock[item] -= amount*batches
            queue.append({'recipe': key, 'batches': batches, 'ready': offset+row['days']})
            actions += 1
            peak = max(peak, len(queue))
        assert len(queue) <= 4
        seconds += actions*2+25
    locked = sum(value(KITCHEN['processing'][job['recipe']]['required'])*job['batches'] for job in queue)
    return {'income': margin/HORIZON, 'seconds': seconds/HORIZON, 'energy': 0,
            'locked_inputs': locked, 'completed': completed/HORIZON, 'peak_queue': peak}

def value(items):
    return sum(PRICES[item]*amount for item, amount in items.items())

def ecology_profile(rng, start):
    health = ECOLOGY['initial_health']
    plants = 0
    cycle = False
    debris = 0
    restored = False
    first = None
    costs = 0
    energy = 0
    actions = 0
    crowd = rng.randint(0, 4)
    for offset in range(HORIZON):
        day = start+offset
        if (health < 90 or debris > 0) and rng.random() < .95:
            debris = max(0, debris-1)
            health = min(100, health+ECOLOGY['clean_health'])
            energy += ECOLOGY['clean_energy'];actions += 1
        if plants < ECOLOGY['restoration_plants'] and rng.random() < .95:
            costs += value(ECOLOGY['plants_required'])
            plants += 1
            health = min(100, health+ECOLOGY['plant_health'])
            energy += ECOLOGY['plant_energy'];actions += 1
        if plants >= ECOLOGY['restoration_plants'] and not cycle:
            costs += value(ECOLOGY['cycle_required'])+ECOLOGY['cycle_coins']
            cycle = True;health = min(100, health+6);actions += 1
        if not restored and cycle and plants >= ECOLOGY['restoration_plants'] and health >= ECOLOGY['restoration_health'] and debris == 0:
            costs -= ECOLOGY['reward_coins']+value(ECOLOGY['reward_items'])
            restored = True;first = offset+1;actions += 1
        if weather(day) == 'storm':
            debris = min(3, debris+1)
        change = (1 if plants >= 3 else 0)+(2 if cycle else 0)-min(6, crowd*2)-debris
        health = min(100, max(0, health+change))
        assert 0 <= health <= 100
    return {'income': -costs/HORIZON, 'seconds': actions*3/HORIZON+15,
            'energy': energy/HORIZON, 'first': first, 'health': health, 'crowd': crowd}

def recipe_audit():
    rows = []
    for group, entries in [('kitchen_processing', KITCHEN['processing']), ('cooking', KITCHEN['recipes']), ('lake_processing', AQUA['recipes'])]:
        for key, row in entries.items():
            required = value(row['required'])
            revenue = value(row['rewards'])
            margin = revenue-required
            ratio = margin/required if required else None
            # Flag large input-value multiplication. Smaller positive margins still
            # require real ingredients and queue/time limits, and are reported.
            suspect = required == 0 and revenue > 0 or required > 0 and margin > 25 and ratio > .5
            rows.append({'group': group, 'id': key, 'input_opportunity_gold': required,
                         'output_sale_gold': revenue, 'margin_gold': margin,
                         'margin_ratio': round(ratio, 4) if ratio is not None else None,
                         'large_risk_flag': suspect})
    return rows

def summarize(rows):
    return {'net_gold_per_game_day': quantiles([r['income'] for r in rows]),
            'assumed_active_seconds_per_game_day': quantiles([r['seconds'] for r in rows]),
            'stamina_per_game_day': quantiles([r['energy'] for r in rows])}

def main():
    rng = random.Random(SEED)
    result = {key: [] for key in ['farming', 'fishing', 'livestock', 'processing', 'ecology']}
    for index in range(SAMPLES):
        start = 1+28*(index % 4)
        result['farming'].append(farm_profile(rng, start))
        result['fishing'].append(fishing_profile(rng, start))
        result['livestock'].append(livestock_profile(rng, start))
        result['processing'].append(processing_profile(rng, start))
        result['ecology'].append(ecology_profile(rng, start))
    audit = recipe_audit()
    report = {
        'version': '0.7.0-stage-B', 'seed': SEED, 'profiles': SAMPLES,
        'days_per_profile': HORIZON, 'channels_independent_do_not_sum': True,
        'model_not_human_playtest': True,
        'source_configs': ['resources/crops/*.tres', 'resources/seasons/economy.json', 'resources/seasons/climate.json',
                           'resources/fishing/fishing.json', 'resources/livestock/livestock.json', 'resources/kitchen/kitchen.json',
                           'resources/ecology/config.json', 'resources/aquaculture/fish.json'],
        'assumptions': [
            '10000 independent 28-day segments, evenly covering spring/summer/autumn/winter; deterministic engine climate formula and source prices.',
            'Channels are alternative operating models, not a joint single-player schedule. Never add their medians or count sold ingredients again as processed inputs.',
            'Farming: 12-30 plots, one season-compatible crop, 90-99% manual care, 60% with existing well/irrigation. New seeds paid; closing immature crops have no cash value.',
            'Fishing: 4 to ecology-adjusted cap casts/day, store bait 4 gold/cast even on failure, rod mix 35/40/25%, random accessible habitat, 25% night sessions.',
            'Fishing catch probability is an explicit skill assumption 0.60-0.93 adjusted by configured difficulty/rod; it is not engine QTE or real player measurement.',
            'Fishing rare aquaculture unlocks are assumed for 60% of advanced-rod profiles. Eternal carp is zero-sale, ecology+weather+cooperation gated, at most one per modeled season.',
            'Livestock: two existing adults of each species, 90-99% feeding adherence, legal morning grazing on 80% of suitable days, 94% product collection, daily storage cap3.',
            'Building capital, animal/fishing gear purchase, prior unlock work, injury, buffs and dialogue are excluded. Reported cashflow is not a complete new-game return-on-investment.',
            'Processing: four queue slots, batches<=8, real recipe delays, limited supplied raw material quotas/day (wheat6,milk2,carp3,berries2 or winter1,wood2).',
            'Processing income is incremental realized sale margin vs selling those exact inputs, only for claimed jobs; closing work-in-progress value is separate. It is not extra free source income.',
            'Ecology: density0-4, maintained fishpen water, source daily weather/storm debris, 95% care adherence, first three water plants and one cycle repair with real ingredient opportunity costs.',
            'Action times are assumed (farm2s/action, livestock1.8s, fishing1.5-3.1s wait plus7-14s minigame plus2s handling, home processing2s/action), with stated travel allowances.',
            'One real second=2 game minutes is preserved. Menus pause world time; assumed active seconds do not prove a feasible nine-minute real session or optimal joint stamina allocation.'
        ],
        'results': {key: summarize(rows) for key, rows in result.items()},
        'fishing_detail': {
            'casts_per_game_day': quantiles([r['attempts'] for r in result['fishing']]),
            'landed_per_game_day': quantiles([r['landed'] for r in result['fishing']]),
            'income_by_rod': {str(level): quantiles([r['income'] for r in result['fishing'] if r['rod'] == level]) for level in [1,2,3]},
            'configured_max_casts': FISHING['daily_casts'], 'energy_per_cast': FISHING['energy_per_cast']
        },
        'livestock_detail': {
            'hay_per_day': quantiles([r['hay'] for r in result['livestock']]),
            'steady_full_manual_feed_margin_per_adult_day': {key: round(PRICES[row['product']]/row['cycle']-row['feed']*LIVESTOCK['items']['hay']['price'],3) for key,row in LIVESTOCK['species'].items()}
        },
        'processing_detail': {
            'peak_queue': max(r['peak_queue'] for r in result['processing']),
            'claimed_batches_per_day': quantiles([r['completed'] for r in result['processing']]),
            'closing_locked_input_value': quantiles([r['locked_inputs'] for r in result['processing']])
        },
        'ecology_detail': {
            'restoration_day': quantiles([r['first'] for r in result['ecology'] if r['first'] is not None]),
            'not_restored_within_segment': sum(r['first'] is None for r in result['ecology']),
            'closing_health': quantiles([r['health'] for r in result['ecology']]),
            'construction_health_cost_per_extra_pen': 3,
            'minimum_clean_cycle_recovery_with_four_crowded_clean_pens_no_debris': ECOLOGY['clean_health']+3-6
        },
        'recipe_audit': audit,
        'large_recipe_risks': [row for row in audit if row['large_risk_flag']],
        'findings': [
            'Daily cast cap plus bait/stamina costs bounds fishing. Skill rates are assumptions and need real playtest calibration.',
            'Animal income requires adult growth/unlock/capital outside this segment, each animal has finite daily output and storage; winter removes free grazing.',
            'All cooking recipes sell below ingredient opportunity cost in current configuration. Processing margins are small and constrained by ingredient sources and queues.',
            'Eco restoration has a one-time investment; density management, daily cleaning and repeatable plants/cycle avoid permanent resource depletion in tested scenarios.',
            'No new modeled source produces diamonds; eternal carp has sale_price0 and is not a currency exchange.',
            'Python models do not prove absence of all exploits. Runtime suites separately test duplicate claims, daily settlement, migration, low-health recovery and actual minigame outcomes.'
        ]
    }
    output = ROOT/'docs/BALANCE-0.7.0-B.json'
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
    for key, rows in result.items():
        print(key, json.dumps(report['results'][key], ensure_ascii=False))
    print('Recipe risk flags:', len(report['large_recipe_risks']))
    print('Profiles:', SAMPLES, 'days:', HORIZON, 'output:', output)
    if report['large_recipe_risks']:
        raise SystemExit('Review high-margin recipes before claiming balance.')

if __name__ == '__main__':
    main()
