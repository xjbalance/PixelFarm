"""将二十张手工路线规格写为32px格房间数据；其余八主题仅规划，不生成假场景。"""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SPECS=[
('旧轨余响',6,[(25,6),(31,6),(31,20),(36,20)],[(27,13),(35,13)],[0,2]),
('逆风支架',9,[(25,9),(29,9),(29,23),(36,23)],[(34,9),(34,17)],[1,0,2]),
('沉默的装车口',12,[(25,12),(35,12),(35,22),(28,22)],[(30,17),(36,17)],[2,1]),
('折返的矿灯',15,[(25,15),(30,15),(30,5),(36,5)],[(35,21),(28,21)],[0,1,2]),
('第一座避风站',18,[(25,18),(33,18),(33,7),(27,7)],[(29,23),(36,23)],[2,0,1]),
('两条运粮轨',21,[(25,21),(36,21),(36,6),(28,6)],[(29,12),(34,12)],[1,2,0]),
('卸下的空车',8,[(25,8),(34,8),(34,17),(27,17),(27,24)],[(36,21),(32,21)],[2,0]),
('封在岩里的气流',11,[(25,11),(30,11),(30,22),(36,22),(36,16)],[(34,5),(28,5)],[1,0]),
('回声分岔',14,[(25,14),(36,14),(36,5),(29,5)],[(29,21),(35,21)],[0,2,1]),
('三班人的水位账',17,[(25,17),(29,17),(29,7),(36,7),(36,23)],[(32,12),(35,12)],[2,1,0]),
('浸水的层理',7,[(7,17),(7,23),(32,23)],[(18,18),(18,25)],[1,2,0]),
('温室的旧引水支线',11,[(11,17),(22,17),(22,24),(36,24)],[(31,18),(35,18)],[0,2]),
('倒置刻度',15,[(15,17),(15,24),(29,24),(29,18)],[(7,22),(10,22)],[2,0,1]),
('环形蓄水室',19,[(19,17),(32,17),(32,24),(8,24)],[(7,18),(12,18)],[1,0,2]),
('第二座换气站',23,[(23,17),(23,24),(35,24)],[(12,18),(12,25)],[2,1]),
('晶核的呼吸',27,[(27,17),(10,17),(10,24),(34,24)],[(33,18),(36,18)],[0,1,2]),
('隔开的清水槽',31,[(31,17),(31,24),(6,24),(6,18)],[(19,18),(22,18)],[2,0]),
('无人独占的灯室',9,[(9,17),(9,24),(22,24),(22,18),(35,18)],[(33,24),(36,24)],[1,2,0]),
('关闸之前的签名',17,[(17,17),(33,17),(33,24),(8,24)],[(8,18),(12,18)],[0,2,1]),
('共同决定的停用日',25,[(25,17),(35,17),(35,24),(7,24)],[(13,18),(17,18)],[2,0,3,1]),
]
REGIONS=['旧轨断层','回流水库','赤砂热井','石林风道','倒悬苗圃','月白断崖','黑潮工坊','星核长廊','无名档案','群星归路']
levels=[]
for n,(title,cross,route,spur,solution) in enumerate(SPECS,1):
 horizontal=n>10
 entry=[4,5] if horizontal else [4,23]
 controls=[[6,5],[14,7],[18,10]]+([[10,4]] if n==20 else [])
 hint=[5,10]
 ore=[[9,11],[17,4]]
 approach=[cross,11] if horizontal else [19,cross]
 # 单格切断横贯整图；所有过门路线都受同一碰撞闸控制。
 gate=[1,14,38,1] if horizontal else [22,1,1,26]
 path=[entry,[4,12] if horizontal else [4,cross],approach,route[0]]+route[1:]
 rects=[]
 def room(p,r=1): rects.append([max(1,p[0]-r),max(1,p[1]-r),2*r+1,2*r+1])
 def segment(a,b):
  mid=[b[0],a[1]]
  for start,end in [(a,mid),(mid,b)]:
   rects.append([min(start[0],end[0])-1,min(start[1],end[1])-1,abs(start[0]-end[0])+3,abs(start[1]-end[1])+3])
 for a,b in zip(path,path[1:]): segment(a,b)
 for p in controls+[hint]+ore:
  segment(entry,p);room(p)
 segment(route[1],spur[0]);segment(spur[0],spur[1]);room(spur[1])
 # 深层采用上方控制室，装置分工可达；跨闸只有主桥。
 chest=spur[1]
 note=('停用页写着先借棚安置，再切断温室旧水管；清水被保留下来供居民使用。落款是三班人共同签名。' if n==20 else
       '洪水前的水位刻度与桥上相同。这里记录的是先泄压，再转运住户，最后关闭育苗用水。' if n==10 else
       '这段细管接向温室，并没有通向私人矿仓。需要先恢复清水与检修通道。' if n==12 else
       '巡检记号：保留退路，不以最后一车矿换取居民的清水。')
 levels.append(dict(depth=n,title=title,theme=0 if n<=10 else 1,entry=entry,exit=route[-1],floors=rects,gate=gate,
   controls=controls,hint=hint,ores=ore,chest=chest,solution=solution,clue=' → '.join(['风','水','灯','人'][i] for i in solution),
   record=note,gear=1 if n<=10 else (2 if n<=15 else 3),checkpoint=n in [1,5,10,15,20],
   hazards=[route[1]],conduit=route[-2] if n in [5,12,20] else []))
(ROOT/'resources/abyss/floors.json').write_text(json.dumps(levels,ensure_ascii=False,indent=2)+'\n')
plan={'implemented':20,'planned':100,'regions':[{'from':i*10+1,'to':i*10+10,'name':name,'implemented':i<2,'milestone':(i+1)*10%20==0} for i,name in enumerate(REGIONS)],
 'gear':{'2':{'depth':10,'required':{'iron_bar':8,'crystal':12,'wood':10},'coins':800},'3':{'depth':15,'required':{'star_alloy':6,'crystal':20,'starlight_ore':9},'coins':1600}},
 'greenhouse':[{'id':'clear','title':'清理遗址','required':{'wood':8,'stone':8},'coins':0},
 {'id':'structure','title':'修复建筑结构','required':{'wood':80,'stone':60},'coins':800},
 {'id':'water','title':'恢复水源','required':{'iron_bar':4,'crystal':8},'coins':0},
 {'id':'core','title':'安装晶石能源核心','required':{'star_alloy':8,'starlight_ore':12,'crystal':24},'coins':0},
 {'id':'lamps','title':'点亮1314盏星灯','required':{},'coins':0}],
 'trials':{'management':{'days':12,'seeds':120,'budget':2800,'harvest_each':24,'profit':3500},'planning':{'days':4,'wood':24,'stone':16},'cave':{'start':10,'end':20,'air':10},'mechanism':{'conduits':[5,12,20]},'joint':{'wheat':12,'potato':12,'carrot':12}}}
(ROOT/'resources/abyss/legend.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2)+'\n')
print('20 authored layouts; floors 21–100 remain design-only.')
