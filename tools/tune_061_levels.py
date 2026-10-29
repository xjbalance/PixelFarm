"""为八个非Boss层增添有实际距离收益的可选侧廊；原通路保持。幂等。"""
from pathlib import Path
import json
from collections import deque
P=Path(__file__).resolve().parents[1]/'resources/abyss/floors.json'
data=json.loads(P.read_text());results=[]
def cells(d):
 return {(x,y) for rx,ry,w,h in d['floors'] for x in range(max(1,rx),min(39,rx+w)) for y in range(max(1,ry),min(27,ry+h))}
def dist(s,a,b):
 q=deque([(tuple(a),0)]);seen={tuple(a)}
 while q:
  (x,y),n=q.popleft()
  if (x,y)==tuple(b): return n
  for dx,dy in [(1,0),(-1,0),(0,1),(0,-1)]:
   p=x+dx,y+dy
   if p in s and p not in seen: seen.add(p);q.append((p,n+1))
 return None
for d in data:
 if d['depth'] not in [27,34,47,54,67,74,87,94]: continue
 if d.get('passage_hazard') in d['hazards']: d['hazards'].remove(d['passage_hazard'])
 s=cells(d);a=d['exit'];b=d['chest'];old=dist(s,a,b);gate=d['gate']
 forbidden={(x,y) for x in range(gate[0],gate[0]+gate[2]) for y in range(gate[1],gate[1]+gate[3])}
 candidates=[]
 for bend in [[a[0],b[1]],[b[0],a[1]]]:
  corridor=set()
  for p,q in [(a,bend),(bend,b)]:
   for x in range(min(p[0],q[0])-1,max(p[0],q[0])+2):
    for y in range(min(p[1],q[1])-1,max(p[1],q[1])+2):
     if 1<=x<39 and 1<=y<27: corridor.add((x,y))
  new=corridor-s
  if new & forbidden or not new: continue
  opened=s|new;gain=old-dist(opened,a,b)
  if gain>=4: candidates.append((gain,new))
 if not candidates: raise RuntimeError(f'No meaningful side passage for {d["depth"]}')
 gain,new=max(candidates,key=lambda x:x[0]);occupied={tuple(p) for p in [d['entry'],d['exit'],d['chest'],d['hint'],*d['ores'],*d['controls'],*d['utility']]}
 switch=next((p for p in sorted(s) if abs(p[0]-a[0])+abs(p[1]-a[1])==2 and p not in occupied),None)
 assert switch
 # 警示位放在新廊中段，仍可付费固定安全设施或走原路。
 warning=sorted(new)[len(new)//2]
 d['passage_cells']=[list(p) for p in sorted(new)];d['passage_switch']=list(switch);d['passage_hazard']=list(warning);d['passage_savings']=gain;d['hazards'].append(list(warning))
 results.append({'depth':d['depth'],'old_steps':old,'open_steps':old-gain,'gain':gain,'new_cells':len(new)})
P.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(results,ensure_ascii=False,indent=2))
