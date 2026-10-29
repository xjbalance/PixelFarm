# 经营与设施界面统一：羊皮纸、暖木与自然绿

本轮只整理设施界面的显示层级、卡片、页签与说明，沿用共享`FarmUIStyle.card/heading`和现有原生触点按钮。没有修改材料、售价、时间、奖励、动物状态、钓鱼参数或存档结构。

## 实际变化

- 厨房：左侧保留原食谱选择，右侧增加真实料理图标、掌握/持有记录、单独的食材说明及同一行制作/食用操作；原配方、材料检查、确认回调不变。
- 畜牧：住处、照料繁育、动物记录与干草补给分为纸卡；已建畜舍和动物详情使用等级/数量/心情等清楚的小指标，按钮仍调用原状态层。
- 湖泊生态：生态、水草、淤积和水循环以指标展示，日常照料、恢复记录、月夜、共同研究分开阅读。
- 鱼栏：鱼苗、成年鱼、水质和健康分开显示；厨房、鱼栏、装修、节日、钓鱼页签均正确标明当前页，切换不扣资源。
- 四季历：今天、未来七日、农时与世界变化分为四组。已有世界变化派生为空时显示诚实的暂不可显示提示，避免旧四级住宅导致索引错误；没有修改`WorldChanges`的业务派生或清空进度。
- 家具装修、长期建设、隐藏地图调查、节日、天气、白天恢复等十一类设施共用标题、简短提示与纸面层级，完整九格HUD和既有场景行为保留。

## 真实窗口前后对照

[厨房前后](facility-ui07/compare-kitchen.png) · [生态前后](facility-ui07/compare-ecology.png) · [畜牧前后](facility-ui07/compare-livestock.png)

[厨房](facility-ui07/after-kitchen.png) · [家园](facility-ui07/after-housing.png) · [鱼栏](facility-ui07/after-fishpen.png) · [生态](facility-ui07/after-ecology.png) · [畜牧](facility-ui07/after-livestock.png) · [恢复](facility-ui07/after-recovery.png) · [共建](facility-ui07/after-development.png) · [隐径](facility-ui07/after-exploration.png) · [节日](facility-ui07/after-festival.png) · [四季历](facility-ui07/after-calendar.png) · [钓鱼](facility-ui07/after-fishing.png)

改造前在隔离的`git archive 96a9667`中运行同一进度与窗口夹具，保存顶部画面；改造后采用相同1280×720窗口。拼图仅整理真实帧，不绘制或伪造游戏界面。完整22帧与结果见[截图清单](facility-ui07/screenshots.json)。未把这些图片称为Android真机测试。

## 已执行专项

| 检查 | 实际结果 |
|---|---:|
| 原始厨房/生活窗口基线 | 41项，0失败 |
| 隔离旧版本十一类设施基线 | 232项，0失败 |
| 新设施状态与原生输入 | 316项，0失败 |
| 新设施真实桌面窗口 | 316项，0失败 |
| 原厨房/畜牧/生态/钓鱼/家园规则 | 470项，0失败 |
| 原厨房/生活/畜牧/钓鱼窗口 | 89项，0失败 |

专项遍历1280×720、1600×720、1280×960三种横屏，验证十一类公开入口、中文边界、按钮触区与滚动可达、地图防穿透、关闭恢复操作，以及51次真实页签切换的唯一高亮与资源不变。所有测试只使用临时用户目录，最终日志无脚本错误、失败或实例泄漏。这里只记录专项，不把它与整合回归重复相加。

日志：`builds/facility-ui07-before.log`、`facility-ui07-state.log`、`facility-ui07-window.log`、`facility-ui07-original-state.log`、`facility-ui07-original-window.log`。暂无Android设备，实际DPI、手指触感和手机性能仍待验收。

## 修改文件

新增纯展示组件`scripts/ui/facility_layout.gd`；修改十一类Panel：`aquaculture_panel.gd`、`ecology_panel.gd`、`kitchen_panel.gd`、`livestock_panel.gd`、`fishing_panel.gd`、`housing_panel.gd`、`world_development_panel.gd`、`exploration_panel.gd`、`festival_panel.gd`、`calendar_panel.gd`、`recovery_panel.gd`。

新增测试入口`tests/facility_ui07_runner.tscn`与`tests/facility_ui07_render.tscn`，供标准无头/窗口回归调用。共享主题、手记地图和世界素材由本轮其他独立部分统一处理。
