"""Generate the content/economy delivery reference from the shipped data, not a separate design list."""
from pathlib import Path
import json,re
ROOT=Path(__file__).resolve().parents[1]
d=json.loads((ROOT/'resources/harvest/harvest.json').read_text())
names={};prices={}
economy=json.loads((ROOT/'resources/seasons/economy.json').read_text())
for group in economy['groups'].values():
    source=json.loads((ROOT/group['path'].removeprefix('res://')).read_text())
    for id,row in (source[group['section']] if group['section'] else source).items():names[id]=row['name'];prices[id]=row['sell_price']
for id,name,price in [('carrot','胡萝卜',36),('potato','土豆',56),('wheat','小麦',22)]:names[id]=name;prices[id]=price
for source in [d['crops'],d['items']]:
    for id,row in source.items():names[id]=row['name'];prices[id]=row['sell_price']
def words(items):return '、'.join(names.get(k,k)+' ×'+str(v) for k,v in items.items())
def seasons(values):return ' / '.join(['春','夏','秋','冬'][x] for x in values)
def table(headers,rows):return '| '+' | '.join(headers)+' |\n| '+' | '.join(['---']*len(headers))+' |\n'+''.join('| '+' | '.join(map(str,row))+' |\n' for row in rows)+'\n'
text='''# 像素世界 0.8.0《丰收工坊》

在原 0.8.0 工程扩展农业生产，保留原三种作物、九格工具栏、点击移动、住宅厨房、全场 DIY 和现有剧情系统。新增 27 种季节作物、3 种花卉、4 种结果树、10 类实体加工设备、49 条分钟制加工配方、27 道料理和两种织物家具。

## 玩家入口

1. 林芽种子摊 → 种子与收获：按当季供货，支持分页和花卉分类。高级品种及结果树苗随原种子合作社解锁，保留原八折规则。
2. 背包 → 装备种子：新增种子使用九格栏中的第六格；原胡萝卜、土豆、工具与鱼竿位置不变，种子选择随存档保存。
3. 农场菜单 → 建造 / 改造领地 → 摆件 → 加工设备：选设备、看材料、预览位置、确认建设。设备需留下合法站位与通路。
4. 靠近并点击实际设备，选择配方和批数，确认投入。完成后在原设备收取；每台同时保留一笔订单，多批按总时长串行加工。
5. 植被 → 生产果园：栽种购买的树苗。果树不占生产田、不要求每天浇水；成熟后仅在结果季补果。移动保留树龄，回收为树苗后重新成长。
6. 住宅厨房 → 料理与图鉴：家常、烘焙、茶饮分类，每页最多六道。食品可在背包食用或在商店按数量出售。
7. 住宅家具制作：用毛布制作河湾毛织地毯，用棉布制作棉布软垫椅；继续使用原装修、回收和收纳系统。

## 实际新增作物

每天浇水才增加一个生长日；雨水、原灌溉设施仍生效。非适种季暂停生长，保留植株、田地 ID 与已有成长天数。以下均为独立种子、收获物、32×32 物品图标和 32×40 四阶段生长图。

'''
text+=table(['ID / 名称','季节','生长日','种子价','收获数','单个售价','解锁','实际用途'],[[f"`{id}` {c['name']}",seasons(c['seasons']),c['growth_days'],c['seed_price'],c['harvest_quantity'],c['sell_price'],'基础' if c['unlock']=='basic' else '种子合作社','、'.join(({**d['processing'],**d['recipes']})[r]['name'] for r in c['uses'])] for id,c in d['crops'].items()])
text+='原胡萝卜 2 日 / 土豆 3 日 / 小麦 2 日，数量、价格和原季节规则保持；原春铃花玩法保留。新增农作物和花卉均可赠给林芽，走原每日赠礼、近期重复和生日规则。\n\n'
text+='## 果园\n\n'
text+=table(['树种','成长日','结果季','采果周期 / 数量','树苗原价 / 合作社价'],[[r['name'],r['growth_days'],seasons(r['seasons']),f"{r['regrow_days']}日 / {r['yield']}份",f"{r['sapling_price']} / {int(r['sapling_price']*.8)}"] for r in d['orchard'].values()])
text+='果实满包留在树上；一次采果后清空成熟槽并设置下次结果日。重复日信号、移动、反复进出和读档不会加倍产果；有果实时须先采收才能回收树苗。\n\n'
text+='## 实体设备\n\n'
text+=table(['设备 ID / 名称','建设材料','金币','配方数'],[[f"`{id}` {r['name']}",words(r['required']),r['coins'],sum(p['processing_station_id']==id for p in d['processing'].values())] for id,r in d['stations'].items()])
text+='原有免费观赏果树仍是摆件；结果树明确位于“生产果园”分组，须使用购买的树苗。\n\n这些设备由玩家放置在农场或已解锁的合法地表领地，具有独立精灵、真实碰撞、自动靠近交互和输出槽。每台设备有稳定对象 ID。施工预览不扣资源；正在加工或存有成品时不能拆除，移动保留订单。空设备可拆成一件不可出售的整机，重新放置消耗整机，不重复建设收费。\n\n旧厨房已建的四类设备各保留一次免费实体安装权益；旧加工订单继续保留在厨房的“领取成品”，按原日期完成，不迁移成重复奖励。\n\n'
text+='## 全部新加工配方\n\n配方按游戏分钟计时，现实 1 秒 = 游戏 2 分钟。正常菜单暂停仍遵循原规则；切换地图、睡眠、小睡和读档均使用同一游戏时钟。启动时整笔扣料，完成后留在输出槽。取消确认不扣料；已开始的订单继续完成，不提供中途返还材料。\n\n'
text+=table(['配方 ID','设备','原料','产出','分钟 / 批','成品单价'],[[f"`{id}`",d['stations'][r['processing_station_id']]['name'],words(r['input_items']),names[r['output_item_id']]+' ×'+str(r['output_quantity']),r['processing_duration'],prices[r['output_item_id']]] for id,r in d['processing'].items()])
text+='## 新增料理\n\n厨房已有五道料理保持原配方与解锁。新增料理共享原消费事务和单一增益槽：已有增益不叠加、不覆盖、不续时；满体力不消耗食品。\n\n'
buffs={'':'无额外增益','speed':'移动 +15%，120秒','thrift':'体力费75%，90秒','mining':'采矿伤害 +1，90秒','fishing':'钓鱼辅助 +0.03，120秒'}
text+=table(['ID / 料理','原料','恢复体力','增益','售价'],[[f"`{id}` {r['name']}",words(r['required']),d['items'][id]['energy'],buffs[d['items'][id]['buff']],prices[id]] for id,r in d['recipes'].items()])
text+='新食品与加工品可作为阿禾的礼物，继续使用同一每日额度。湖岸原鱼汤配方及草鱼、鲈鱼、金鳞鱼、星辉鱼料理用途保留；永恒星鲤未加入加工消耗。小京婚礼的固定五道旧料理目标不会随新菜谱扩张。\n\n'
text+='''## 完整生产链与经济

自动化使用实际农田生效事务和实际动物/钓鱼系统验证三条循环：

- 两份实收小麦 → 磨坊 90 分钟 → 两份面粉 → 一份麦香面包 → 食用 / 出售。
- 三份实收玉米 → 磨坊 135 分钟 → 48 份干草饲料 → 喂养真实鸡和牛 → 领取鸡蛋、牛奶 → 配合自产面粉制作蛋糕。
- 湖岸实际抛竿和追鱼 → 领取两条同种普通鱼 → 熏制炉 180 分钟 → 烟熏湖鲜 → 原商店出售。

新增处理品通常为投入原料出售价值的约 122%，料理约 112%；原面粉、奶酪、烟熏鱼和鱼干继续原售价。既有料理价格也不改写。玉米饲料一份产16份：直接出售价值16金，小于原玉米58金；替代购买饲料的价值64金，使自制饲料有用途而不构成买原料转卖套利。

所有新种子需适种日、浇水和收获；果树需成长与季节；设备有真实建设成本及单槽时间约束。新配方图无原料回流循环，不产钻石，不复制稀有鱼。没有增加现成加工原料的金币购入渠道，原钻石交易规则保留。

数据校验检查重复 ID、未知原料/设备、正整数数量、可获得来源、图标、依赖环和产出价值。完整逐配方成本与时间见 [economy.json](harvest-workshop/economy.json)。同时模拟112天单地块连续种植，计入种子成本、适种日、浇水动作和跨季停长；结果不计人工、折扣和期末未收获作物变现。设备吞吐量为理想24小时上界，实际收取与睡眠间隔会降低产量。长期玩家经济仍需游玩反馈。

## 存档与原系统保护

存档从 v27 迁移到 v28，新增 `workshop`。原作物仍使用 `plots`，装备种子、设备加工状态、订单唯一编号、开始/完成分钟、领取记录、果树树龄和结果槽持久化；投入材料已在同一库存事务扣除，订单保留配方 ID 和批数。设备位置复用 `territory.objects`，不另建互相冲突的摆放系统。

旧存档只补空工坊状态，不重置田地、经营、背包、金币、矿洞、操作模式、外观、小京好感与婚姻。新种子/配方解锁依赖原合作社及原料理前置，直接复用已保存的进度。

小京旧三作试炼原先遍历所有作物目录；目录扩展后已将其固定为原胡萝卜、土豆、小麦，防止无意扩大任务。520次成功播种、1314钻石婚礼、四级房屋及既有成就门槛不变，钓鱼无保底与永恒星鲤降低十倍配置保留。

## 美术与窗口证据

原生32像素体系，使用当前晴光河湾89色色阶、左上高光和暖木/奶油/自然绿。图标、作物四阶段、十类设备和织物家具由本轮像素绘制程序生成；果树树冠基于工程内已接入的用户素材衍生，原始 `need/` 不变。没有下载或复制新的商业游戏素材。

- [风格基线](HARVEST-STYLE.md)与[270张图像的资源清单、来源和校验值](harvest-workshop/assets.json)
- [农场前后对比](harvest-workshop/comparison-farm.png)、[厨房前后对比](harvest-workshop/comparison-kitchen.png)、[背包前后对比](harvest-workshop/comparison-inventory.png)
- [原素材与样板同屏](harvest-workshop/style-sample.png)
- [农场中的新旧作物与十类设备](harvest-workshop/farm-workshop.png)
- [农场全景](harvest-workshop/farm-panorama.png)
- [果园](harvest-workshop/orchard-grown.png)
- [果酱加工界面](harvest-workshop/jam-progress.png)
- [厨房料理界面](harvest-workshop/kitchen-recipes.png)
- [背包图标图集](../assets/harvest/item_atlas.png)及[图集索引](../assets/harvest/item_atlas.json)
- [16:9](harvest-workshop/workshop-1280x720.png)、[19.5:9](harvest-workshop/workshop-1560x720.png)、[20:9](harvest-workshop/workshop-1600x720.png)、[4:3平板](harvest-workshop/workshop-1280x960.png)
- [480DPI模拟确认](harvest-workshop/dpi-480-confirm.png)、[480DPI加工](harvest-workshop/dpi-480-processing.png)、[480DPI厨房](harvest-workshop/dpi-480-kitchen.png)

以上为实际 Godot X11 窗口，不是 UI 效果图。截图使用隔离验收存档布置，正式游玩仍需正常购买种子与建设设备。模拟480DPI、1920×1080物理屏和1280×720画布时，48dp转换为96逻辑像素，并检查横屏安全区。实际原生 ScreenTouch 验证确认前不扣料、双指不重复提交、关闭恢复地图、新种子点击移动播种、厨房滚动按钮可点击。

没有 Android 真机，真实手感、双指操作、温度与长时间功耗未验收；Windows成品已用Wine实跑窗口、中文路径与存档重启，不能视为Windows真机验收。

## 未开放内容

'''
text+=table(['预留配方','原因'],[[r['recipe_id'],r['reason']] for r in d['future']])
text+='''本轮没有新增这些动物、蜂箱或蘑菇采集系统，没有扩展第三章或新地图。

## 修改范围与阶段提交

- A `b8ff6ea`：作物/种子/物品目录、季节生长、图标与存档基础。
- B `c0146e4`：实体设备、分钟制生产、原子投入/领取、建造与搬迁。
- C `ca6810e`：全部加工路线、果园、布料家具和实际窗口。
- D `369c99b`：厨房27道新菜、分页、赠礼、三条生产循环。
- E：完整回归、兼容保护、经济校验、跨进程存档、窗口触控与打包；最终编号见交付消息及 Git 历史。

完整修改路径见 [changed-files.txt](harvest-workshop/changed-files.txt)。

主要数据：`resources/harvest/harvest.json`；新脚本：`scripts/farming/harvest_catalog.gd`、`scripts/kitchen/workshop_state.gd`、`workshop_panel.gd`。原农田、Catalog、种子经济、厨房、背包/HUD、住宅家具和领地接口做局部接入；存档 v28 迁移在原 save_schema/save_store 中。没有重建项目或另建一套库存/时钟/寻路。

新增资产在 `assets/harvest/`，两款家具在 `assets/housing/`。生成器为 `tools/generate_harvest_data.py`、`generate_harvest_assets.py`；校验与测试入口为 `tools/validate_harvest.py`、`test_harvest.py`、`check_project.py` 和 `capture_harvest.py`。测试与构建均使用隔离用户目录。

最终自动化、窗口、存档和安装包结果见 [results.json](harvest-workshop/results.json)。完整配方、种植配置以上述实际数据表为准。
'''
(ROOT/'docs/HARVEST-WORKSHOP.md').write_text(text)
print('Generated docs/HARVEST-WORKSHOP.md')
