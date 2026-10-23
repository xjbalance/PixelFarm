# Android 导出与真机验收

## 当前状态

已实际生成并签名 [PixelFarm-0.3.0-debug.apk](https://github.com/xjbalance/PixelFarm/releases/download/v0.3.0/PixelFarm-0.3.0-debug.apk)，66,717,852 字节（63.63 MiB）。下载 APK 到手机后，用文件管理器打开，按系统提示允许该来源安装应用，再安装并打开「风芽农场」。手机无需安装 Godot、Java 或 SDK。

2026-10-23 使用项目内已有便携构建工具完成新版 APK 导出。最终文件通过 v1/v2/v3 签名验证、ZIP 完整性及对齐检查；包内游戏数据与源码一致，提取资源后在桌面 Godot 4.3 独立启动 180 帧无错误。**尚未执行 Android 真机或模拟器安装运行测试**。详细证据见 [APK 构建报告](APK-BUILD-0.3.0.md)。

与 0.2.0 使用相同包名和签名，可直接覆盖安装；不要先卸载旧版。剧情和共建使用存档 v3，旧经营进度迁移后保留。覆盖安装仍需真机确认。

安装包配置：横屏、Compatibility/OpenGL ES 3.0、ARM64 + ARMv7、包名 `org.pixelfarm.windbud`、版本 `0.3.0`（versionCode 3）、自有图标。最终 AndroidManifest 的最低版本为 **API 21 / Android 5.0**，目标版本为 API 34；没有申请任何 `uses-permission` 权限。手机还需支持 OpenGL ES 3.0。

普通模板导出使用模板内的 SDK 版本，`gradle_build/min_sdk` 和 `gradle_build/target_sdk` 必须留空，不能在未启用 Gradle 时覆盖。本次已修正旧预设，并开启 `rendering/textures/vram_compression/import_etc2_astc`，否则 Godot 4.3 会拒绝 Android 导出。

## 当前 Linux 工作区再次打包

```bash
cd /home/xiznhi/xiangqi/PixelFarm
python3 tools/build_android.py
```

脚本使用 `.tools/android/` 内的 JDK、SDK、导出模板与独立编辑器配置；仅首次创建 `.tools/android/keys/pixelfarm-debug.keystore`，后续复用。导出后自动核对签名、对齐、清单、两种 ARM 引擎和全部游戏 JSON，成功后更新 APK 与 `.apk.sha256` 文件。不会修改系统配置、安装到手机或下载依赖。

**保留并自行备份此 keystore**，未来更新使用相同包名和签名才能覆盖安装并保留存档。工具与密钥不进入源码压缩包；换一台构建机时须另行配置工具并安全迁移密钥。当前 APK 是用于直接安装试玩的调试版。

## 在 Windows 配置构建环境

1. 使用 **Godot 4.3 Standard**。在「编辑器 → 管理导出模板」安装精确版本 **4.3.stable**。Android 官方模板应包含 `android_debug.apk` 和 `android_release.apk`。
2. 安装 **OpenJDK 17**，确认 `java -version` 和 `keytool` 可运行。
3. 使用 Android Studio SDK Manager 或官方 command-line tools 安装：
   - Android SDK Platform-Tools（adb）。
   - Android SDK Build-Tools **34.0.0**（zipalign、apksigner）。
   - Android SDK Platform **android-34**。
   - Android SDK Command-line Tools。
4. 接受 SDK 许可证。在 Godot「编辑器设置 → 导出 → Android」中设置 **Java SDK Path** 与 **Android SDK Path**。路径为 JDK/SDK 根目录，不是 bin 目录。
5. 配置调试 keystore、用户名 `androiddebugkey`、密码 `android`。若 Android Studio 已生成 `%USERPROFILE%\.android\debug.keystore`，直接复用；没有时再创建，不要覆盖已有签名。

创建新的调试签名示例（PowerShell，确认文件不存在后执行）：

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.android" | Out-Null
keytool -genkeypair -keyalg RSA -keysize 2048 -validity 10000 `
  -alias androiddebugkey -keypass android -storepass android `
  -keystore "$env:USERPROFILE\.android\debug.keystore" `
  -dname "CN=Android Debug,O=Android,C=US"
```

签名文件与密码不应提交到源码仓库。本工程 `.gitignore` 已忽略 `*.keystore`。此预设使用标准 APK 导出，不要求启用 Gradle 自定义构建。

## 导出与验证

在项目目录执行：

```powershell
& "C:\Tools\Godot_v4.3-stable_win64_console.exe" --headless --editor --path . --quit
& "C:\Tools\Godot_v4.3-stable_win64_console.exe" --headless --path . `
  --export-debug "Android Debug" "builds/PixelFarm-0.3.0-debug.apk"
Test-Path "builds/PixelFarm-0.3.0-debug.apk"
Get-Item "builds/PixelFarm-0.3.0-debug.apk" | Select-Object Length, LastWriteTime
```

也可在编辑器「项目 → 导出 → Android Debug → 导出项目」中勾选调试后导出。只有导出退出码成功且文件存在，才视为生成成功。再使用 SDK Build-Tools 的 `apksigner verify --verbose builds/PixelFarm-0.3.0-debug.apk` 验证签名。

在已授权 USB 调试的测试手机上：

```powershell
adb devices -l
adb install -r builds/PixelFarm-0.3.0-debug.apk
adb shell am start -n org.pixelfarm.windbud/com.godot.game.GodotApp
adb logcat -s godot
```

如果启动器 Activity 在后续自定义导出中改变，可直接从手机桌面点「风芽农场」。以上设备命令是交付后的操作说明，本次未执行设备安装。

## 真机验收清单（待执行）

- 横屏启动，字体无缺字；长屏、刘海、挖孔和系统手势导航区域不遮挡按钮。
- 左指保持摇杆，右指点击工具/动作；抬起右指时左指继续移动，抬起左指后立刻停止。
- 手指拖出摇杆区域再抬起、切后台再返回、锁屏再解锁，不出现持续移动或时间卡住。
- 背包、商店和对话期间角色不动，时间暂停；界面关闭后输入恢复。
- 实际完成翻土、三种作物种植、每日浇水、室内睡觉、收获、出售和购买。
- 用斧头和镐完成采集，修建三项设施；在委托板接取/交付，通过手机触屏查看材料与委托手记。
- 从来信完整完成修桥、三项公共设施、聚餐和风灯夜；测试选择、手记触摸滚动、地图和每日设施福利。
- 保存后结束应用进程，再启动，确认室内/室外位置、日期、库存、金币与作物状态一致。
- 连续运行 20 分钟，使用 Godot profiler/设备工具检查帧率、内存、音频、发热与前后台恢复。

60 FPS 是工程配置目标，本次软件渲染和无界面测试不能证明手机上的性能。Android 真实系统安全区和多指硬件输入同样需要上述验收。

## Windows EXE

已提供 Windows Desktop 预设。安装匹配的 Windows 导出模板后可执行：

```powershell
& "C:\Tools\Godot_v4.3-stable_win64_console.exe" --headless --path . `
  --export-debug "Windows Desktop" "builds/PixelFarm.exe"
```

本轮已交付 Android APK 和可导入源码，未生成或测试独立 Windows EXE。
