# Android APK 构建记录 · 0.3.0 共建河湾

2026-10-23，已真实导出并验证 [PixelFarm-0.3.0-debug.apk](https://github.com/xjbalance/PixelFarm/releases/download/v0.3.0/PixelFarm-0.3.0-debug.apk)。APK 内含引擎、代码、中文字体、剧情、美术、配乐和游戏数据，手机无需另装 Godot 或下载资源。

| 项目 | 实测值 |
|---|---|
| 文件 | `builds/PixelFarm-0.3.0-debug.apk` |
| 大小 | 66,717,852 字节 / 63.63 MiB |
| SHA-256 | `21c8558fd25195783c35d9f55ea465e0ccfe36a4bf2fe94b1b12c471229a537c` |
| 包名 | `org.pixelfarm.windbud` |
| 版本 | 0.3.0 / versionCode 3 |
| 最低 / 目标系统 | API 21 / API 34；手机需支持 OpenGL ES 3.0 |
| 架构 | arm64-v8a、armeabi-v7a |
| 启动 Activity | com.godot.game.GodotApp |
| 横屏 | screenOrientation=0，landscape |
| 应用权限 | 最终清单无 uses-permission |
| 签名 | RSA 2048 调试密钥；v1/v2/v3 校验通过 |

证书 SHA-256 与 0.2.0 完全一致：`89455063278c15e708389a2caff957c7254ff2e88b3e19aaf23cdd755c90414b`。包名不变，versionCode 从 2 增为 3，可用来覆盖旧版；**不要先卸载旧版**，以保留存档。实际设备覆盖安装尚未验证。

## 实际检查

- Godot4.3 调试导出成功且最终文件存在非空，先导出到 `.pending.apk`，全部核验通过后才更名为交付文件。
- apksigner 验证签名，zipalign 检查4字节对齐，ZIP 所有文件 CRC 通过。
- aapt 检查包名、版本、横屏、启动入口、SDK 与两种 ARM 架构。
- 全部 **6 份游戏 JSON**、Godot4.3 LICENSE/COPYRIGHT 和 Noto 字体许可证与源文件逐字节一致。
- 提取最终 APK 的 assets 至隔离目录，桌面 Godot4.3 无界面独立启动180帧成功，无缺失资源/脚本/运行时错误；该检查不等同 Android 平台测试。
- 240项无界面与实际窗口集成检查通过；存档跨进程恢复、旧档迁移通过，见 [验证报告](VALIDATION.md)。

完整日志在 builds：`android-preflight-0.3.0.log`、`android-export-0.3.0.log`、`android-signature-0.3.0.log`、`android-alignment-0.3.0.log`、`android-manifest-0.3.0.log`、`android-manifest-tree-0.3.0.log`、`android-apk-assets-runtime-0.3.0.log`。校验文件与 APK 同目录，后缀 `.apk.sha256`。

构建继续使用项目内既有 Godot4.3、Temurin17、Android Build-Tools34.0.0 / Platform34、官方4.3 Android调试模板和原有签名，没有安装系统软件或修改全局配置。源码包不包含 SDK、引擎、缓存和签名私钥。

当前 adb 列表无设备，**尚未进行 Android 真机或模拟器安装运行**，也未进行 Windows 实机、真实安全区、音频听感、帧率与功耗验收。安装和重新导出方法见 [Android 说明](ANDROID.md)。
