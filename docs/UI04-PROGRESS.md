# 全局UI视觉改版实施记录

基于背包任务03提交e51b293，保留所有玩法与schema v22，按用户授权在03结束后执行。参考文档未在工程找到；Fields of Mistria官网读取超时、Roots of Pacha Steam页SSL握手超时，日志builds/ui04-reference-fetch.json；未声称查看参考图片。按用户配色/层次规范原创实现。

## A：公共主题与代表界面

新增原创24px九宫格面板/按钮/选中/禁用/焦点/自然/星辉/危险/轨道/填充13款材质，5个16px状态图标，以及可复现生成器。资源river_palette.json与river_theme.tres，Noto Sans CJK原授权字体保留。复用Theme、StyleBoxTexture和原Control，旧box接口继续服务兼容的自绘控件。

原物品资产和人物头像不复制参考游戏。HUD、背包、对话校准纸底深色正文与标题，保持原接口与布局。实际before/after-A各8张窗口截图，4项材质/对比度测试通过，TEXT对纸底最低11.53:1，按钮字体对材质均不低于4.5:1。代表背包/触控/快捷栏窗口回归通过，后续阶段再完成其余显式浅色文字及局部布局。

证据：builds/ui04-before-manifest.json、ui04-after-A-manifest.json、ui04-theme-check.log、ui04-A-representative.log。A为部分界面验证，不等同全局最终验收。

A验收修正：旧新增工具栏视觉测试把StyleBoxFlat类型与border_color写死，换九宫格后出现运行类型错误；没有放过该错误。现改为StyleBox基类并断言选中/普通实际纹理分别为selected/button，原输入/单一选中断言保持。代表回归136+28+23项零失败，修复前日志错误不作通过。
