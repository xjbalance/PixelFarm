# 0.8.2 野莓加工入口修复

基线 `314996b`，开发分支 `fix/0.8.2-workshop-access`。

## 确认的问题

用户补充确认：点击鸡圈上方的物件能打开面板，但内容是摘取野莓。该物件实际是野莓丛，并非已摆放的果酱锅。原采摘面板仍显示“小屋厨房”标题和料理/加工/领取标签，但莓丛分支会提前返回，点击标签不会切换内容，因此容易让人以为加工台坏了。

同时发现独立问题：野莓果酱仅留在旧厨房加工配置中，实体果酱锅漏接了这条配方。厨房新面板只展示设备安装说明和旧订单收取，没有新建旧加工订单的按钮。原“带回厨房熬酱”提示已经不符合实际入口。

## 修复后的操作

1. 点击野莓丛，打开明确命名的“野莓采集 · 果酱原料”面板；隐藏不适用的厨房标签，保留每日采摘规则。
2. 点击“前往果酱锅”，沿现有点击寻路走到可达的实体果酱锅，再打开原加工界面。按实际可达路径选择设备，不远程开工或传送。
3. 果酱锅选择“野莓果酱”：野莓4份＋小麦1份，加工2游戏日，产出原物品 `berry_jam` 1份，售价仍为48金。
4. 没有已摆放且可到达的果酱锅时，保留采摘面板并提示建设或留出通路。常规建造入口为“菜单 → 建造 → 摆件 → 加工设备”，成本仍为木材6、石头8、铜锭1、100金；原免费安装权益与整机重放规则不变。

回到住宅厨房后，厨房标题与全部正常标签恢复。旧厨房订单继续在厨房“领取成品”中收取，新订单保存在实体果酱锅中。

## 兼容与验证

存档仍为v30，无字段迁移。复用原物品ID、背包交换、加工状态机、游戏时钟、设备搬迁和旧订单恢复规则；不调整产量、售价、季节、婚礼或钓鱼。

修复前新增专项重现了“实体果酱锅没有野莓果酱配方”；默认修缮台和家具台能正常打开，没有将它们误报为故障。修复后7个相关自动化场景共535项检查、实际Godot X11窗口38项检查全部通过。另通过全配方引用/可达性校验，现为51条实体加工配方。

专项覆盖鼠标与原生触点打开设备、莓丛到设备的实际行走、未建设备时不扣物品、确认/取消、只扣一次原料、两日跨天加工、搬迁与整档读写、满包保留和领取防重复。相关回归覆盖旧厨房队列、全加工配方、加工触点、UI和农场障碍交互。详见[机器结果](workshop-hotfix/results.json)、[专项日志](workshop-hotfix/headless-acceptance.txt)、[窗口日志](workshop-hotfix/window-acceptance.txt)与[配方校验](workshop-hotfix/recipe-validation.json)。

实际运行截图：[野莓采摘入口](workshop-hotfix/berry-guide.png)、[测试夹具中鸡圈上方的实体果酱锅](workshop-hotfix/jam-pot-location.png)、[野莓果酱配方](workshop-hotfix/jam-recipe.png)、[待领取](workshop-hotfix/jam-ready.png)、[领取后](workshop-hotfix/jam-collected.png)。截图中的设备位置与资本属于隔离测试档，不会自动向玩家原农场增加设备或搬迁原布局。

复现与验证命令：

```bash
python3 tools/test_harvest.py workshop_access_runner kitchen_b_runner harvest_processing_runner harvest_chains_runner harvest_touch_runner quality081_ui_runner ranch082_obstacle_runner
python3 tools/capture_ranch082.py workshop_access_runner
```

## Windows 修复包

`builds/PixelWorld-0.8.2-berry-hotfix-Windows-x64.zip`。完整解压后保留EXE与PCK同目录；沿用原应用名称、存档路径与v30存档。原0.8.2安装包保留，避免把旧包校验记录与本修复包混用。[修复包元数据](workshop-hotfix/windows-package.json)记录完整校验值。

本次交付Windows修复包，未重新导出Android APK；没有Android真机及原生Windows硬件验收。Windows包内资源启动检查通过；实际EXE经Wine验证中文路径、游戏窗口与存档重启，[Wine结果](workshop-hotfix/windows-runtime.json)绑定本修复包的EXE和PCK校验值。
