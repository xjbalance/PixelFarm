# 像素世界0.4.0 Android构建记录

本次含默认点击移动、备用摇杆自由切换和模式持久化。使用项目原便携Godot4.3/JDK17/SDK34/4.3模板与原调试密钥。

- 输出：builds/PixelWorld-0.4.0-debug.apk
- 大小：66794025字节
- SHA256：0d6df21149dbabcc36f3cd63f0154436019076272db71db684fc40ba709d3700
- 包名org.pixelfarm.windbud，versionCode5，versionName0.4.0，显示名像素世界。
- minSDK21、targetSDK34、ARM64+ARMv7，Compatibility/OpenGL ES3，未新增权限。
- v1/v2/v3签名通过；证书SHA256与0.3.0一致：89455063278c15e708389a2caff957c7254ff2e88b3e19aaf23cdd755c90414b。
- ZIP CRC/对齐、实际游戏JSON/许可一致性通过。
- 最终包资源提取后在独立临时目录桌面启动180帧通过。
- 没有Android设备安装/运行、覆盖更新或性能结论。

日志位于builds/android-*-0.4.0.log；完整结果见[测试报告](VALIDATION.md)，设备步骤见[ANDROID](ANDROID.md)。
