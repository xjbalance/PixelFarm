# Android APK 构建记录 · 0.2.0

2026-10-22 已真实导出 [PixelFarm-0.2.0-debug.apk](../builds/PixelFarm-0.2.0-debug.apk)。这是独立可安装的 APK，内含游戏引擎、代码、字体、像素资源、音效和数据，不需要另外下载 PCK。尚未在 Android 真机或模拟器安装运行。

## 交付文件

| 项目 | 最终文件实测值 |
|---|---|
| 文件 | `builds/PixelFarm-0.2.0-debug.apk` |
| 大小 | 64,493,729 字节 / 61.51 MiB |
| SHA-256 | `1449e0957ee13cdfb9703577e057614987a35e3448d16dc712b12feae6aa6141` |
| 包名 | `org.pixelfarm.windbud` |
| 显示名 | 风芽农场 |
| 版本 | 0.2.0 / versionCode 2 |
| 架构 | arm64-v8a、armeabi-v7a |
| 最低 Android | API 21 / Android 5.0，需支持 OpenGL ES 3.0 |
| 目标 Android | API 34 / Android 14 |
| 启动入口 | `com.godot.game.GodotApp`，MAIN / LAUNCHER |
| 屏幕 | landscape（screenOrientation=0） |
| 应用权限 | 最终清单没有 `uses-permission` 项 |
| 签名 | 项目专属 RSA 2048 调试密钥；v1、v2、v3 验证通过 |

SHA-256 校验文件为 `builds/PixelFarm-0.2.0-debug.apk.sha256`。签名证书 SHA-256：`89455063278c15e708389a2caff957c7254ff2e88b3e19aaf23cdd755c90414b`。

## 实际执行的验证

- Godot 4.3 命令行 `--export-debug "Android Debug"` 退出码为 0，最终 APK 文件存在且非空。
- Android Build-Tools 34.0.0 `apksigner verify --verbose --print-certs` 通过；无需另附签名文件即可安装。
- `zipalign -c -v 4` 通过，ZIP 所有条目 CRC 校验通过。
- `aapt dump badging` 与 `aapt dump xmltree` 确认上表的包名、版本、最低/目标 SDK、启动入口、横屏和架构。
- 两种 ARM 引擎库均在 APK 中，全部四份游戏 JSON 与当前源码逐字节一致。
- 只从此 APK 提取 `assets/` 到隔离临时目录，使用桌面 Godot 4.3 启动 180 帧成功，无脚本/资源错误；不依赖原工程目录。此项检查的是打包资源可运行，不能替代 Android 系统安装和硬件测试。
- 此前已完成的 161 项游戏集成断言及跨进程存档验证见 [验证报告](VALIDATION.md)。本次未改变玩法脚本。

证据日志均在 `builds/`：`android-export-0.2.0.log`、`android-signature-0.2.0.log`、`android-alignment-0.2.0.log`、`android-manifest-0.2.0.log`、`android-manifest-tree-0.2.0.log`、`android-apk-assets-runtime-0.2.0.log`。

## 工具与修复

所有工具位于工程 `.tools/`，没有修改全局 Java/SDK/Godot 配置：

- 官方 Godot `4.3.stable.official.77dcf97d8` Standard Linux 引擎。
- Eclipse Temurin JDK `17.0.20.1+1`，下载后比对官方 SHA-256。
- Google Android Command-line Tools 12.0、Build-Tools 34.0.0、Platform-Tools 37.0.1、Platform 34 revision 3。归档与 Google 官方仓库元数据的校验值一致，SDK Manager 确认可识别三个 SDK 组件。
- Godot 4.3 官方导出模板归档中的 `android_debug.apk`，从 HTTPS 官方发行文件提取，解压长度、归档 CRC 和内部 APK ZIP 检查通过。
- 项目专属 `.tools/android/keys/pixelfarm-debug.keystore`，不会被源码打包脚本包含；后续更新必须保留并复用。

实际导出发现并修复：未启用 Gradle 时不能覆盖 `gradle_build/min_sdk` / `target_sdk`，现已留空并以最终清单验证版本；Android 导出要求开启 `rendering/textures/vram_compression/import_etc2_astc`，现已配置。对应失败日志保留在 `android-export-sdk-override-error.log` 与 `android-export-texture-config-error.log`，最新构建已通过。

当前工作区执行 `python3 tools/build_android.py` 可重新导出和校验。脚本不下载或安装工具、不自动部署手机；新构建机需先准备依赖。手机安装步骤、Windows 构建方法与真机验收项目见 [Android 说明](ANDROID.md)。
