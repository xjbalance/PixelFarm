# 素材来源与许可记录

| 内容 | 来源 | 处理 |
|---|---|---|
| `assets/characters/*.png` | 本项目 `tools/generate_assets.py` 原创像素绘制 | 四向角色帧、林芽，不引用外部角色 |
| `assets/tilesets/*.png` | 同上 | 草地、土壤、道路、水面、树、石、栅栏 |
| `assets/buildings/*.png` | 同上 | 小屋与种子摊 |
| `assets/crops/crops.png` | 同上 | 三种作物各四列阶段图形 |
| `assets/ui/icon.svg`、`android_icon.png` | 本项目原创几何嫩芽图标 | 不包含外部品牌图案 |
| `assets/audio/*.wav` | generate_assets.py / polish_assets.py，Python 标准库原创合成 | 农活、收获、换日、48 秒循环主题与8秒雨声；没有商业音乐采样 |
| `assets/ui/fonts/NotoSansCJK-Regular.ttc` | 环境已有的 Noto Sans CJK（Google / Adobe 字体项目） | 保留完整原字体；随附 Debian 包完整版权与 SIL Open Font License 1.1 文本 |

字体项目：https://github.com/notofonts/noto-cjk 。本地分发许可在 [`assets/ui/fonts/LICENSE.txt`](../assets/ui/fonts/LICENSE.txt)。导出包含字体与许可文本。

重新生成像素素材需要 Python 与 Pillow：

```bash
python3 tools/generate_assets.py
```

所有生成后的 PNG / WAV 已包含在工程里。**运行和导出游戏不需要 Python 或 Pillow**。工程未使用任一参考游戏的素材，未使用星露谷原始资源。

`.tools/` 中本地下载的 Godot 便携版和虚拟显示工具只用于开发验证，未装入系统，也不包含在源码交付压缩包中。引擎及导出运行时适用其自身开源许可；0.3.0 已在 assets/credits 中附带精确 4.3-stable 版本的 Godot 官方 LICENSE.txt 与 COPYRIGHT.txt（重命名为 GODOT-LICENSE.txt / GODOT-THIRD-PARTY.txt），通过导出白名单包含到 APK。


0.3.0 的 `polish_assets.py` 继续编辑本工程已有像素体系：地表色板、周砚/阿禾、八格工具图标、原创音乐与雨声。`detail_scenery.py` 增加门窗、石基、爬藤、树叶、衣着，并生成茶屋与木作坊建筑变体。`scenery.gd`、`portrait.gd` 为原创原生像素陈设和头像绘制。故事、三位角色、信件与对白均原创；没有下载或分发参考游戏美术、音乐或剧本。

完整重绘顺序：先 `python3 tools/generate_assets.py`，再 `python3 tools/polish_assets.py`，最后 `python3 tools/detail_scenery.py`。不需要在运行游戏或导出前重绘。没有使用 AI 图片生成服务。


0.4.0新增小京：`tools/generate_xiaojing_assets.py` 以本工程16px原有色板绘制独立32×48角色；`portrait.gd` 原生几何绘制独立头像，`greenhouse.gd` 绘制温室与星灯。未调用AI图片生成服务或引入第三方角色素材。新主线、小京五段关系、12个任务结语、七份记忆、婚礼与婚后信件均为本项目原创文字。截图04来自真实Godot渲染的测试夹具，不代表新档已具备这些进度。
