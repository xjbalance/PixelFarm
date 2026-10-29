"""Validate the actual content graph, icons, attainable inputs and bounded value chains."""
from pathlib import Path
import json, re, hashlib
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
def unique_object(pairs):
    result={}
    for key,value in pairs:
        if key in result:raise ValueError('Duplicate JSON ID: '+key)
        result[key]=value
    return result
def read(path):return json.loads((ROOT/path).read_text(),object_pairs_hook=unique_object)
def validate():
    data=read('resources/harvest/harvest.json');items={};sources=set();errors=[]
    for crop in (ROOT/'resources/crops').glob('*.tres'):
        s=crop.read_text();id=re.search(r'id = "(.*?)"',s)[1];price=int(re.search(r'sell_price = (\d+)',s)[1]);items[id]={'sell_price':price};sources.add(id)
    economy=read('resources/seasons/economy.json')
    for group in economy['groups'].values():
        definitions=read(group['path'].removeprefix('res://'));definitions=definitions[group['section']] if group['section'] else definitions
        for id,info in definitions.items():
            assert id not in items,id
            items[id]=info
    # These are actual harvest/feed/animal/forage/normal fishing sources, not all registered IDs.
    sources.update(['wood','stone','egg','milk','wool','wild_berry','fish_carp','fish_crucian'])
    for id,crop in data['crops'].items():
        assert id not in items,id
        assert 1<=crop['growth_days']<=28 and crop['seasons'] and all(s in range(4) for s in crop['seasons'])
        assert crop['seed_price']>0 and 1<=crop['harvest_quantity']<=3 and crop['watering']=='daily'
        assert crop['uses'],id+' has no downstream use'
        items[id]=crop;sources.add(id)
        assert Image.open(ROOT/f'assets/harvest/crops/{id}.png').size==(128,40)
        for icon in [id,id+'_seed']:assert Image.open(ROOT/f'assets/harvest/items/{icon}.png').size==(32,32)
    for id,info in data['items'].items():
        assert id not in items,id
        items[id]=info
        assert Image.open(ROOT/info['icon'].removeprefix('res://')).size==(32,32)
        assert info['name'] and '\ufffd' not in info['name'] and info['description']
    for tree,info in data['orchard'].items():
        sources.add(info['fruit']);assert info['fruit'] in items
        for stage in ['young','growing','mature','fruit']:assert (ROOT/f'assets/harvest/orchard/{tree}_{stage}.png').exists()
    for group in [list(data['crops'])+list(data['orchard']),list(data['recipes'])]:
        signatures=[hashlib.sha256((ROOT/f'assets/harvest/items/{id}.png').read_bytes()).hexdigest() for id in group]
        assert len(signatures)==len(set(signatures)),'Distinct raw produce and dishes must not share identical icon bitmaps'
    recipes={**data['processing'],**data['recipes']};assert len(recipes)==len(data['processing'])+len(data['recipes'])
    edges={};costs=[]
    for id,r in recipes.items():
        assert r['recipe_id']==id and r['output_item_id'] in items and isinstance(r['output_quantity'],int) and r['output_quantity']>0
        assert r['processing_station_id'] in list(data['stations'])+['kitchen']
        assert r['processing_duration']>=0 and (r['processing_duration']>0 or r['processing_station_id']=='kitchen')
        assert r['input_items'] and all(k in items and isinstance(q,int) and 1<=q<=999 for k,q in r['input_items'].items())
        assert 'diamond' not in r['output_item_id']
        edges.setdefault(r['output_item_id'],set()).update(r['input_items'])
        cost=sum(items[k]['sell_price']*q for k,q in r['input_items'].items());value=items[r['output_item_id']]['sell_price']*r['output_quantity']
        assert value<=cost*1.6 or r['output_item_id'] in ['flour','dried_fish','smoked_fish','cheese'],(id,cost,value)
        costs.append({'recipe':id,'inputs_sale_value':cost,'output_sale_value':value,'margin':value-cost,'game_minutes':r['processing_duration']})
    def visit(id,path):
        assert id not in path,'Recipe cycle: '+str(path+[id])
        for dep in edges.get(id,[]):visit(dep,path+[id])
    for id in edges:visit(id,[])
    available=set(sources)
    while True:
        before=len(available)
        for r in recipes.values():
            if set(r['input_items'])<=available:available.add(r['output_item_id'])
        if len(available)==before:break
    for id,r in recipes.items():assert set(r['input_items'])<=available,(id,'unreachable',set(r['input_items'])-available)
    for id,crop in data['crops'].items():assert any(id in r['input_items'] for r in recipes.values()),id
    for id,r in data['stations'].items():
        assert Image.open(ROOT/r['icon'].removeprefix('res://')).size==(32,48)
        assert any(p['processing_station_id']==id for p in data['processing'].values())
    yearly=[]
    for id,crop in data['crops'].items():
        growing=None;cash=0;planted=0;harvested=0;waterings=0
        for day in range(112):
            season=day//28
            if growing is not None and growing>=crop['growth_days']:
                harvested+=crop['harvest_quantity'];cash+=crop['harvest_quantity']*crop['sell_price'];growing=None
            if growing is None and season in crop['seasons']:
                growing=0;cash-=crop['seed_price'];planted+=1
            if growing is not None and season in crop['seasons']:
                growing+=1;waterings+=1
        yearly.append({'crop':id,'days':112,'plots':1,'seed_purchases':planted,'harvested':harvested,'watering_actions':waterings,'net_gold':cash,'unharvested_growth_days':growing})
    for row in costs:
        if row['game_minutes']>0:row['theoretical_batches_per_24h']=1440//row['game_minutes']
    assert data['processing']['corn_feed']['output_quantity']*items['hay']['price']>=items['corn']['sell_price'],'Feed should be useful compared with buying hay'
    report={'crops':len(data['crops']),'trees':len(data['orchard']),'stations':len(data['stations']),'processing':len(data['processing']),'dishes':len(data['recipes']),'recipes':costs,'yearly_one_plot_simulation':yearly,'simulation_assumptions':['112 days, one plot, full-price seeds, all relevant unlocks earned','Water every suitable day; harvest at the following morning; off-season growth pauses','No labor/energy valuation, rainfall bonus, seed discount or terminal crop liquidation','Device throughput is an ideal upper bound; actual collection and night gaps lower output'],'unavailable_extensions':data['future']}
    (ROOT/'docs/quality081').mkdir(exist_ok=True,parents=True)
    (ROOT/'docs/quality081/harvest-validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print('HARVEST DATA PASS:',{k:v for k,v in report.items() if isinstance(v,int)})
if __name__=='__main__':validate()
