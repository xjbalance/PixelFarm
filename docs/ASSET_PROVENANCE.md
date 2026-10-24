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

0.5.0矿区图集由`tools/generate_mine_assets.py`使用同一32px色板与固定种子生成，机关/矿脉/入口/灯台由`mine_map.gd`、`mine_point.gd`、`ore_node.gd`原创几何绘制。没有引入外部游戏资源或图片生成服务。05截图为实际Godot窗口渲染的进度夹具；可玩性另由碰撞/输入集成测试验证。

## 0.6.0新增原创资产

工具tools/generate_060.py沿用项目几何像素风：扩展mines.png为五区小图集，原前12图块保留；xiaojing_wedding.png沿原角色轮廓绘制原创礼服/发饰；wedding_floor.png为原创室内地板/墙图块。礼堂桌/杯/灯/1314灯点与村庄交接台由脚本像素绘制。

star_vow.wav为自合成短循环旋律，star_chimes.wav为正弦合成铃风环境音，无外部采样。角色、文本与新机关场景没有使用商业游戏素材。Noto字体与原引擎许可保留，APK校验确认许可内容完整。截图均由实际Godot窗口渲染，使用进度夹具，不能作为真人流程或手机实测证据。

## 0.6.2湖泊养殖

assets/aquaculture 下16张PNG由 tools/generate_aquaculture_assets.py 用Pillow几何逐像素原创生成，含6成鱼、6鱼苗、2帧游动图集、饲料与两种料理。六鱼具有不同轮廓与鳍尾特征，不引用商业游戏素材。岸上木台/栏网/维护箱由 aquaculture_point.gd 程序绘制，沿用现有农场色板；不增加动态光源。

## 0.7.0阶段A季节美术

assets/seasons的四套32px地表和树木纹理由tools/generate_season_assets.py在项目原创旧atlas上生成像素变化，春花、夏草、秋叶、冬雪采用独立细节。SeasonLandscape仅替换纹理并绘制稀疏装饰，不改地图格数或水域碰撞。WeatherScreen使用固定绘制预算、delta动画时钟表现九天气，无外部商业素材、动态灯或粒子实例堆叠。

## 0.7.0阶段B

assets/fishing、livestock、kitchen由各自tools/generate_*_assets.py以项目原创色板程序绘制：鱼竿/饵/钩/传说鱼、鸡牛羊/饲料产物、10食材料理图。原六鱼复用养殖素材，无同ID重复定义。生态水草/水样台、厨房设施、畜舍、休息椅由对应world脚本绘制，均不使用商业游戏素材。

## 0.7.0阶段C

节日7张纪念/装饰图由tools/generate_festival_assets.py原创像素生成；家具与室内地板等15张由tools/generate_housing_assets.py生成。人物继续使用项目原头像与角色，无商业游戏素材。节日绳框/灯会/原村民聚集叠加现有地图；侧间地板、窗户、墙体及装修图形由Housing模块绘制，保留原故事资产。

## 0.7.0阶段D

assets/exploration为三张地图原创地表atlas及6种材料/封记图标，tools/generate_exploration_assets.py程序像素绘制；森林薄雾/季节草叶、排水廊墙体/干道/水桥、神庙光轴与符台均为代码实体呈现。assets/world_progress的招牌/货物等由tools/generate_world_progress_assets.py原创生成，码头/雨棚/灯/花坛按状态绘制。无其他商业游戏素材。
