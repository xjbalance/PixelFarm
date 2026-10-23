# GitHub 参考调查

调查日期：2026-10-22。通过 GitHub API 与 raw 文件访问读取 README、根目录、递归脚本路径、项目配置和许可证信息，研究资料保存在本地 .tools/research-0.3；少量源码仅用于结构分析，不加入游戏、不进入源码交付包。

| 仓库 | 本次检查提交 | README 与实际项目配置 | 许可证结论 |
|---|---|---|---|
| [Cai-Junhao/FarmPixel](https://github.com/Cai-Junhao/FarmPixel) | `7ca9dc2a8e6fa0b289c528ad405db96fc08b7893` | README 称 Godot 4.3；实际 project.godot 声明 **4.4 / Forward Plus**，GDScript | API license=null，顶层无 LICENSE；README 提醒内置素材仅供演示，不能据此推定代码或素材可复用 |
| [nadia-nh/rc-godot-farm-rpg](https://github.com/nadia-nh/rc-godot-farm-rpg) | `c80e6e85af60469b322f7cc696e8556bf0ee9438` | README 称 Godot 4；实际声明 **4.5 / Forward Plus**，GDScript，主场景 UID 引用 | 顶层 LICENSE，GitHub 标识 **GPL-3.0**；美术另有 CC0 等分别声明，不能将其统一视作无条件可复用 |
| [Ellemire/Bloomrise](https://github.com/Ellemire/Bloomrise) | `3d734c8be47d1292328c5ec972e824cb3854843d` | README 称 Godot 4.0+；实际声明 **4.4 / Forward Plus**，GDScript，含 Dialogue Manager 与 Git 插件 | API license=null，顶层无 LICENSE；addons 内许可证仅适用于对应插件，不能代替游戏整体许可 |

## 目录和设计观察

FarmPixel 将角色状态放在 `scenes/characters/`，成长与交互等组件放在 `scenes/components/`，全局时间/背包/工具管理位于 `scripts/globals/`。README 描述按 Y 排序、分碰撞层以及每日成长事件，适合借鉴“表现层与规则分离”。仓库还包含 `.godot` 缓存，不适合作为本工程的直接起点。

rc-godot-farm-rpg 使用 `scripts/`、`resources/`、`scenes/`、`styles/`；README 明确描述 `GameManager`、`FarmManager`、`CropData`、`InputDispatcher`、`UILayer` 与 Signals。其收获自动出售和动作预算属于自身设计，本项目独立采用背包收获后去摊位出售，并增加双触点输入。

Bloomrise 使用 `scenes/characters/`、`scenes/components/`、`inventory/`、`dialogues/`、`addons/`、`scripts/globals/`；README 描述状态机、雨天浇水、背包、商店与任务界面。本项目第一版只取独立 NPC、数据作物、场景入口的结构思路，未引入插件、天气、任务或任何参考代码。

## 本工程实施决策

- 锁定 Godot **4.3 Standard**，不依赖这些仓库更高版本的 UID 场景引用。
- 优先使用 Godot 原生 TileMapLayer、CharacterBody2D、Signals、Resource 与 JSON。
- 地图、角色、林芽对话、种子价格、生长数据、UI、音效和脚本均独立制作。
- 不分发三个仓库的代码、美术、截图、角色或音乐，也不使用《星露谷物语》资源。

本记录仅说明实际检查范围与复用决策，不将 GitHub 的公开可访问性等同于授予使用许可。


## 0.3.0 追加调查：村庄体验与条件对白

2026-10-23 实际读取 README、许可证、目录树和部分相关文件，筛查适合参考的开源项目：

| 项目 | 检查版本 / 许可证 | 实际分析与本工程取舍 |
|---|---|---|
| [Kenny-Haworth/Harvest-Moon-2.0](https://github.com/Kenny-Haworth/Harvest-Moon-2.0) | `8d9ccc4e49ad86b22eb38a9e00ddfa60150cd00c`；MIT，Kendall Haworth 2020 | README、Godot3时代 project.godot、`areas/Town.gd`、`ui/dashboard/weather/Weather.gd`。参考农场/村镇连通和天气反馈；旧 API 不直接移植，代码许可证也不据此替代全部素材授权。 |
| [elliotfontaine/untitled-farming-sim（Seasons Gone）](https://github.com/elliotfontaine/untitled-farming-sim) | `c509cab1614eab245e5bc7a4c27034cfa318f7e8`；MIT，Elliot Fontaine 2023 | README、LICENSE、Godot4.1 Compatibility 项目设置、`world/world.gd`；640×360设计。参考环境氛围与天气/作物联动，独立实现色板、雨声和先结算后补水。 |
| [nathanhoad/godot_dialogue_manager](https://github.com/nathanhoad/godot_dialogue_manager) | MIT；检查兼容 Godot4.3 的 **v3.3.3** 文档；当前 main 需要4.6 | `Basic_Dialogue.md`、`Conditions_Mutations.md`、README、LICENSE。学习条件对白、选项、文本与状态分离；本项目用原生 JSON + GDScript 实现，不安装插件，不复制其实现。 |
| [godotengine/godot-demo-projects](https://github.com/godotengine/godot-demo-projects) | MIT；查 README 与根目录 | 引擎示例需要匹配版本分支；本项目仍锁定4.3，不把最新分支当作兼容保证。 |

原先三个指定项目再次核对：FarmPixel、Bloomrise 的游戏整体许可证仍不明确；rc-godot-farm-rpg 为 GPL3 且实际引擎较新，因此没有直接以其游戏内容作为交付基础。

研究落实到本版的独立实现：第二张村庄地图、条件对白与人物头像、两处选项、修桥碰撞改变、数据驱动公共设施、地图手记、雨天作物、环境细节与循环配乐。故事按用户偏好围绕共同建设村庄展开；首章具体内容详见 README。上述项目的代码、角色、图像、音乐和截图均未被复制进游戏。
