# 常用与剧情界面的羊皮纸风格统一

本轮只调整界面布局、显示层次和样式，使用公共`FarmUIStyle.card()`与`heading()`，沿用原安全区、触控按钮和滚动逻辑。完整九格HUD的布局与尺寸由原模块保留，未在此处缩小。

## 具体变化

| 界面 | 实际改动 |
|---|---|
| 背包与商店 | 标题增加原地图符号；选中物品说明和每条物品行使用轻纸卡，名称、图标、数量与动作位置更清楚；出售确认说明与数量操作分组 |
| NPC对话 | 头像增加薄纸框，正文置于阅读卡，人物姓名去掉整条厚底；保留132×148以上头像、原正文、逐字显示和末尾选择 |
| 委托与修缮 | 标题、描述、费用、奖励和最终动作成组；移除费用容器92px的固定空白，当前页签具有实际选中态，主要动作靠右 |
| 设置与正式睡眠确认 | 说明和操作分为纸卡，标题与原图纸符号一致；原功能、操作模式切换、睡眠限制及保存读取流程保留 |
| 人物近况 | 头像与姓名、生日、好感和每日近况并排；赠礼、现场提示与个人约定使用分组纸卡 |
| 小京与星光手记 | 统一羊皮纸外框，星紫只点缀标题和特殊按钮；阅读故事时头像与正文并排，关系、记忆和动作保留原数据 |
| 矿洞、深渊与河湾档案 | 复用轻纸卡分组正文和动作；深渊、河湾档案、星光手记使用各自明确的窗口标题，避免共用矿洞标题 |

矿洞的`content_cards`仅是视觉布局开关，便于继承面板选择自行分组；不进入存档。旧内容被清除后，分组引用自动失效并重建，不长期保留旧窗口节点。

## 原功能与数据保护

本轮没有改动业务回调、剧情正文、任务条件、物品价格、体力、成长和存档结构。按数量出售的选择、旧确认token失效、库存变化校验及唯一结算继续使用原逻辑；新纸卡只改变控件的视觉父容器。

自动化逐字段检查了背包、商店、对话、委托、设置、关系和矿洞等面板的打开、查看与关闭：钱物、成功播种、住宅、施工、婚姻和其他进度不因查看改变。原生触点点击界面空白不会穿透到农场或执行旧交互。

## 实际测试

| 检查 | 结果 |
|---|---:|
| 修改前状态基线：数量出售35、背包51、Palm28、点击移动53 | 167项，0失败 |
| 修改前真实窗口基线 | 40项，0失败，12帧 |
| 新界面状态专项 | 68项，0失败 |
| 新界面真实窗口专项 | 68项，0失败，16帧 |
| 原相关回归：上述167项加UI05布局308项 | 475项，0失败 |

专项覆盖1280×720、1600×720和1280×960，验证界面位于安全区、按钮保留当前最小触区、分组存在、UI防穿透及查看不改变原数据。完整全局回归和更广泛密度矩阵由主交付记录汇总，不将这些专项重复相加成总数。

最终日志为`builds/story-ui07-state-final.log`、`builds/story-ui07-window-final.log`；原回归为`builds/story-ui07-regression.log`。这些最终运行无脚本错误、FAIL或实例泄漏，测试均使用临时用户目录。

入口为`res://tests/story_ui07_runner.tscn`，无头执行状态检查，实际窗口执行时同时截图。`-- --baseline`仅用于开发前保存原界面，不把优化后画面伪称原图。

## 真实窗口对比与截图

[对话前后](story-ui07/compare-dialogue.png) · [背包前后](story-ui07/compare-inventory.png) · [委托前后](story-ui07/compare-quest.png) · [人物近况前后](story-ui07/compare-social.png) · [完整截图清单](story-ui07/screenshots.json)

[背包](story-ui07/after-inventory.png) · [商店](story-ui07/after-shop.png) · [数量出售确认](story-ui07/after-sale_confirmation.png) · [NPC对话](story-ui07/after-dialogue.png) · [委托](story-ui07/after-quest.png) · [设置](story-ui07/after-settings.png)

[人物近况](story-ui07/after-social.png) · [小京](story-ui07/after-xiaojing.png) · [矿洞](story-ui07/after-mine.png) · [深渊](story-ui07/after-abyss.png) · [河湾档案](story-ui07/after-river.png) · [星光手记](story-ui07/after-star.png)

目录包含12张修改前、16张修改后和4张对比图。所有原始帧来自真实Godot窗口；对比图只并排整理帧，没有重画截图。捕获使用可重复的进度夹具，背景为后续建筑/角色材质统一之前的世界版本，不能用这些背景推断最终世界美术差异。

## 文件及待验收

生产文件：`scripts/ui/dialogue_panel.gd`、`inventory_panel.gd`、`progress_panel.gd`、`system_panel.gd`、`xiaojing_panel.gd`、`mine_panel.gd`，以及`social/social_panel.gd`、`abyss/abyss_panel.gd`、`river/river_panel.gd`、`star/star_panel.gd`。新增专项为`tests/story_ui07_runner.gd/.tscn`。

公共主题和其他设施的整合由对应模块完成。本子任务没有添加新玩法或改动世界地图。没有Android真机，真实手机的触控手感、DPI、安全区和覆盖安装仍待验收；桌面窗口结果不等于手机实测。
