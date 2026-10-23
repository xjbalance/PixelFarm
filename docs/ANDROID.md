# 像素世界0.4.0 Android构建与设备验收

默认点击地面自动寻路、点击对象靠近后执行一次原交互。八格工具栏、右下使用按钮保留；菜单随时切换备用虚拟摇杆并自动保存。切换、模态界面、地图变化和后台会取消旧路径与待执行动作。小京复用同一点击交互入口；桌面原生触点测试通过，手机触感待验收。见[操作说明](TOUCH-CONTROLS.md)。

## 更新兼容配置

| 项目 | 当前值 |
|---|---|
| 显示名称 | 像素世界 |
| applicationId | org.pixelfarm.windbud（不变） |
| 版本 | 0.4.0 / versionCode 5 |
| 引擎 | Godot4.3 Standard，Compatibility / OpenGL ES3 |
| 架构 | ARM64 + ARMv7 |
| 最低/目标SDK | 21 / 34 |
| 用户目录 | 原Android应用私有目录 |
| 签名 | 复用原调试密钥，证书摘要与0.3.0一致 |
| 图标 | 沿用本项目原创嫩芽像素图标 |

证书SHA256：`89455063278c15e708389a2caff957c7254ff2e88b3e19aaf23cdd755c90414b`。构建脚本缺少原密钥或证书不符时会失败，避免无意创建不能覆盖安装的新包。该调试签名是工程中已有的交付身份；没有另换所谓正式签名。

## 本机构建

```bash
python3 tools/check_project.py
python3 tools/simulate_xiaojing.py
python3 tools/build_android.py
python3 tools/verify_apk_runtime.py
```

使用`.tools/android`的JDK17、SDK34、匹配4.3模板与独立编辑器配置，不自动下载，不安装到设备。必须保留并安全备份原`.tools/android/keys/pixelfarm-debug.keystore`。源码包不包含任何密钥。

导出先写pending APK，核对签名、包名、名称、入口、版本、ZIP/对齐、双架构、游戏JSON与许可后才替换交付文件。APK提取资源后的桌面启动不能替代Android运行。

## Windows构建

Godot4.3 Standard安装4.3.stable Android模板，配置JDK17、SDK Platform/Build-Tools34与**原更新密钥**。不要创建替代签名后宣称可覆盖旧版。项目使用标准模板导出，不必开启Gradle；预设的gradle min/target留空。

```powershell
& "C:\Tools\Godot_v4.3-stable_win64_console.exe" --headless --editor --path . --quit
& "C:\Tools\Godot_v4.3-stable_win64_console.exe" --headless --path . --export-debug "Android Debug" "builds/PixelWorld-0.4.0-debug.apk"
```

APK可传到手机直接安装，无需手机上安装Godot。旧版更新时不要卸载或清除数据。在已授权测试手机上可执行：

```bash
adb install -r builds/PixelWorld-0.4.0-debug.apk
adb shell am start -n org.pixelfarm.windbud/com.godot.game.GodotApp
adb logcat -s godot
```

以上设备命令为说明，本次没有执行手机安装。

## 待执行真机验收

- 横屏、刘海/手势导航安全区、长手记与小京长列表滚动、按钮点击不穿透。
- 默认点击地面/农田/资源/人物的到达与单次动作、不可达提示、移动NPC重规划。
- 菜单双向切换、重启模式恢复；备用摇杆保持移动时第二指操作工具；松手、锁屏、后台恢复不持续移动。
- 新主线完整游玩；NPC找到、通桥碰撞、共建/每日福利与选择保存。
- 小京夜信、赠礼限额、路线盘/九格机关、婚礼确认取消与读取。
- 原0.3.0覆盖安装保留同一份真实存档；损坏主档退回备份。
- 20分钟以上后台/重启/音频/性能、内存、功耗与发热。

无Android真机或模拟器验收记录，60FPS仍是目标。桌面输入注入和Mesa软件渲染无法证明手机手感与硬件兼容性。
