# 验证报告

日期：2026-10-22。工作目录 `/home/xiznhi/xiangqi/PixelFarm`。原工作区是棋类项目，本次只在新建 PixelFarm 子目录工作，未修改其他项目。

## 环境与执行结果

| 项目 | 实际结果 |
|---|---|
| 引擎 | 官方 Linux x86_64 Godot **4.3.stable.official.77dcf97d8**，下载到 `.tools/` 的便携版 |
| 编辑器导入 | `--headless --editor --path . --quit` 成功；无脚本解析、资源引用或场景错误 |
| 自动化集成 | **92 项断言通过，0 失败**，使用真实主场景、物理帧与 Viewport 输入 |
| 跨进程存档 | 独立进程 A 写入，进程 B 自动读取，位置/场景/金币/库存/日期/体力/农田均符合预期 |
| 主场景启动 | 无界面运行 180 帧成功，无运行时错误 |
| 源码交付包 | 解压到全新临时目录，不带 `.godot` 缓存，再次通过导入、92 项集成、跨进程读档和主场景启动检查 |
| 实际画面 | 临时 Xvfb + Mesa llvmpipe OpenGL Compatibility，成功生成 8 张实际游戏截图 |
| Android 导出 | 已尝试，因缺模板、JDK、SDK、调试签名失败；没有 APK |
| Windows / Android 真机 | 未运行，不能以 Linux 检查替代 |

`tools/check_project.py` 校验 Godot 版本、隔离测试用户目录、逐项检查退出码以及 ERROR/FAIL/资源泄漏日志。最终结果在 `builds/validation.log`，单项日志为 `import.log`、`integration.log`、`persist-write.log`、`persist-restart.log`、`main-smoke.log`。

## 分阶段验证

- 第一阶段：27 项通过。地图、键盘移动、建筑/池塘碰撞、农田边界、翻土/播种/浇水/成熟收获、体力、NPC 分页与暂停、双触点操作。
- 第二阶段：累计 47 项通过。增加三种作物成长周期、批量购买、负数/上限/金币不足/库存不足的交易拒绝、原子结算、堆叠上限和午夜换日。
- 第三阶段：累计 76 项通过。增加房门/床/出门、隐藏地图碰撞禁用、JSON 写入与恢复、非法字段拒绝、备份回退、室内存档与昼夜调色。
- 第四阶段：累计 92 项通过。增加 1280×720、1600×720、1280×960 横屏布局，模拟安全区、模态防触摸穿透、后台清理输入与重复生命周期恢复。

第一阶段之后均在已可运行的基线上迭代，没有把大量未经运行的代码留到交付时再检查。

## 运行中发现并修复

- TileSetAtlasSource 尚未加入 TileSet 时设置物理多边形会导致层越界：先挂载 source 再设置碰撞。
- 无窗口环境的屏幕坐标与画布坐标不同：测试使用 Viewport 本地触点坐标；实际交互使用逻辑画布坐标。
- Godot 鼠标模拟不足以代表多手指：按钮和摇杆分别拥有触点 index，模态或后台释放触点。
- 室内地板覆盖家具：修正 TileMapLayer 绘制层，并调整室内相机范围。
- JSON 数字类型不稳定：验证后将物品数量与生长天数归一化为整数。
- 损坏 JSON 的解析会产生引擎错误日志：改用可检查错误码的 JSON.parse，按预期恢复备份。
- Android 焦点与暂停可能连续通知：用单一后台状态保护，避免恢复后时钟永久暂停。
- 自动化高速换日留下仍在播放的音频资源：测试退出前停播并等待混音线程释放，最终无资源泄漏日志。

## 画面检查

截图均由 `tests/capture.tscn` 调用真实 Viewport 纹理输出：

- `screenshot-farm-start.png`：空地和初始状态。
- `screenshot-farm-grown.png`：测试场景布置的三种作物及多个生长阶段。
- `screenshot-shop.png`：购买、出售、库存与金币 UI。
- `screenshot-dialogue.png`：中文 NPC 对话。
- `screenshot-night.png`：夜间场景调色。
- `screenshot-home.png`：室内家具与玩家。
- `screenshot-1600x720.png`、`screenshot-1280x960.png`：长屏/平板比例。

图形日志只有虚拟显示驱动“不支持切换 V-Sync”的警告；这不代表实际 Android 的 V-Sync 状态。使用软件渲染器，因此没有将其性能报告为手机 60 FPS。

## 未验证与未完成

真实 Windows 启动、Windows EXE、APK、Android 真机多点触控/系统安全区、真实音频听感、手机 GPU 性能与功耗均未验证。模拟事件只能证明游戏侧输入逻辑，不能证明所有设备驱动表现。

树木与石头目前是景物和碰撞体，尚无采集掉落；设施升级、NPC 好感/任务/日程、天气季节、畜牧钓鱼和背景音乐属于后续内容。本次没有将这些项目计为完成。
