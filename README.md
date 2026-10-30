# 像素世界 · 0.8.2《活力牧场》

最新：[0.8.2开发报告、牧场动画、四倍农场与旧档兼容](docs/RANCH082-REPORT.md)。鸡鸭共舍、鸡窝收蛋与鸭蛋腌制已开放；鸡鸭牛羊使用真实四向行走、啄地/吃草、休息与归舍。主农场96×64，旧48×32坐标保留，自然障碍清理后永久开垦。独立牧场通过原畜舍旁围栏门进入，原容量和鸡/牛/羊产量保持。存档v29迁移v30；原Android包名、更新签名和存档位置保留。

操作：主农场选择锄头后点击合法土地即可开垦，菜单进入农场DIY。建好鸡鸭舍、牛棚或羊圈后，从舍旁围栏门进入后方牧场；点击动物自动走近照料，点击鸡窝统一收鸡蛋和鸭蛋。晴天08:00–14:00可开栏，18:00、雨雪和冬季回暖舍。旧场景自然物重叠时，手动选择镐子先清石堆，再选择斧头清灌木，原剧情设施点击保留。

此前：[丰收工坊完整说明、配方与截图](docs/HARVEST-WORKSHOP.md)。新增27种季节作物、3种花卉、4种结果树、10类实体设备、49条加工配方、27道料理及布料家具。设备在农场建造模式摆放，料理仍在住宅厨房制作。存档 **v28**，旧v27及更早进度安全迁移；九格工具栏、全场DIY、婚姻和原钓鱼概率保留。

当前验收：217个回归进程全部通过；自动化与实际窗口断言、包体校验和限制见[机器汇总](docs/ranch082/results.json)。Android code32，Windows成品通过Wine独立运行和存档重启；Android及Windows原生真机尚未验收。复现入口：`tools/check_project.py`、`tools/capture_ranch082.py`、`tools/audit_ranch082_assets.py`。

0.8.1历史验收：203个进程、11,085项自动断言和530项实际窗口检查通过。Android code31；Windows使用Wine验证，Android及Windows原生真机尚未验收。复现入口：`tools/check_project.py`、`tools/capture_quality081.py`、`tools/analyze_quality081.py`。

此前：[农场全场DIY](docs/REPORT-FARM-DIY.md)。真实住宅、温室、畜舍、商店、鱼栏、原设施、42个资源节点与生产田都能移动或收纳后放回；48×32主农场可重新铺路、改水形并在合法干地开垦。原等级、库存、动物和剧情进度保留。存档 **v27**，兼容v1–v26。[9736项检查与窗口证据](docs/TEST-FARM-DIY.json)

此前的[方案C世界素材整合](docs/REPORT-NEED-ASSETS.md)已接入97款世界素材，保留作本轮之前的对照记录。原来固定的大型功能建筑现已开放搬迁。[还需补充的素材](docs/NEED-ASSET-GAPS.md)

0.8.0基础功能包括[领地编辑第一阶段](docs/REPORT-TERRITORY-080.md)，并保留[移动精修](docs/TOUCH-POLISH-01.md)、[农活精修](docs/FARMING-POLISH-02.md)、[饮食恢复调整](docs/FOOD-RECOVERY.md)、[背包快捷栏](docs/INVENTORY-POLISH-03.md)、[UI04视觉统一](docs/REPORT-UI04.md)、[UI05沉浸式视野](docs/REPORT-UI05.md)、[住宅05四阶段住宅与小睡](docs/REPORT-HOME05.md)、[原布局恢复与资源丰富森林](docs/RESTORED-LAYOUT-RESOURCES.md)、[温馨田园住宅与家具自由摆放](docs/HOME-ARRANGE.md)、[按数量出售](docs/SALE-QUANTITY.md)、[农场视觉样板06](docs/FARM-VISUAL-06.md)、[羊皮纸冒险图纸](docs/PARCHMENT-MAP.md)、[UI07全界面收口](docs/REPORT-UI07.md)及[方案C角色选择](docs/SCHEME-C-SELECTION.md)。

**0.8.2《活力牧场》**，Godot 4.3 Standard。主农场支持全场DIY，四处按章节开放的地表领地保留既有权限；公共区域和地下保留原规则。

保留原种田/采集的消耗与产出、三张原地图、第一章与第二章、百层深渊、小京520播种/三属性/12任务/7记忆/5试炼/1314钻石婚礼及婚后520日。原应用包名、证书与存档路径保留。

在主农场打开菜单 →「建造 / 改造领地」→「原物」，选择原建筑、设施、树石或农田后点地图预览并确认；“已收纳”分组可放回。地表页支持挖水和填水；新生产田用普通锄头开垦。观赏摆件不产生资源，共享箱子使用原住宅容量。区域路线与权限见[设计说明](docs/TERRITORY-080-DESIGN.md)。

农场全场DIY历史阶段回归 **9736项、188个进程通过**，窗口专项 **359项通过**。该阶段调试APK为code25，Windows64 ZIP已生成并经Wine验证；Android与Windows原生真机未验收。[该阶段机器记录](docs/TEST-FARM-DIY.json)；[素材整合阶段](docs/TEST-NEED-ASSETS.json)和[初版0.8.0](docs/TEST-TERRITORY-080.json)的历史记录保留供比较。

![真实编辑器预览原住宅搬迁](docs/farm-diy/editor/farm-diy-editor-home_preview.png)

尚未结婚时，婚礼还需住宅完工至当前最高四级「星光庄园」，并亲手钓获、领取过传说鱼「永恒星鲤」。只检查永久钓获记录，不交付或消耗鱼；已婚旧档保留婚姻。详见[婚礼准备](docs/MARRIAGE-REQUIREMENTS.md)。

右上角地图图标旁已有[一键回家](docs/HOME-TELEPORT.md)，免费传送至屋内安全位置；该功能历史验证109项状态/109项窗口与相关265项状态/173项窗口回归通过。

当前采用方案C“温暖田园 × 星辉旅人”：开局可选男女主角，小京自动使用对应形象，世界精灵、头像、菜单和剧情显示共用外观解析。方案C阶段完整整合验收：**6,087项自动化、3,425项桌面窗口、159个计划进程全部通过**，见[方案C机器记录](docs/TEST-SCHEME-C.json)；原签名Android调试APK已构建（versionCode 20），没有Android真机验收。上一轮[UI07风格收口](docs/REPORT-UI07.md)已完成，`94f18cd`记录5,062项自动化、3,335项桌面窗口及146个进程通过，属于v24/code18历史基线。

[方案C完整报告](docs/REPORT-SCHEME-C.md) · [角色选择与菜单](docs/SCHEME-C-SELECTION.md) · [角色资源与来源](docs/SCHEME-C-ASSETS.md) · [UI07收口报告](docs/REPORT-UI07.md) · [当前图纸报告](docs/PARCHMENT-MAP.md) · [农场视觉样板](docs/FARM-VISUAL-06.md) · [数量出售](docs/SALE-QUANTITY.md) · [住宅改造与摆放报告](docs/HOME-ARRANGE.md) · [布局与森林报告](docs/RESTORED-LAYOUT-RESOURCES.md) · [住宅05报告与四级截图](docs/REPORT-HOME05.md) · [UI05报告与前后截图](docs/REPORT-UI05.md) · [布局规范](docs/UI05-LAYOUT.md) · [UI04报告](docs/REPORT-UI04.md) · [初版开发报告](docs/REPORT-0.7.1.md) · [0.7.0内容报告](docs/REPORT-0.7.0.md) · [操作与玩法](docs/GUIDE-0.7.0.md) · [测试记录](docs/VALIDATION.md) · [UI05验收边界](docs/KNOWN-ISSUES-UI05.md)

首次无存档时先选择角色：男主对应女小京，女主对应男小京；可以反复预选，最后确认才创建新档。已有存档直接读取，原经营、任务和婚姻进度保留。菜单“新游戏 · 重新开始”先显示覆盖确认；确认角色时先备份旧档，取消保留当前进度。首次选择返回不保存默认性别，后台保留预选。

游玩中可打开菜单 →「切换人物形象」，随时更换主角并联动小京，无需重新开始。预选可取消，确认后保存，原农场、钱物、任务和婚姻进度保留；详见[游戏内切换说明](docs/CHARACTER-SWITCH.md)。

![方案C角色选择实际窗口](docs/scheme-c-selection/female.png)

选择页采用用户原参考的纸面立绘卡，世界角色使用透明四方向像素图；仪式衣装为配色派生，资源边界见[来源说明](docs/SCHEME-C-ASSETS.md)。角色选择页支持触屏、键鼠和手柄事件；实体手柄及Android设备仍待验收。

UI07已经把原手记中的旧地图替换为同一套可交互羊皮纸图纸，常用、剧情与经营面板共享新纸卡和标题；建筑与人物材质也完成上一阶段统一。完整九格HUD保持原尺寸。

![农场视觉样板06历史画面](docs/farm06/layout_1280x720.png)

当前保留完整顶栏与底部九格工具栏。新农场样板统一草块、路缘、池岸和四季树冠，仅替换农场视觉；地形、农田、资源位置和碰撞保持原样。农场42、村庄外围16、迷雾森林70个可再生树石点保留；森林从农场西北的“西北林径”进入。村庄、森林和矿洞本轮未做同级美术重绘。[同镜头前后对比](docs/farm06/comparison.png) · [四季样板](docs/farm06/four-seasons.png)。

按 **M**、点击HUD的小折叠地图图标，或打开手记“河谷地图”查看同一套原创羊皮纸图纸；查看世界总览和已发现区域，拖动/双指或滚轮缩放，定位当前人物。图纸读取真实桥梁、住宅、探索状态，保留未知区域遮蔽，只供查看，不传送、不自动导航。

![羊皮纸世界总览实际窗口](docs/parchment-map/world_1280x720.png)

![资源丰富的迷雾森林](docs/classic-resources/mist_forest_1280x720.png)

住宅已统一为暖木、奶油墙面与苔绿软装，床、沙发、厨房和其他家具可自行移动，四级成长与原完整九格大小保留。

![四阶段温馨田园住宅实际窗口](docs/home-arrange/four-levels.png)

在家打开菜单选择“布置房间”，或点击收纳柜→“布置与移动”→“直接在房间里布置”；点选/拖动家具预览，点击“确认摆放”才提交。家具外观、碰撞与功能位置同步更新，出口和生活通路受保护。[摆放演示](docs/home-arrange/arrange-demo.gif) · [室内前后对照](docs/home-arrange/compare-interior.png)。

住宅仍通过周砚进行两日改建；所有等级保留室内厨房。沙发小睡一小时恢复最大体力50%，午夜仍优先正常昏睡。[原小睡演示](docs/home05/sofa-demo.gif)。

UI05紧凑版已恢复为上方的完整布局；[旧界面仅作历史对照](docs/ui05/compare-hud.png)。

空闲时拖动画面自由观察，松手保留视野；点击“回中”或开始移动恢复跟随。底部九格工具栏常驻，任务默认展开且可折叠。[查看前后对照](docs/ui05/compare-hud.png)。

## 运行与下载

Godot **4.3 Standard** 导入`project.godot`，完成素材导入后按F5；不需要.NET或插件。Python只用于开发工具，游戏运行不依赖Python。Windows/macOS可导入源码，但本轮没有这些平台的实体机测试。

```bash
./.tools/Godot_v4.3-stable_linux.x86_64 --path .
```

- [Windows 64位电脑版 ZIP](builds/PixelWorld-0.8.0-Windows-x64.zip) · [Windows说明](docs/WINDOWS.md)
- [Android调试APK](builds/PixelWorld-0.8.0-debug.apk) · [APK校验和](builds/PixelWorld-0.8.0-debug.apk.sha256)
- [完整源码包](builds/PixelWorld-0.8.0-source.zip) · [源码校验和](builds/PixelWorld-0.8.0-source.sha256)

源码包不含本机引擎、SDK、签名密钥或玩家存档。Android构建必须使用原签名，见[ANDROID.md](docs/ANDROID.md)。本次没有在手机安装或执行覆盖更新。

## 操作

| 行为 | 桌面 | Android |
|---|---|---|
| 移动 | WASD/方向键/鼠标点击 | 默认点击自动寻路，设置可切换备用摇杆 |
| 交互 | 点击对象/E/空格 | 点对象，沿合法位置靠近后执行一次 |
| 工具 | 1–9 / Q | 下方工具栏；第9格鱼竿 |
| 背包/委托 | B/J | 右上对应按钮 |
| 地图图纸 | M展开/收起，拖动/滚轮缩放 | 小折叠地图图标，拖动/双指缩放 |
| 手记 | HUD或菜单中的手记按钮 | 同左，原手记功能保留 |
| 保存/读取/菜单 | F5/F9/Esc | 菜单与系统返回 |
| 钓鱼 | 按住追鱼按钮或空格，松开调整 | 长按/松开追鱼按钮 |
| 领地改造 | 菜单→建造 / 改造领地，预览后确认，Esc退出 | 单指点选或拖刷，确认/取消；多指不结算 |
| 家内布置 | 家内菜单→布置房间，点选/拖动、确认 | 同样点选/拖动家具预览，确认才提交 |
| 角色选择 | 左右/鼠标预选，Enter确认，Esc返回 | 点男女主角卡，确认后开始；返回保留原进度 |

浇水时脚底与朝向短暂固定，人物图像不再水平累加偏移；地图点击使用按下时的世界位置，避免跟随相机后释放到另一格。按下时同时保留NPC/动物身份，释放后不会因它们走动误点地面。目标环区分地面、交互与不可达；UI、多指、混合鼠标触屏、切图、模式切换与后台均有取消/防误触处理。手记“村里的邻居”与地图显示实际活动位置。

## 每天的安排

现实1秒＝游戏2分钟，一天06:00–24:00，正常约9分钟。20:00前不能主动睡觉，20:00后确认休息；午夜疲劳昏睡恢复六成，每天只结算一次。菜单、对话及后台暂停正常时间。

菜单“操作与生活指南”随时查看八类说明；新玩家轻提示只展示一次，旧存档默认已读。商店支持“按数量出售”：选择1至实际持有量，也可选1/5/10/全部；确认页展示单价、数量、总价与剩余，最终确认才扣物。原“出售全部”保留，购买数量独立，取消不改资源。

体力不足时可用：屋东休息椅每日3次，每次花20游戏分钟恢复15；现有食物只要持有且体力未满即可继续吃，每次消耗1份，胡萝卜/土豆/小麦恢复8/12/4；鱼干/鱼汤恢复18/30，厨房料理按原值恢复，均无每日食用次数限制。已有料理增益不叠加、不覆盖或延长。建成茶座后每日热茶40。满体力不消耗恢复物品或次数，椅子不触发作物/矿石/鱼群跨天。

每季28日、每年112日。雨自动浇露天田，雪不算雨；冬季胡萝卜/土豆休眠保留，小麦全年，春天继续原进度。手记“四季历”可看七日预报；每季15日晴或薄云的20点后可观满月，流星夜有固定可预报窗口。

## 新内容从哪里开始

- 农场东湖：原四岸鱼栏，水样台管理全湖生态；装备鱼竿点水开始实操钓鱼。村河、地下水脉与两处隐图水域也有钓点。
- 农场南侧：鸡舍、牛棚、羊圈建造牌。动物真实活动，雨雪/冬季回到可见暖舍，晴日可放牧。
- 家内厨房：灶台提供原有料理功能；屋外四加工设备保留跨日加工队列和原有增益，屋西野莓灌木提供果酱原料。
- 周砚建造服务：温馨小屋→舒适农舍→河湾大屋→星光庄园，两日施工期间可照常回家；家内收纳柜提供储物与家具布置，庭院布置牌保留原专用区域。春庆的春铃花种在实体花坛栽培，三日后可收花。
- NPC对话标题“近况与礼物”，小京面板“四季近况”：生日/喜恶/个人任务与共同活动，原剧情仍可继续。
- 每季24日：春播比赛、夏湖畔灯会、秋丰收展篮、冬集市送暖锅；原第一章风灯庆典独立保留。
- 农场西北林门：迷雾森林；森林档案和生态修复后去湖东旧阶开放封闭排水廊；两区档案与高级矿洞工艺后去村东岸古神庙。
- 河湾村共建发展牌：两级码头与两级社区建设、真实新产贸易、三处巡灯和每周原NPC共餐。三个发展方向都能做，不永久锁路线。

![湖底封闭排水廊](docs/screenshot-070-ruins.png)

## 验证与维护

```bash
python3 tools/check_project.py
python3 tools/check_windows.py
python3 tools/check_interrupt_071.py
python3 tools/simulate_070.py
python3 tools/build_android.py
python3 tools/build_windows.py
python3 tools/verify_apk_runtime.py
python3 tools/verify_territory_apk.py
python3 tools/package_source.py
python3 tools/verify_source_package.py
```

完整入口使用临时用户目录，测试不操作真实玩家存档。窗口工具使用本机Xvfb/Mesa，不能替代安卓真机。10,000组经营模型及240次新增地图切换压力测试不代表真人长线时长或手机功耗表现。

[经济模型](docs/ECONOMY-0.7.0.md) · [存档迁移](docs/SAVE-MIGRATION.md) · [架构](docs/ARCHITECTURE.md) · [素材溯源](docs/ASSET_PROVENANCE.md) · [变更记录](docs/CHANGELOG.md)

0.8.0在`development/0.8.0`独立开发，继承0.7.1提交`7c65c99`；`development/0.7.1`保持该提交，保留原基线及各阶段历史。[阶段A–E记录](docs/PROGRESS-0.7.0.md)为开发历史；0.7.0内容和0.7.1修复分别见各版报告。
