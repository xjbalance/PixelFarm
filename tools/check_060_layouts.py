"""检查100层真实地格的闭闸/开闸可达性与独立布局，不替代Godot物理验证。"""
from pathlib import Path
from collections import deque
import json
R=Path(__file__).resolve().parents[1]
data=json.loads((R/'resources/abyss/floors.json').read_text())
def cells(d):
 s=set()
 for x,y,w,h in d['floors']:
  s.update((i,j) for i in range(max(1,x),min(39,x+w)) for j in range(max(1,y),min(27,y+h)))
 return s
def reach(s,start):
 q=deque([tuple(start)]);seen={tuple(start)}
 while q:
  x,y=q.popleft()
  for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
   p=(x+dx,y+dy)
   if p in s and p not in seen: seen.add(p);q.append(p)
 return seen
errors=[]
for d in data:
 s=cells(d);x,y,w,h=d['gate'];closed=s-{(i,j) for i in range(x,x+w) for j in range(y,y+h)}
 if d['shortcut']:
  x,y,w,h=d['shortcut'];closed-={(i,j) for i in range(x,x+w) for j in range(y,y+h)}
 pre=reach(closed,d['entry']);post=reach(s,d['entry'])
 for p in [d['hint'],*d['controls'],*d['utility']]:
  if tuple(p) not in pre: errors.append((d['depth'],'pre',p))
 for p in [d['exit'],d['chest'],*d['ores']]:
  if tuple(p) not in post: errors.append((d['depth'],'post',p))
 if tuple(d['exit']) in pre: errors.append((d['depth'],'gate bypass'))
assert not errors,errors
assert len(data)==100 and len({json.dumps(d['floors']) for d in data})==100
assert len({tuple(sorted(cells(d))) for d in data})==100
print('PASS: 100 unique layouts, all clue/control/utility routes before gate, all exits/chests/ores after gate, no gate bypass.')
