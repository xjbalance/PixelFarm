# 像素世界0.7.1 Android构建与待真机验收

当前交付`builds/PixelWorld-0.7.1-debug.apk`，67,973,185字节。SHA256：`bae419924d192cc6f8d8653f8769edd4f23eeeabdc1900144ff958b42b4084bf`。原0.7.0记录见[历史说明](ANDROID-0.7.0.md)。

已实际导出，原证书验证、清单/双ABI、ZIP对齐/CRC、全部JSON与许可验证通过；提取最终APK实际资源在隔离桌面Godot启动180帧，检查v22/教学/出售确认的包内代码接口通过。这些不等于在Android运行。

| 项目 | 当前配置 |
|---|---|
| applicationId | org.pixelfarm.windbud，保持不变 |
| 版本 | 0.7.1 / versionCode 12 |
| 引擎 | Godot4.3 Standard / Compatibility GLES3 |
| ABI | ARM64 + ARMv7 |
| 最低/目标SDK | 21 / 34 |
| 存档 | v22，兼容v1–v21，原私有目录/旧自定义路径不变 |
| 原证书SHA256 | 89455063278c15e708389a2caff957c7254ff2e88b3e19aaf23cdd755c90414b |
| 权限 | 无uses-permission声明，不申请网络权限 |

## 可复现构建

```bash
python3 tools/check_project.py
python3 tools/check_windows.py
python3 tools/check_interrupt_071.py
python3 tools/build_android.py
python3 tools/verify_apk_runtime.py
```

Linux入口使用本机`.tools/android`内JDK17、SDK34、4.3模板与原keystore；隔离编辑器/XDG/ADB15037，不修改全局SDK、不重新生成签名。先写pending，签名/清单/对齐/CRC/JSON/许可全部验证后才替换交付APK。密钥不打进源码包，仍保留本机原路径。Windows/macOS可导入Godot工程，但本轮没有这些平台构建/实机结果。

## 本轮触控与性能变化

触点按下时捕获坐标和对象，追踪移动NPC/动物，换工具/多指/混合输入/后台取消旧意图。工具脚底和朝向短锁不叠加动作，目标环区分地面/交互/不可达。主要按钮≥48×48逻辑像素，设置/指南滚动，出售全部最终确认。保留默认点击和备用摇杆，选择仍存档。

提示10Hz、NPC同帧静态导航采样共享、动物60Hz物理与4Hz像素帧、天气空重绘/转场清理、隐藏UI不处理每次输入。现有一盏无阴影洞灯、节点/家具/动物上限和按地图启停继续保留。CPU测量与生命周期数据见`PERFORMANCE-0.7.1.json`，不包含手机FPS/功耗。

## 真机验收清单：全部待执行

本轮实际`adb devices -l`无连接设备，证据`builds/devices-0.7.1.log`。以下是后续设备操作说明，本轮没有安装或覆盖。

```bash
adb install -r builds/PixelWorld-0.7.1-debug.apk
adb shell am start -n org.pixelfarm.windbud/com.godot.game.GodotApp
adb logcat -s godot
```

安装前备份原APK和原存档。使用原签名覆盖，勿卸载旧包来冒充升级验证。

| 待验收项目 | 设备上记录/判定 |
|---|---|
| 覆盖升级 | 0.7.0/v21→0.7.1/v22，钱/作物/矿层/家具/动物/鱼栏/小京三属性、婚姻、钻石、婚后日期、操作模式逐项不变；老档不重新弹教学 |
| 屏幕 | 常用16:9、全面屏、平板及刘海/导航条；九工具、背包、任务/手记、对话、钓鱼、家具、商店、鱼栏、畜牧、深渊、婚礼确认均可触达 |
| 相机与目标 | 长距离行走中按下/释放不换格，移动NPC/动物仍追踪本人，不可达有红环反馈且无扣费；连点、双指、拖动、UI无穿透 |
| 农活 | 轻触连续多格，浇水脚底/朝向稳定，播种/翻土/收获/砍伐/采矿不叠加，结束可移动，打开背包不执行工具 |
| 体力/日结算 | 椅子3次/20分钟/15点、满体力不耗；餐/茶日限、取消/重复确认无资源变化；20点前不可睡，午夜唯一结算作物/矿石/鱼/每日状态 |
| 后台与中断 | 锁屏/来电/切后台/系统回收/强关后恢复，旧触点/路径不恢复；深渊不在后台受伤，鱼获/加工/婚礼不重领或重扣 |
| UI重要操作 | 出售/家具/婚礼取消不扣材料，最终确认只结算一次；长文/列表拖动及两控制模式自由切换 |
| 长负载 | 至少20–60分钟，三舍18动物/40家具/恶劣天气/夜晚节日/100层切换，记录型号、Android版本、FPS、加载耗时、CPU/GPU、RSS/内存、温升、电量 |

Linux/Xvfb窗口原生触点、隔离进程SIGKILL、模拟安全区与APK导出不能替代这些项目。暂未给出真机验收结论。
