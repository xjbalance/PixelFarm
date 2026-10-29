"""100层拓扑与八处可选侧廊审计，输出独立报告。物理碰撞另由Godot验证。"""
from pathlib import Path
from collections import deque,Counter
import json
R=Path(__file__).resolve().parents[1];data=json.loads((R/'resources/abyss/floors.json').read_text())
def cells(d):
 return {(x,y) for a,b,w,h in d['floors'] for x in range(max(1,a),min(39,a+w)) for y in range(max(1,b),min(27,b+h))}
def distances(s,start):
 out={tuple(start):0};q=deque([tuple(start)])
 while q:
  x,y=q.popleft()
  for dx,dy in [(1,0),(-1,0),(0,1),(0,-1)]:
   p=x+dx,y+dy
   if p in s and p not in out: out[p]=out[x,y]+1;q.append(p)
 return out
report=[]
for d in data:
 s=cells(d);x,y,w,h=d['gate'];bar={(i,j) for i in range(x,x+w) for j in range(y,y+h)}
 closed=s-bar
 if d['shortcut']: closed.discard(tuple(d['shortcut'][:2]))
 before=distances(closed,d['entry']);opened=s|{tuple(p) for p in d.get('passage_cells',[])};after=distances(opened,d['entry'])
 critical=[d['hint'],*d['controls'],*d['utility']]
 assert all(tuple(p) in before for p in critical),d['depth']
 assert tuple(d['exit']) not in before,d['depth']
 assert all(tuple(p) in after for p in [d['exit'],d['chest'],*d['ores']]),d['depth']
 assert tuple(d['exit']) not in distances(opened-bar,d['entry']),('passage bypass',d['depth'])
 row={'depth':d['depth'],'region':d['region'],'gate_rounds':d['rounds'],'critical_before_gate':len(critical),'floor_cells':len(s),'mechanism':d['rule'],'post_gate_steps':after[tuple(d['exit'])]}
 if d.get('passage_cells'):
  old=distances(s,d['exit'])[tuple(d['chest'])];new=distances(opened,d['exit'])[tuple(d['chest'])]
  assert new<old and tuple(d['passage_switch']) in after
  row.update(side_route_old_steps=old,side_route_new_steps=new,new_cells=len(d['passage_cells']))
 report.append(row)
assert len({tuple(sorted(cells(d)|{tuple(p) for p in d.get('passage_cells',[])})) for d in data})==100
result={'version':'0.6.1','layers':report,'distinct_topologies':100,'regions':dict(Counter(d['region'] for d in data)),'targeted_floors':[r for r in report if 'side_route_old_steps' in r], 'limitations':['Module/sequence repetition still exists; unique topology is not proof of100 unique experiences.','Continuous movement, ore collision and nav updates are separately checked by Godot stability/river suites.']}
(R/'docs/LEVEL-AUDIT-0.6.1.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print('PASS:100层闭闸/开闸/矿石/宝箱、8处可选支路无主闸绕过；地格拓扑100种。')
