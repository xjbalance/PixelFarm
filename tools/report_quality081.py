"""Generate delivery notes from the measured 0.8.1 audit and actual content data."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/quality081'
baseline=json.loads((OUT/'baseline-tests.json').read_text())
economy=json.loads((OUT/'economy.json').read_text())
assets=json.loads((OUT/'assets.json').read_text())
text=f'''# 《像素世界》0.8.1《丰收匠心》开发报告

本轮在已完成的0.8.0农业系统上做质量优化。基线为 `14287b5`：33种田间作物（含花卉）、4种果树、10类实体设备、49条分钟加工配方、32道厨房料理，鸡/牛/羊有实际生产。鸭、山羊、猪、蜂箱与可食用蘑菇来源仍未开放。本轮没有新增地图、章节或动物玩法。

开发分支 `development/0.8.1`；恢复分支 `backup/0.8.0-before-0.8.1`。`need/` 和用户真实存档保留。独立0.8.0工作副本重新执行了 {baseline['processes']} 个进程、{baseline['assertions']} 项断言，失败0。

## 美术与表现

规范见[《像素世界美术风格基线》](ART-STYLE-BASELINE.md)。采用当前晴光河湾89色阶、32像素网格、左上光源和统一材质层次。原三作物原先为16像素绘图最近邻两倍，新版将其与新作物一起整理为32×40原生帧；图集行号、实际占地和成长时间不变。

- 新旧作物分别呈现根菜、叶菜、矮丛、藤蔓、谷物和花卉结构，成熟果实挂在植株上，原三作物有独立种子/收获图标。
- 袋装、烘焙、玻璃/陶罐、油品、奶制品、布料和原动物产品使用同一色阶、光照与细节密度。
- 保留已有合格果树树冠、建筑、家具、角色和地面；树木仍使用原季节与结果机制。
- 十类设备共用一张工作图集：4帧、4fps；顶部仅增加8像素烟气空间，脚底和碰撞不变。菜单、后台、隐藏和完成时暂停/停止。
- 成熟地块新增小型静态暖金标识；湿土和蓝色水分标记保留，不增加触控节点。

本轮校验 {assets['resources']} 张农业相关原生纹理，包括旧物品、作物阶段、四季树木、工作图集与已有织物家具。[逐资源规格与SHA256](quality081/assets.json)。图集夹具与实际世界验收分别记录，不能用单独PNG代替场景效果。

## 实际窗口截图

- [作物前后对比](quality081/comparison-crops.png)：胡萝卜/草莓、小麦/玉米、土豆/卷心菜的幼苗、中期与成熟同田。
- [设备前后对比](quality081/comparison-devices.png)：磨坊、果酱锅、纺织机和熏炉相邻摆放。
- [背包前后对比](quality081/comparison-inventory.png)、[动物产品前后对比](quality081/comparison-animal-products.png)。对照夹具只隐藏无关背包条目，复用实际图标、数量和控件。
- [旧新料理同屏](quality081/after-kitchen.png)、[厨房改版对比](quality081/comparison-kitchen.png)。
- [设备工作帧A](quality081/working-a.png)、[工作帧B](quality081/working-b.png)。
- [具体缺料与预计时间](quality081/ui-mill-ready.png)、[实际投入工单](quality081/ui-processing.png)、[完工收取](quality081/ui-output.png)。
- [种子季节图鉴](quality081/ui-seed-catalogue.png)、[跨季备种确认](quality081/ui-seed-warning.png)。
- [16:9](quality081/ui-workshop-1280x720.png)、[19.5:9](quality081/ui-workshop-1560x720.png)、[20:9](quality081/ui-workshop-1600x720.png)、[4:3横屏平板](quality081/ui-workshop-1280x960.png)、[480DPI与模拟安全区](quality081/ui-dpi480.png)。

以上来自实际Godot X11窗口和软件OpenGL，不是网页模型或单纯素材拼图。截图使用隔离验收进度；设备材料及初始资本是测试夹具，正常游玩仍需购买与建设。

## 生产和存档安全

审计发现旧工单按当前配方推导投入/产出，配方调整会改变旧在制品的解释。存档v28迁移为v29，工坊区版本为2，每笔只增加 `inputs` 和 `outputs` 数量快照，其他经营分区保留原字段。旧49条配方固化在 `production_080.json`，迁移不补扣、不清队列、不补发奖励。

真实旧引擎输出的合法v28测试存档包含已婚、四级住宅、矿洞、待领取和未完成工单。验证非生产字段逐项保留、旧原料数量、原成品、坏字段拒绝和幂等迁移。不同存档复用物件ID时，设备信号与实际地图父节点也正确恢复。

原游戏时钟保持现实1秒=2游戏分钟，06:00–24:00，20:00可睡、午夜昏睡。小睡、正式睡眠、跨天、离场、后台、重复点击、信号重入、满包、搬迁与读档都通过专项检查。动画不推进生产；后台不按现实离线时间加产量。

详细说明：[存档兼容](quality081/save-compatibility.md)。旧作物、生长天数、果树经济、动物产量、钓鱼概率和1314钻石规则等36份非目标资源定义的校验值保持原样：[保护清单](quality081/protected-rules.json)。

## UI、输入和引导

加工列表显示图标、可制作/缺料/解锁状态；选中详情列出原料实际持有与需要，当前工单则显示冻结的已投入数量。预计时间使用同一绝对游戏分钟，夜间完成显示清晨可取。加工中可以浏览其他配方，当前工单保持不变。

配方列表节点保留，库存刷新不丢滚动位置；进度按时钟事件更新，暂停90帧没有额外写入。确认前不扣料，完成后突出收取，满包留在设备中。厨房补齐材料与具体失败说明，满体力食用按钮禁用。

种子页增加当季/花卉/四季图鉴、成长日、每株产量、价格和解锁信息。非当季库存仍可卖；原胡萝卜/土豆的提前买种规则保留，新增明确备种确认和旧确认失效保护。合作社八折规则保持。当前温室没有普通种植功能，所以不误标“适合温室”。

共享滚动与按钮使用同一DPI换算阈值，内外滚动容器只由最深的可滚动区域处理本次手势，避免滚动触发点击。沿用完整九格、点击移动、自动寻路、自由观察和备用摇杆。

五条加工帮助复用原 `tutorial.seen`，通过简短提示与首次内联说明呈现，菜单可随时查阅。旧档对新帮助默认已读，其他旧教学标记保留；不新增奖励，不连续弹强制教程。

## 生产链与平衡

实际通过：小麦→面粉→面包；草莓→果酱→草莓蛋糕；玉米→饲料→鸡蛋→蛋黄酱；牛奶→黄油→奶油炖菜；棉花→棉布→软垫椅。农业原料由实际购买种子、播种、浇水、收获、喂养、产物收取取得，没有直接塞入高级成品。[链路结果](quality081/chains.json)。

审计 {economy['recipe_count']} 条现有农业配方，检查物品ID、正常来源、可达性、依赖循环、设备成本、原料机会成本、时长和操作。只调整奶酪售价、两条鲫鱼投入、无增益炖菜恢复与奶酪面包的关联定价。[全部配方前后数据和理由](quality081/economy.md)、[机器可读模拟与成本](quality081/economy.json)。

旧库存采用当前售价/恢复效果，读档不补差额或体力；旧工单仍按原投入与成品快照执行。基础作物收益、果树、动物、鱼苗、矿物、婚礼与钻石获取不变。部分原湖岸食品/饲料的出售毛利为负，但保留食用、增益、自给和减少往返的用途，不作为转卖获利路线。

## 验证与交付

最终结果：[results.json](quality081/results.json)。包括全部原回归、专项测试、窗口矩阵、原生ScreenTouch、真实v28迁移、独立进程读档、经济图校验、源码空缓存导入和安装包资源验证。

额外渲染夹具同屏120株作物、40台设备动画、18只动物精灵和96枚图标，不写入玩家数据；实际桌面壁钟帧耗时与环境见[performance.json](quality081/performance.json)，[压力窗口](quality081/render-stress.png)。该夹具使用固定1/60秒逻辑步长，记录的是渲染信号间实际壁钟时间，不是Android硬件性能结论。

保留原Android包名 `org.pixelfarm.windbud`、更新签名和存档位置，versionCode31。目标包为 `builds/PixelWorld-0.8.1-debug.apk`、`PixelWorld-0.8.1-Windows-x64.zip` 和 `PixelWorld-0.8.1-source.zip`。Windows成品使用Wine验证时单独标明；没有Android或Windows真机验收。

## 提交记录与尚未完成

- A `e4246a8`：风格基线、真实基线测试和样板同屏。
- B `68dbe8a`：农业素材统一与设备工作动画。
- C `a5f9abf`：工单快照、旧档迁移、支付和跨存档恢复。
- D `b3879fe`：配方/厨房/种子UI、触控和帮助。
- E：有限平衡、完整回归、窗口与打包；最终编号见交付消息及Git历史。

本轮没有新增鸭、山羊、猪、蜂箱或蘑菇采集；其预留配方仍明确未开放。Android真机触控、温度、长时功耗和Windows原生硬件兼容未验收。经济报告提供静态与游戏日期模型，长期玩家经济仍需游玩反馈。

主要代码：`workshop_state.gd`、`workshop_panel.gd`、`workshop_visual.gd`、`production_info.gd`、厨房/背包/触控/教程及原存档接口的局部修改。数据与生成器保持统一ID，没有改造全局相机、寻路或主线。[完整修改路径](quality081/changed-files.txt)。
'''
(ROOT/'docs/QUALITY081-REPORT.md').write_text(text)
print('Generated docs/QUALITY081-REPORT.md')
