# 温馨田园住宅与家具自由摆放

当前基于`a09a661`，按用户确认的“温馨田园风”修改：暖木、奶油墙面、苔绿软装。正常游玩的完整九格与原尺寸界面保留，森林及128个树石点不变。未跟踪`need/`原参考图保留，未提交或打包。

## 怎么自己摆家具

1. 在家点击收纳柜，进入“布置与移动”，选择“直接在房间里布置”；也可在家打开菜单选择“布置房间”。
2. 点选家具，拖到新位置，或在列表中选择“移动原木床”等按钮后点击房间空地。
3. 半透明家具只是预览。松手后绿色表示可放，红色表示与家具、墙或必需通路冲突；点击“确认摆放”才提交。
4. “退出布置”保留原位置；“家具列表”可切换床、沙发、厨房、桌椅、柜、灯、植物、地毯与待安放物件，也能摆放库中已有的自制家具。

编辑时只临时把底部工具条换成布置操作栏，人物和时钟暂停；退出恢复原九格大小。触控和电脑鼠标均可拖动，支持多指/混合设备取消保护、UI防穿透。地图点位按视口变换，保留抓取偏移再按网格吸附，不把触摸屏像素误作世界坐标。

## 实际改变

原床、沙发、厨房、储柜、餐桌椅、斗柜、信件书桌、灯、植物、地毯、壁炉以及升级后的书房家具都由稳定ID的位置记录驱动。可布置区域扩为实际室内可走地板，原来只能摆几格的限制不再套在整个家上。

床、沙发、厨房、收纳、信件桌移动后，美术、实体碰撞、点击范围和使用位置一起移动。点击原位置不会继续调用搬走的功能。正式睡眠仍20:00后；沙发仍1小时恢复最大体力50%，午夜优先原疲劳结算一次；厨食配方、材料、加工与增益不变；柜存不复制。家内操作键优先识别面向且可触及的功能家具，避免新位置被附近旧剧情点抢走。

墙、门、窗属于房屋结构；房门和原剧情/NPC必需通路保留。确认摆放会验证整屋出口、侧厅、床/沙发/厨房/收纳/信件以及原剧情点，不能把玩家困住或隔墙使用家具。核心生活家具不允许收起到无法使用的状态；非关键物件若升级后尺寸变大且找不到空位，保留原记录为“待安放”，不会消失。

## 视觉

木床改为弧形实木床头、双枕、亚麻包边与苔绿拼缝被褥；沙发圆扶手/坐垫压线，厨柜为奶油柜面与温灰石台。餐桌、书架、陶器、盆栽、局部织毯与低噪声木板统一材质，墙面改奶油抹灰与暖木护墙。原自制家具也有同风格、原尺寸的独立贴图，保持最近邻及原角色/世界尺度。

当前住宅目录共60张PNG：沿用/重绘原51张，新增浅木地板和8张自制家具贴图，均由原Pillow像素生成器维护。

四级住宅保留成长差异。屋外仅玩家房屋贴图同步奶油墙、暖木门窗，1/2级暖棕瓦、3/4级苔绿瓦与少量暖星灯；四图仍192×168、透明轮廓与原图逐像素相同，不移动农场建筑入口或碰撞。

[前后对照](home-arrange/compare-interior.png) · [四级田园住宅](home-arrange/four-levels.png) · [移动布置演示](home-arrange/arrange-demo.gif) · [床预览](home-arrange/bed_preview.png) · [确认后](home-arrange/bed_after.png)。GIF是实际Godot窗口状态帧组合，不是手机录像或FPS测量。

## 存档与已有布局

schema从v23升为**v24**，只为住宅新增`builtins`记录，保存每级开放的内置家具ID、网格位置和必要的待安放标记。原`owned/placed/recovered/storage`继续复用，v23默认旧家具位置原样保留；原钱物、住宅等级、施工单、已婚关系、1314钻石、130体力升级、操作方式及其他系统不重置。

扩建时先保留玩家已摆位置，加入新房型家具；尺寸增长发生冲突时先就近安置，无法安置保留到可恢复收纳。自制家具移动保留原ID和序号，摆放只转移已拥有的一件，不重新扣制作材料，不复制储物。预览、手指、选中状态和编辑窗口不入档；确认完整提交后沿原tmp/备份/更名流程保存，重启不会重放移动。

## 验证与边界

开发前相关六套基线500项、住宅窗口44项通过，原14帧室内截图归档到`builds/home-arrange-before/`。

最终**4251项自动化、2534项桌面窗口检查、134个计划进程全部通过**；26套窗口检查均零失败。新增主套件159项、6个持久化进程27项和窗口86项（已包含于总数），见[机器记录](TEST-HOME-ARRANGE.json)。新测试包含真实原生点选/拖动/确认、非法位置与取消、UI与多指过滤、电脑鼠标、搬迁后使用新床/新沙发/新厨房/新柜、旧位置失效、升级与婚姻/体力保留、旧档和坏档备份。

实际修复过的集成问题：

- 纯几何原先把恰贴餐桌边缘的格子当作可走，实际物理有0.01余量；改为保守脚底检测，原错误厨房格21,9拒绝，纯/实际网格一致。
- 功能点和家具body分离后，沙发原锚点在本体内；以稳定ID关联自己的碰撞体，只排除自身，其他墙/家具仍阻挡射线。
- 修正RID集合判断与非住宅交互点返回空碰撞数组的Godot类型错误；这些有脚本错误的中间日志未计通过。
- 编辑操作栏取位需等待真实布局，状态短句不再自动换行撑大底栏；后台入口显式取消未提交编辑。

当前调试APK已导出，原包名`org.pixelfarm.windbud`和签名保留，versionCode 16；68,169,694字节，SHA256 `5fbcff27391aca9333c3728322810869b21b4b3d15f171a31ad2e62e64a341a0`。实际包内资源脱离源码在桌面Godot运行180帧、接口检查与真实SIGKILL后独立重启均通过。

没有Android真机，触感、设备DPI/挖孔、覆盖升级与手机性能仍待验收。真实窗口为Linux Godot4.3 Xvfb/Mesa；未虚构手机FPS或功耗。

## 主要文件与复现

主要修改文件按用途列于下表；全局九格布局、寻路算法、资源经济与世界地图保持原行为，原参考图未改。

| 范围 | 文件 |
|---|---|
| 家具布局与保存 | `scripts/housing/home_layout.gd`、`housing_state.gd`，`scripts/save/save_schema.gd`、`save_store.gd` |
| 摆放与预览 | `home_arrange_controller.gd`、`home_arrange_panel.gd`、`home_placement_preview.gd`、`home_builtin_target.gd` |
| 室内渲染 | `scripts/world/home.gd`，`housing_surface.gd`、`housing_extension.gd`、`housing_furniture.gd`，`tools/generate_home_interior_assets.py`与`assets/housing/interior/` |
| 功能点同步 | `home_action_point.gd`、`home_rest_controller.gd`、`housing_world.gd`、`housing_point.gd`，`scripts/kitchen/kitchen_state.gd`、`kitchen_world.gd`、`kitchen_point.gd`，`scripts/world/story_point.gd` |
| 家内输入与UI接入 | `scripts/core/main.gd`，`scripts/ui/hud.gd`、`system_panel.gd`，`housing_panel.gd`，`scripts/input/interaction_resolver.gd`与`scripts/navigation/navigation_manager.gd`的自身家具碰撞关联 |
| 验证与构建 | `tests/home_arrange_*`与相关旧版夹具，`tools/check_project.py`、`check_windows.py`、`verify_apk_runtime.py`，`export_presets.cfg` |

[Android调试APK](../builds/PixelWorld-0.7.1-debug.apk) · [完整源码包](../builds/PixelWorld-0.7.1-source.zip)。

```bash
python3 tools/check_project.py
python3 tools/check_windows.py
python3 tools/check_interrupt_071.py
python3 tools/generate_home_interior_assets.py
python3 tools/capture_home_arrange_artifacts.py
python3 tools/build_android.py
python3 tools/verify_apk_runtime.py
python3 tools/package_source.py
python3 tools/verify_source_package.py
```
