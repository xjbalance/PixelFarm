# 晴光河湾：明亮且统一的场景配色

根据“喜欢以前明亮的色彩，但继续使用提供的素材”和“需要整体性”的反馈，本轮统一处理地面、草木、建筑、庭院摆件、动画与室内材料。没有退回旧场景素材，也没有增加玩法。

## 直接查看实际效果

所有并排图左侧是本轮修改前，右侧是修改后。基线为 `f5a0203`，两侧使用同一套场景、时间、镜头和测试进度；图片只是拼接实际 Godot 窗口截图，没有对截图额外调色。

- [正常游玩视角](bright-world/compare_farm_hud_1280x720.png)
- [农场全景](bright-world/compare_farm_full_spring.png)
- [河湾村](bright-world/compare_village.png)
- [森林](bright-world/compare_forest.png)
- [室内](bright-world/compare_home.png)
- [四级住宅](bright-world/compare_house_level_4.png)
- [四季总览](bright-world/four-seasons.png)
- [玩家布置的庭院](bright-world/after/farm_player_garden.png)
- [20:9 横屏](bright-world/after/farm_hud_20x9.png) · [4:3 平板](bright-world/after/farm_hud_tablet.png)

住宅四级、已修复温室与示范庭院使用明确的进度/布置夹具，不会给新游戏自动发放这些内容，也没有修改玩家自己的存档。

## 整体统一的处理

公共色板为 [world_palette.json](../resources/presentation/world_palette.json)，共 89 色，按绿叶、木土、屋顶、米白、石材、水色、雪色、花色与星辉分组。原先偏橄榄黄的草地改为嫩绿，夏季保留较浓的绿色，秋季为暖金，冬季为柔和雪色。建筑和家具一起进入相同的暖木、奶油和阴影色阶。

草地、道路和大块土地减少高频碎色，不使用抖色；树冠、屋顶和家具保留结构细节，让环境前后层次更清楚。连接图块的草地边缘与基础草地使用同一配色，避免改造后的地表变成另一种绿。夏季重复斑驳经过实际四季截图检查后单独收敛。

住宅、摊位、资源树石与部分家具使用同一套低透明度像素落地阴影。阴影跟随原节点，无碰撞、无触控覆盖、无逐帧 Shader。室内地板、墙面、现有床/沙发/厨房以及预览图也使用同一配色。

本轮保留 **97 款提供的世界素材**。150 份原始运行文件 SHA256 校验全部一致，`need/` 没有改动；调色结果单独派生。384 张调色 PNG 的尺寸和 Alpha 均逐项核对保留，原锚点、动画帧数/帧率及物件身份保留。角色方案 C 原始行走图未替换为其他来源。

## 实测数据与回归

固定白天农场窗口、相同背景采样区的 sRGB 加权图像亮度如下。此处是像素统计，不是物理照度或主观质量评分。

| 采样 | 修改前 | 修改后 |
| --- | ---: | ---: |
| 草地平均亮度（0–255） | 136.62 | 169.79 |
| 草地亮度标准差 | 14.05 | 1.67 |
| 道路平均亮度（0–255） | 160.42 | 192.36 |
| 道路亮度标准差 | 16.92 | 4.04 |

HUD 标题区逐像素一致，九格工具栏和原布局保留。完整机器记录见 [results.json](bright-world/results.json)。

- 全工程回归：**188 流程、9,736 项检查，0 失败**，覆盖旧档恢复、农场编辑、生产、房屋、关系、婚姻和原操作模式。
- 针对资源、自然、摆件、DIY 与家内布置的 787 项复核通过；最终地面色值微调后，自然 75 项与农场 140 项再次通过。重复回归未累加到 9,736。
- 节日图标实际渲染专项 17 项通过，白方块修复保留。
- 实际 X11 Godot 窗口：修改前后各 20 张截图，覆盖四季、四级住宅、室内、村庄、森林、庭院预览和三种横屏形状。
- Windows 新版独立 PCK 启动检查通过。Android APK 包名、原签名、版本 code27、双 ARM 架构和 ZIP 对齐检查通过；实际导出资源的 97 款静态/动画明亮路径加载、住宅移动、保存恢复检查通过。
- 存档继续为 **v27**，没有新增持久化设置，不重置已有布局、物品或进度。

未执行 Android 真机或原生 Windows 硬件验收。

## 构建与维护

Windows 成品：`builds/PixelWorld-0.8.0-Windows-x64.zip`，完整解压，使用配套 EXE 与 PCK。Android：`builds/PixelWorld-0.8.0-debug.apk`。源码：`builds/PixelWorld-0.8.0-source.zip`。

调色重建：`python3 tools/brighten_world_assets.py`。每次都从原始运行素材开始，不叠加上次调色；普通素材重新导入也会调用这一流程。公共调色函数在 `tools/world_palette.py`，运行端只选已处理好的贴图，不实时转换图像。

对比截图：`python3 tools/capture_world_assets.py --output docs/bright-world/after`；历史基线可用 `--before --ref f5a0203 --output docs/bright-world/before`。汇总：`python3 tools/summarize_bright_world.py`。

本轮调整统一色彩、纹理强弱和落地关系。林芽、周砚、阿禾仍是原有造型；没有独立新素材的室内家具保留原有形状并统一配色，不能当作新增独立造型已交付。缺少的同风格角色与家具素材仍见 [素材缺口清单](NEED-ASSET-GAPS.md)。现有地图布局和地下关卡未重做。
