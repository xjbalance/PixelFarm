# 方案 C：角色选择、菜单头像与新游戏确认

角色方案为“温暖田园 × 星辉旅人”。首次没有存档时进入主角选择；已有存档按原进度读取，不强制重新选人。男主角对应女小京，女主角对应男小京，小京仍使用同一名字、NPC身份与关系记录，没有独立性别选项。

## 选择页

两张大卡展示用户确认的男女主角纸面立绘；可以反复预选，暖金高亮与“已选择”标记始终只对应一张卡。下方小京头像随预选只读更新。确认按钮明确显示将以哪位主角开始，图片不会拦截卡片或按钮触控。

- 原生触屏和鼠标可点击角色卡、确认和返回。
- 键盘左右选择，Enter确认，Esc返回。
- 手柄十字键或左摇杆横轴选择，A确认，B返回。
- 双指、拖过卡片、混合输入和迟到确认不会重复开始游戏。
- 后台或焦点丢失只清理手势，保留预选界面；回到前台不会退出、默认确认或写入一个未选择的新档。

组件的`selected_gender`是临时状态。只有最终确认后发送`confirmed(gender)`；返回发送`cancelled`。组件本身不提交外观、不创建存档，也不重置原钱物、日期、房屋或婚姻。图片未能加载时禁用确认并显示提示，不以旧角色冒充对应外观。

## 菜单与实际提交

菜单头部小头像通过`Appearance.portrait_asset("player")`显示当前主角。对话中的小京头像和主角别名也经同一解析入口取图；其他NPC继续原显示协议。缺少图像时显示明确的空缺标记或文字，头像保持不接收触控。

菜单“新游戏 · 重新开始”先打开覆盖确认。取消回到当前菜单，旧确认token失效；确认只发送一次`new_game_requested`，随后由主场景展示角色选择。

实际新档事务由主场景`begin_character_creation()`、`confirm_character_creation()`、`cancel_character_creation()`协调：角色确认后先检查资源，重开时先保留旧档备份，再应用默认新游戏状态与新外观并沿原安全保存路径写入；失败恢复原状态并保留选择重试。等待选择期间拒绝自动保存。已有游戏取消选择返回原游戏菜单；首次无档取消会结束会话，不把默认男主写成已确认新档。

## 资源与界面边界

主角立绘使用用户原参考全身插画的独立纸面卡，已去掉角色标题、色板和旁边的像素示意，纸底原样保留。它们不是新制透明大幅立绘。世界行走使用透明像素精灵；头像、立绘卡和世界动画的来源与用途见[资源报告](SCHEME-C-ASSETS.md)。仪式图为原像素衣装配色派生，完整新礼服及独立特殊动作仍有制作缺口。

界面复用最新`FarmUIStyle`，保留羊皮纸、暖木与暖金高亮。普通680高面板中立绘约350px高，480DPI注入样本约280px高；可用空间变小时优先保留按钮触区和卡片完整性，没有缩小全局HUD或重做菜单架构。

## 实际专项验证

`tests/character_select_runner.tscn`已分别执行无头与真实Linux Godot4.3 Xvfb/Mesa窗口：**36项状态、36项窗口检查，均0失败**。最终日志为`builds/character-select-state.log`和`builds/character-select-window.log`，没有脚本错误、FAIL或实例泄漏。

覆盖十次原生预选切换、单次确认、取消与旧回调、触摸/鼠标/键盘/手柄事件、双指和拖动过滤、后台保留预选、两个菜单头像、菜单覆盖确认，以及16:9、19.5:9、20:9、4:3和480DPI注入样本。测试逐项检查保护数据和原主存档字节，组件操作没有创建或覆盖主存档。

这些是组件专项结果，不代表全部回归总数。Root事务与新旧档整体结果见[验证记录](VALIDATION.md)及[当前机器记录](TEST-SCHEME-C.json)。手柄使用注入事件，未进行实体手柄验收；没有Android真机，手机触感、DPI、覆盖安装及性能仍待验收。

## 真实窗口截图

[男主角预选](scheme-c-selection/male.png) · [女主角预选](scheme-c-selection/female.png) · [男主菜单头像](scheme-c-selection/menu_male.png) · [女主菜单头像](scheme-c-selection/menu_female.png) · [新游戏覆盖确认](scheme-c-selection/new_game_confirmation.png)

[1280×720](scheme-c-selection/layout_1280x720.png) · [19.5:9](scheme-c-selection/layout_1560x720.png) · [20:9](scheme-c-selection/layout_1600x720.png) · [平板4:3](scheme-c-selection/layout_1280x960.png) · [480DPI样本](scheme-c-selection/dpi_480.png)

共10张原始窗口帧，[清单](scheme-c-selection/screenshots.json)记录实际来源。这些图为独立组件窗口，主场景、世界移动与配对角色画面由游戏集成截图另行记录；没有重画或伪造游戏画面。

## 修改文件与接口

- `scripts/appearance/character_select_panel.gd`：`setup()`、`open_panel()`、`select_gender()`、`confirm_selection()`、`close_panel()`，以及`confirmed/cancelled`信号。
- `scripts/ui/portrait.gd`：统一外观头像解析、变化刷新与缺图显示，绘制不接收输入。
- `scripts/ui/system_panel.gd`：当前主角小头像、新游戏覆盖确认与`new_game_requested`信号。
- `tests/character_select_runner.gd/.tscn`：状态、输入、布局与真实窗口专项。

主场景、HUD、外观状态与存档事务由对应模块接入，本组件没有独立维护第二套小京进度。
