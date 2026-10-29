# 0.5.0架构增量

- `MineState`拥有矿物/工具/加工/机关/宝箱事务；`MiningSaveSchema`验证新状态。资源与地图定义在`resources/mining`。
- `CaveMap`按设计数据创建TileMapLayer与交互对象；`ore_node`仅负责碰撞与受击表现，`mine_point`复用原交互组。
- `WorldTravel`统一六图可见性、物理启停、相机和出生点，复用同一个玩家。导航仍采样真实碰撞，变更等待物理同步；静态障碍按变更缓存，NPC动态占位。
- `ChapterTwo`记录探索、机关和人物事实，连续八项一次性奖励使用原`Inventory.exchange`。`mine_panel`只提交阅读/确认，不能远程开采或跳过前置。
- schema7逐步迁移v1–v6；`Xiaojing`保留既有任务与婚姻，实体矿道/星灯共用旧试炼ID。旧路线盘只可完成迁移后在途的一轮。
- 矿图无每格脚本/粒子/阴影灯阵；共用单盏玩家灯，仅可见地图处理。手机性能尚未实测。

下方保留历史架构记录，版本号与范围以本段及README为准。

# 0.4.0架构补充

当前用户文档见[README](../README.md)，下方保留0.3.0历史架构说明。

- `Letters`：数据任务与调查事实，复用原`Story.stage`提交与`Inventory.exchange`；原交付委托不改。
- `Xiaojing`：独立三属性/任务/记忆/试炼/婚姻状态，农田成功提交直接计数，不订阅展示信号；钻石单独账户。
- `xiaojing_panel.gd`：原生触点/滚动/模态UI，故事读完才提交，婚礼确认才扣费。
- `VillagerNavigation`：NPC站点间的四向AStarGrid2D，采样当前真实碰撞；复用CharacterBody2D，不是玩家点击寻路模块。
- 当前schema6，逐步迁移v1–v5；同一用户目录、原包名和签名保留。
- `TouchInputManager`记录输入归属、UI过滤与相机逆变换；`TouchInteractionResolver`解析原目标。
- `WorldNavigation`缓存当前图静态碰撞并叠加动态NPC，32px AStarGrid2D基数网格；桥梁/资源变更后等待物理同步刷新。
- `AutoMoveController`维护一次意图状态机，输入仍由原Player移动/动画/碰撞执行；`TouchInteractionExecutor`在合法距离与视线内调用原交互一次。
- 模式由GameState统一变更，HUD释放摇杆、控制器取消待操作、输入管理器取消手势；存档仅保存枚举，运行路径不持久化。详见[触控说明](TOUCH-CONTROLS.md)。

---

# 模块与数据约定

主场景只协调可见地图、交互对象与 UI；游戏规则放在各自模块。没有第三方运行时插件。

| 模块 | 职责 | 主要通信 |
|---|---|---|
| `Events` Autoload | 用户提示、动作请求、交互、模态与农活事件 | 全局 Signals |
| `GameState` Autoload | 工具选择、体力、当前位置、模态状态、键盘绑定 | `changed`、`modal_changed` |
| `Catalog` Autoload | 注册 `CropDefinition` 数据资源、查询中文名 | 只读查询 |
| `Inventory` Autoload | 数量堆叠、金币、原子数量校验 | `changed` |
| `GameClock` Autoload | 时间流逝、换日、体力恢复 | `changed`、`day_advanced` |
| `farm.gd` | 坐标农田数据、农活校验、生长结算、作物绘制 | 监听换日；发出 `farm_action` |
| `FarmEconomy` | 校验整笔交易后提交金币与数量 | 库存变化通知 UI |
| `ResourceField` / `ResourceNode` | 稳定采集物 ID、耐久、掉落、再生与碰撞反馈 | 换日、`resource_hit` |
| `FarmProgress` Autoload | 设施定义、三份委托、好感与每日交谈 | `changed`、`upgrade_built`、`progress_committed` |
| `FarmSaveSchema` | 无副作用的版本迁移和完整数据校验 | 返回可恢复的数据副本 |
| `FarmSaveStore` | JSON 版本校验、写临时文件与备份、恢复状态 | 完成后刷新各系统 Signals |
| `player.gd` | CharacterBody2D 物理移动、四向动画、面对格子 | 接收 HUD 的 `movement` |
| NPC / 交互点 | 附近交互入口，不包含 UI 逻辑 | 对话或 `interaction_requested` |
| UI | HUD、背包/摊位、菜单、对话、独立触点控件 | 发送语义请求，不写农田规则 |

## 地图和碰撞

农场为 48 × 32 格、每格 32 像素。脚下/面前的农田操作范围为 10 × 6 格（x=17..26，y=16..21），比外围浅色土地略小。玩家相机 1.35 倍，小屋使用 1 倍固定边界视野。

图层/物理约定：地形 `TileMapLayer` 在 Z=-5，农田在 Z=-1，玩家和树木/建筑放在 Y-sort 的 Actors 下；世界碰撞层为 1，玩家层为 2，玩家只检测世界层。池塘的 TileSet 在挂到 TileSet 后再写碰撞多边形，兼容 Godot 4.3。

小屋为独立场景，切换时复用同一个玩家、重新设置出生点和相机；禁用隐藏地图的处理和地形层，避免隐藏地图的碰撞仍干扰室内。农田仍接收每日生长信号，所以在室内睡觉也会结算室外作物。

## 农田规则

每个已开垦格子的 key 是标准格式 `"x,y"`，value 是 `{"crop":"carrot", "days":1, "watered":true}`。字典无该 key 表示未翻土；crop 为空字符串表示已翻土但没种植。

操作先校验位置、状态、背包和体力，再修改数据。仅浇水的格子在换日时增加 days，并将 watered 清为 false。成熟由 `days >= growth_days` 决定。收获保留已开垦状态，去除作物；失败操作没有副作用。

新作物通过 `.tres` 声明 id、中文名称、价格、生长日数、图集行与阶段数。场景无须为每株作物创建 Node，每次仅在内容或选中格变化时重绘，适合小型移动端地图。

## 触摸与模态

摇杆拥有独立触点 index，拖动到控件外仍追踪同一手指；动作键和所有 UI 按钮分别跟踪各自的触点。关闭鼠标模拟，避免第二根手指替换第一根的事件。键盘向量和摇杆向量在玩家模块合并，速度限制为单位向量。

背包、对话、商店、菜单开启时设置统一模态状态，停止角色和时间，同时释放摇杆。遮罩阻止鼠标穿透，触摸按钮检查所属模态面板，防止触摸穿透。焦点丢失与 Android 暂停通知清理输入、暂停时钟并自动保存；重复恢复通知不会覆盖暂停前的时钟状态。

安全区使用 `DisplayServer.get_display_safe_area()`，按物理屏幕和逻辑 viewport 的比例映射。使用 canvas_items + expand 适配横屏比例。真实系统导航条的坐标语义仍需在目标设备验收。

## 存档

当前 schema 版本 3，版本 1 / 2 读入时逐步迁移；数据上限、整数/布尔类型、坐标范围、已知作物 ID、格子边界均有校验。JSON 的数字在读入时可能变成浮点，恢复时统一转回数量和天数整数。非法存档不会部分覆盖当前状态。

写入流程：临时文件 → flush → 原文件改名 `.bak` → 临时文件改为正式文件。新文件改名失败会尝试还原备份。读取顺序是正式文件、备份。未来添加新版本时应先实现显式版本迁移，不要直接放宽校验来猜测旧数据。

存档恢复后会检查玩家是否落在碰撞体内，必要时返回当前地图的安全入口。存档写入和地图数量均很小，本版采用同步文件 IO；未来大型世界可以将快照写入迁移到后台线程。

## 0.2.0 新增模块

`gathering/resource_catalog.gd` 给原有资源位置分配稳定 ID（如 `tree_7_20`）。`ResourceField` 拥有状态字典，`ResourceNode` 只维护绘制、碰撞和受击反馈。采集前校验工具、体力、完整掉落的背包容量，再更新耐久；枯竭后设置再生日期。换日时先确认玩家未占据出生区域，再恢复资源。存档包含部分采集耐久。

`resources/items/materials.json` 定义材料名称/收购价；`resources/progression/upgrades.json` 定义设施费用与说明；`quests.json` 定义委托前置、交付、奖励。所有纯 JSON 由导出预设的 `resources/**/*.json` 显式纳入，避免编辑器可运行而导出后丢失数据。

`Inventory.preview_exchange` 在副本上校验金币、消耗、奖励和堆叠上限；`exchange` 只在全部可提交时替换库存并发出一次变化信号。设施和委托调用同一接口，状态与奖励都设置完毕后才发出 `progress_committed`，主场景延迟一帧静默自动保存。失败交易既不扣物品，也不改变完成状态。

设施影响实际规则：工具架让采集伤害增加；引水渠在农田完成换日结算后补水；卧室通过 `GameState.max_stamina()` 统一驱动恢复和 HUD。设施状态恢复仅刷新视图，不重新扣费或派发奖励。

委托状态存为 1（进行中）或 2（已完成）；缺省为未接取，前置未完成时显示锁定。迁移器校验前置关系，拒绝未知设施、未知资源 ID、超限耐久与非法好感。随身手记只读，委托板打开可办理的同一个面板。

继续扩展设施时，除数据定义外还需要为效果添加规则处理；并非只改描述就会自动产生任意效果。任务可在现有交付类型内增加 JSON 定义与前置关系；任务页根据数据自动建立分页按钮。


## 0.3.0 共建河湾

- `Story` 读取 `resources/story/wind_lantern.json`。章节状态 0–8，包含条件请求、对话、两处选择、三处探索记忆；UI 展示与状态提交分离。关闭、显字、选项点击都不会提前扣费，只有完整读完才再校验并提交。结局必须在 18:00 后，聚餐必须三项共建完成。
- `VillageProjects` 读取 `village_projects.json`，独立持有设施及每日引水/喝茶日期；只允许在共建板附近建造。共仓影响 `FarmEconomy.seed_price()`，水井通过信号通知真实农田，茶座直接恢复体力。描述和效果不是自动绑定；扩展新效果仍需实现规则。
- 河湾村为 40×28 原生 TileMapLayer。旧桥 y=14..15、x=26..28 在阶段 5 时替换可通行地块；恢复故事同步重建桥面。隐藏地图禁用物理处理与地形。大型陈设有脚底碰撞；顶部画面不阻挡角色。
- `GameWeather` 由日期决定细雨，无随机重抽；成长使用昨天的水，之后补今天的雨水。雨天新翻土立即湿润。
- `dialogue_panel` 提供头像、逐字、选择、取消；旧版普通对白入口继续兼容。`story_panel` 提供共建、真实坐标地图、人物和记忆。`touch_scroll` 显式处理触点拖动，按钮滑动时取消点击，并检查祖先裁切范围。
- `landscape_details` 缓存地形接壤边线，仅在地图状态变化时重建；植物/水面以低频刷新。`weather_screen` 位于单独画布，显示雨、萤火、换图过渡和章节横幅，不截获输入。工具图标、衣着和建筑素材有可复现绘制脚本。
- 音效池与配乐/雨声独立；常驻声音跟随静音和前后台状态。无界面默认不启动常驻播放，自动测试显式启动来验证静音；渲染测试验证真实窗口的循环播放。关窗先存档、停止混音并留清理帧后退出，避免 Godot 4.3 长 WAV 强制退出时未释放播放对象。
- 存档 v3 校验已读主线与当前章节、选择与结局、建设与章节前置、每日福利日期；无效数据整体拒绝。v1/v2 迁移新增剧情与村庄字段取初值，保留旧经营数据。

## 0.5.0 小京深化：独立剧情层

`StarStory` autoload只拥有补充剧情与合约状态，旧`Xiaojing`继续拥有播种、三属性、任务、记忆、钻石和婚姻。`StarTrials`记录实际农田提交、有效新田销售、真实加工领取、矿道重访与联合协作。`StarWorld/StarPoint`仅表现与入口，`StarPanel`复用原安全区/长文滚动/模态按钮。新实体不增加地图墙体，不复制角色控制器。

`FarmSaveStore`写v8的`star_story`；`StarSaveSchema`整体验证后恢复，旧进度推导无奖励迁移。婚礼phase0–4分别为未开场、待布置、待最终确认、已扣钻待收尾、已结束。求婚事件不改变旧proposed==married约束。婚后日期始终按day-wedding_day，读取回信不依赖后台通知是否先执行。

`DiamondPayments`负责报价/确认/单笔支付上下文。`Inventory.preview_exchange`在临时钻石上下文将负金币费用折为钻石，仍完整验证材料/容量；`exchange`一次提交原库存、金币与独立钻石余额。上下文同步结束恢复，不写存档；原主线和制造仍检查各自前置。只有商品/服务UI明确确认后才启用该上下文，奖励事务不受影响。

## P0统一日结算与P1深渊

GameClock.request_sleep(expected_day)统一验证20:00–23:59与确认日期，兼容next_day也受限。_settle检查来源和重入锁，day_ending先清理移动/交互/模态，再唯一day_advanced。午夜走fatigue分支回60%，无需新增存档字段；剧情现只有等到18:00，无任意跳日接口。

AbyssState与LegendState为新增autoload；AbyssMap只保留当前40×28楼层，切层通过WorldTravel复用原玩家，地图数据在resources/abyss。AbyssPoint向状态层发请求，真实TileMap闸变化通知原Navigation失效并等物理同步；旧矿区常量与主线任务不改。

LegendTrials接收原农田成功提交、有效新田销售、加工入队/领取、深渊到达与村民协作，不从展示信号计数。强化徽记与原试炼ID同时认可但不重复发奖，避免十二约定与温室之间形成循环依赖。schema9独立abyss/legend在整档验证前只规范新分区整数表示，随后统一恢复；不把JSON整数浮点表示误当楼层枚举损坏。

## 0.6.0扩展层

River持有新增补充事件，不接管原农田/库存/小京关系。AbyssRules处理区域辅助台与机关轮次，AbyssMap仍只实例化当前100层之一。地格数据和已保存整数均规范化，已走格运行时哈希、保存时保留稳定列表。矿石再生由原day_advanced统一驱动，避开玩家。

GreenhouseVenue是独立场景，原Player/Camera通过WorldTravel复用；StarCeremony只负责位置与仪式步骤，最终扣钻仍由原Xiaojing确认事务完成。新增音轨注册到Audio.extra_channels，在统一静音/后台/退出流程中清理。新主线ID追加至原ChapterTwo，奖励与完成标志仍同一提交，River仅提供真实事实和政策。

v10在恢复前校验river与扩展abyss，旧任务/奖励/婚姻/操作方式不重置。普通玩家不启用测试夹具legacy_rules，旧已确认婚约与已接合约明确兼容；新合约/婚礼走0.6条件。

## 0.6.2湖泊养殖分层

Aquaculture autoload拥有状态和原子操作；fish.json定义物品、六鱼、三级设施、七配方。AquacultureSaveSchema只验证/初始化，不发奖。Catalog单独注册aquaculture_items，旧material工具UI不受影响。AquacultureWorld将四个interactable挂在原FarmWorld/Actors；可点击水面栏体，resolve返回岸边锚点。AquaculturePanel只展示/确认与发请求，距离、日期、库存、容量都在状态层重查。

GameClock.day_advanced是唯一日推进源，module和pen.last_settled_day防重，幼鱼cohorts保持独立四分日年龄，成熟和出生都在日结算；restore不调用settle。处理成功发progress_committed，由原main合并同帧自动保存。v11加aquaculture分区，不改变其他分区ID。鱼售卖复用FarmEconomy，已补所有成功交易提交信号。

小京合作只在原NPC日程切换站点，不创建第二个角色；09–18现场观察、三日真实照料与收获后一次小幅羁绊，不改原婚礼门槛。低频鱼群绘制按示意数量而非库存逐节点实例化，建造碰撞变化发navigation_changed。

## 0.7.0最终整合

11种地图场景共享原玩家（深渊复用100个实体楼层布局）。Calendar只派生绝对日期，GameClock仍唯一日结算；成功事务typed Events是节日/个人/贸易新产凭据，restore门控禁止补播。Catalog按economy.json注册原资源和新增模块同一ID，不混物品重复定义。新模块分别持有权威进度，WorldChanges只归一观察与展示，不再次建造或发奖。

状态层先预览/原子交换，再提交稳定ID、日限与progress_committed，由Main原同帧合并保存写v21；路径、触点、待确认与QTE临时运动不入存档。满包产物/加工/成功鱼桶保留，机关状态先驱动碰撞再导航失效+物理同步。房屋新侧间连接旧坐标、保护通路，独立家具库存/柜存不伪造Inventory资源。

天气/鱼群/灯光固定预算，原NPC不复制参加节日；最终站点只设置一次。动物18、家具40、当前深渊一层、三设计隐图均有硬上限。暖舍草垫低z绘制、动物侧牧区与室内位点分开；家具仅几何变化重建物理形状。特殊花以稳定家具ID/种植日记录，月夜推导气候条件，避免重写原农田或重抽旧天气。

### 首次导入

导入资源媒体使用运行时load而不在GDScript编译阶段preload，避免空.godot缓存时数据类依赖链提前请求字体/贴图/音频。路径与资源实例缓存机制保持，地图/媒体在实际节点初始化时加载；GDScript/场景预加载不改。开发检查使用--import等待资源导完，实际源包须在全新目录独立导入与启动，不靠本机缓存验收。
