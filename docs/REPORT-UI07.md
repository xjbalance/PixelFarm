# 全界面与建筑角色风格收口

基于`96a9667`，统一原手记地图、实际经营与剧情界面，以及建筑角色材质。仍是0.7.1、存档v24，默认点击与备用摇杆、原尺寸完整九格、经济和剧情条件保留。

- 公共材质与卡片：`3e0bca8`，细暖木边与羊皮纸内衬，正文最低实测对比度9.87。
- 全界面与手记地图：`05eaf90`，手记复用同一羊皮纸Canvas，经营和剧情页面统一标题、图标、纸卡、页签和资源信息。
- 世界材质：`9ec64c9`，六套角色、四座建筑和四级住宅共14PNG，原尺寸和全部透明轮廓逐像素保持。

[手记地图前后](journal-atlas-ui07/comparison.png) · [对话前后](story-ui07/compare-dialogue.png) · [背包前后](story-ui07/compare-inventory.png) · [厨房前后](facility-ui07/compare-kitchen.png) · [人物建筑前后](world-style07/compare-farm_home.png)

最终机器结果见[TEST-UI07.json](TEST-UI07.json)：5062项自动化、3335项桌面窗口、146个计划进程全部通过，34套窗口检查零失败。独立旧存档/坏档备份/异常SIGKILL恢复与最终APK实际资源启动检查通过。没有Android真机。

旧集成测试曾因固定控件子节点序号失效而中断，并产生连带失败；仅将`tests/story.gd`、`xiaojing.gd`、`mining.gd`改为按原按钮文字及所属项目卡定位，再滚入可见区发送原生触摸。原452项集成与98项矿洞断言恢复执行并通过，未删除原流程或用直接业务调用替代。

Android保持原包名与签名，versionCode18，68,447,924字节；SHA256 `9bac68944d54cd8ad9ef6102b3901c89cab840b62e9e1ede2ba83c8a1dfc09f8`。这仅说明导出、签名及包内桌面运行检查通过，手机视觉、DPI、触感与覆盖升级待验收。

详细修改与限制见[手记图纸](JOURNAL-ATLAS-UI07.md)、[常用剧情UI](STORY-UI07.md)、[经营设施UI](FACILITY-UI07.md)、[建筑角色材质](WORLD-STYLE-UI07.md)。原`WorldChanges.derive()`四级住宅派生摘要问题仍独立记录，日历对此做安全显示兜底，未改其业务状态。

后续角色方案C属于独立任务；此文记录本轮收口时的v24/code18基线。
