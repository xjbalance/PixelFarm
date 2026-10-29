"""Apply the small audited 0.8.1 adjustments and regenerate the existing harvest data."""
from pathlib import Path
import json,re,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
policy=json.loads((ROOT/'resources/harvest/balance_081.json').read_text())
path=ROOT/'resources/kitchen/kitchen.json';data=json.loads(path.read_text())
for id,values in policy['legacy_item_overrides'].items():data['items'][id].update(values)
data['items']['carrot_stew']['description']=re.sub(r'恢复\d+体力','恢复32体力',data['items']['carrot_stew']['description'])
path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
subprocess.run([sys.executable,str(ROOT/'tools/generate_harvest_data.py')],check=True,cwd=ROOT)
print('Applied bounded 0.8.1 balance policy')
