"""0.6.0模块化关卡：保留前20层稳定布局，镜像模块+独立支路+手工终局。"""
import json,copy,math,wave,struct
from pathlib import Path
from PIL import Image,ImageDraw
R=Path(__file__).resolve().parents[1]
p=R/'resources/abyss/base20.json'
if not p.exists(): p.write_text(json.dumps(json.loads((R/'resources/abyss/floors.json').read_text())[:20],ensure_ascii=False,indent=2)+'\n')
base=json.loads(p.read_text());levels=[]
regions=['废弃矿道','地下水脉','晶石洞窟','远古遗迹','星辉深渊']
sub=['风井','转运间','旧水尺','支架庭','留种台','静压室','折光桥','回程台','观察廊','检修营']
for n in range(1,101):
 d=copy.deepcopy(base[(n-1)%20]);region=(n-1)//20
 if n>20:
  mx=region in (1,3);my=region in (2,3)
  def pt(p): return [39-p[0] if mx else p[0],27-p[1] if my else p[1]]
  def rect(r): return [40-r[0]-r[2] if mx else r[0],28-r[1]-r[3] if my else r[1],r[2],r[3]]
  for key in ('entry','exit','hint','chest'): d[key]=pt(d[key])
  for key in ('controls','ores','hazards'): d[key]=[pt(v) for v in d[key]]
  d['floors']=[rect(v) for v in d['floors']];d['gate']=rect(d['gate'])
  d['title']=regions[region]+'·'+sub[(n-1)%10]+str((n-1)%20+1)
  d['solution']=[(n//3)%3,n%3,(n+1)%3] if n%20 else [1,3,0,2]
  if len(d['controls'])<4 and n%20==0:
   d['controls'].append(pt([10,4]))
  # 星辉区加独立入口支路，保持与旧四种镜像不同的拓扑。
  if region==4:
   d['floors']+=[[2,2,7,4],[2,4,3,20],[3,2,16,3]]
 d['depth']=n;d['theme']=region;d['region']=regions[region]
 d['gear']=1 if n<=10 else (2 if n<=15 else 3 if n<=40 else 4 if n<=60 else 5 if n<=80 else 6 if n<100 else 7)
 d['checkpoint']=n==1 or n%10==0
 d['rule']=['echo','water','prism','rubbing','beacon'][region]
 d['utility']=[] if n<=20 else [pt([8,12]),pt([16,11])]
 if region==4: d['utility']=[[8,12],[16,11]]
 # 工具点接入口侧已有支路；新通道不越过地形主闸。
 for u in d['utility']:
  e=d['entry'];mid=[u[0],e[1]]
  for a,b in [(e,mid),(mid,u)]: d['floors'].append([min(a[0],b[0])-1,min(a[1],b[1])-1,abs(a[0]-b[0])+3,abs(a[1]-b[1])+3])
 d['shortcut']=[d['entry'][0]+1,d['entry'][1]-1,1,1] if n>20 else []
 d['conduit']=copy.deepcopy(base[n-1]['conduit']) if n<=20 else [d['exit'][0]+2,d['exit'][1]] if n==60 else []
 d['hazard_type']=['落石裂缝','回流水','毒雾晶尘','预警机关','低照明星蚀'][region]
 d['ore_items']=['iron_ore','crystal'] if region==0 else ['iron_ore','crystal'] if region==1 else ['crystal','starlight_ore'] if region==2 else ['ancient_shard','starlight_ore'] if region==3 else ['star_fragment','diamond']
 if n<=20: d['ore_items']=['starlight_ore','starlight_ore'] if n>=16 else ['crystal','crystal'] if n>10 else ['iron_ore','iron_ore']
 d['rounds']=2 if n in [40,60,80] else 3 if n==100 else 1
 d['clue']=' → '.join(['风','水','灯','人'][i] for i in d['solution'])
 if n>20: d['record']={'water':'水闸先泄压再转向。居民取水口不在矿车终点，检修员在名单上圈出了两条不同的路。','prism':'晶片只记录光路，不替人判断去留。每一班在自己的刻度旁签名，免得以后只剩一个人的解释。','rubbing':'两块碑面分开保管停用与撤离记录。不是没人愿意留下，而是没有人能替另一班答应继续冒险。','beacon':'星核是旧运输线的蓄能器。风、水、灯、人必须分别接入，终点才会成为回程，而不是一条更深的单行线。'}[d['rule']]
 if n==40: d['record']='回流水库总闸：先泄压、后导流。两轮手柄间需重新核对阀门。停矿时留下的是农田清水与回村的船道。'
 if n==60: d['record']='晶窟调光室：第一轮光轴指向零，第二轮转到二。周砚父亲在检修页旁补写：不能让一个签名替所有人担保。'
 if n==80: d['record']='遗迹议事厅：每轮分别拓印两块碑，不用同一份摹本代替别人的意见。阿禾收藏的口述并没有漏掉反对声。'
 if n==100:
  d.update(title='星河归航台',entry=[20,5],exit=[20,24],hint=[20,3],controls=[[6,9],[14,9],[26,9],[34,9]],utility=[[10,6],[30,6]],gate=[1,14,38,1],floors=[[3,2,34,10],[18,10,5,7],[5,16,30,10]],chest=[32,22],ores=[[8,19],[32,19]],hazards=[[20,16],[15,20],[25,20]],conduit=[20,19],solution=[0,1,2,3],clue='风 → 水 → 灯 → 人',shortcut=[19,12,1,1],record='归航台不是矿仓。三轮分别核对风路、水路与灯路，每轮接好两端信标，再让四座分工台回应。20、40、60、80层的档案缺一不可。合闸后走入星核室，亲手留下共享规则。')
 levels.append(d)
(R/'resources/abyss/floors.json').write_text(json.dumps(levels,ensure_ascii=False,indent=2)+'\n')
p=R/'resources/abyss/legend.json';cfg=json.loads(p.read_text());cfg['implemented']=100;cfg['regions']=[{'from':i*20+1,'to':(i+1)*20,'name':name,'implemented':True} for i,name in enumerate(regions)]
for rank,depth,cost in [(4,40,1200),(5,60,1800),(6,80,2400),(7,99,3000)]:
 cfg['gear'][str(rank)]={'depth':depth,'required':{'star_alloy':4,'crystal':8,'ancient_shard':4} if rank>=6 else {'star_alloy':4,'crystal':12,'starlight_ore':6},'coins':cost}
cfg['gear']['7']['required']['star_fragment']=6
cfg['trials']['cave']={'start':80,'end':100,'air':10};cfg['trials']['mechanism']['conduits']=[20,60,100]
p.write_text(json.dumps(cfg,ensure_ascii=False,indent=2)+'\n')
# 延伸已有原创矿洞图块风格；五区域仍共用一张小图集。
p=R/'assets/tilesets/mines.png';old=Image.open(p).convert('RGBA');img=Image.new('RGBA',(640,32));img.paste(old.crop((0,0,384,32)),(0,0));dr=ImageDraw.Draw(img)
for theme,(floor,wall,line) in enumerate([('#53665b','#303e39','#879580'),('#363c64','#252942','#76739c')],3):
 for offset in range(4):
  x=(theme*4+offset)*32;dr.rectangle((x,0,x+31,31),fill=wall if offset==1 else floor)
  for j in range(0,32,8): dr.line((x,j,x+31,j),fill=line if offset==1 else floor)
  if offset==1: dr.line((x+12,1,x+12,7),fill=line)
  else:
   for k in range(5): dr.point((x+(k*7+3)%31,(k*11+5)%31),fill=line)
img.save(p)
# 婚礼造型沿用角色原像素轮廓，原创礼服与发饰。
p=R/'assets/characters/xiaojing.png';im=Image.open(p).convert('RGBA');dr=ImageDraw.Draw(im);w,h=im.size
# 保持原图尺寸和脚底，避免角色比例改变。
dr.polygon([(w//2-5,h//2),(w//2+5,h//2),(w//2+8,h-5),(w//2-8,h-5)],fill='#e7e5d3');dr.line((w//2,h//2,w//2,h-6),fill='#c4c9bc');dr.rectangle((w//2-6,4,w//2+6,5),fill='#e2c985');im.save(R/'assets/characters/xiaojing_wedding.png')
rate=22050;notes=[262,330,392,330,294,349,440,392,330,392,494,440,349,330,294,262];samples=[]
for i in range(rate*8):
 t=i/rate;f=notes[int(t*2)%len(notes)];env=math.exp(-5*(t*2%1));v=(math.sin(2*math.pi*f*t)+.25*math.sin(4*math.pi*f*t))*.17*env
 samples.append(struct.pack('<h',int(v*32767)))
with wave.open(str(R/'assets/audio/star_vow.wav'),'wb') as out: out.setnchannels(1);out.setsampwidth(2);out.setframerate(rate);out.writeframes(b''.join(samples))
print('100 physical layouts, five atlas themes, original wedding sprite/music generated.')

# 环境铃声与轻风，原创新增，不包含采样或外部音源。
with wave.open(str(R/'assets/audio/star_chimes.wav'),'wb') as out:
 out.setnchannels(1);out.setsampwidth(2);out.setframerate(rate)
 buf=[]
 for i in range(rate*8):
  t=i/rate;phase=t%2;f=[784,1046.5,1174.7,988][int(t/2)%4]
  v=.045*math.exp(-4*phase)*math.sin(2*math.pi*f*t)+.008*math.sin(2*math.pi*110*t)*(1+math.sin(t*1.7))
  buf.append(struct.pack('<h',int(v*32767)))
 out.writeframes(b''.join(buf))
