# Windows 64位电脑版

当前完整包已包含[农场全场DIY](REPORT-FARM-DIY.md)，使用v27存档并兼容原v1–v26。更新时请同时替换EXE与配套PCK；旧档继续位于原应用数据目录。

给 Windows 玩家发送 `builds/PixelWorld-0.8.0-Windows-x64.zip`。全部解压后双击 `PixelWorld.exe`，旁边的 `PixelWorld.pck` 是配套游戏资源，必须保留。玩家不需要安装 Godot、Python 或 .NET。

推荐 Windows 10/11 64位和支持 OpenGL 3.3 的显卡驱动。操作与当前 0.8.0 相同：点击地面行走，WASD/方向键移动，E交互，B背包，J委托，M地图，Esc菜单，F5保存，F9读取。

Windows 世界标牌同样使用随包 Noto CJK 回退字体，避免英文系统缺少中文系统字体时出现方框。此调整不改变玩法、数据或操作方式。

存档继续使用当前 Windows 用户的原应用数据目录：

`%APPDATA%\Godot\app_userdata\Pixel Farm · 风芽农场\farm_save.json`

分享 ZIP 不会分享开发机存档。新版读取原格式时沿原 v26 兼容链迁移，不更换 Windows 存档路径。安卓 APK 和源码包不需要一起发给普通玩家。

## 构建和验证

Linux 构建机使用项目内 Godot 4.3 Windows 官方 release x86_64 模板、Wine 和 rcedit；工具只放在 `.tools/windows/`，不安装到系统。模板从官方 4.3 模板发布包提取并核对 ZIP CRC、大小和 AMD64 PE 头。

```bash
python3 tools/build_windows.py
python3 tools/verify_windows_runtime.py --exe builds/PixelWorld-0.8.0-Windows-x64/PixelWorld.exe
```

导出使用 Windows Desktop release 预设，游戏资源单独打成 PCK。此前实测 Godot 4.3 内嵌 PCK 与本机 rcedit 组合会造成 `pck` 与 `.rsrc` 虚拟段重叠，版本资源无法正确读取，因此此包使用标准 EXE＋PCK 配对方案。

脚本验证 PE64 架构、固定版本 `0.8.0.0`、产品信息、PCK 头和 ZIP CRC，并在没有工程源码的临时目录中用桌面 Godot 启动实际 PCK。ZIP 附带操作说明、字体许可与原 Godot 许可。

最终 ZIP 的 CRC、EXE/PCK 哈希和版本信息均通过。实际 EXE＋PCK 复制到独立中文空格目录后，经 Wine 6.0.3 检查通过：启动、真实窗口、键盘选人、F5 保存、M 地图、正常关闭和重新启动恢复女主角／男小京、v26 与领地状态。另有 215 项原角色选择、触控及运行中切换回归通过。测试没有访问开发机玩家档案。

[角色选择](windows080/character-select.png) · [实际游戏与保存提示](windows080/farm.png) · [地图](windows080/map.png)。完整记录见 [TEST-WINDOWS-080.json](TEST-WINDOWS-080.json)。Wine 运行检查与 Windows 原生机器验收分开记录，未声称完成 Windows 真机测试。
