# 像素世界0.7.0实际测试记录

日期2026-10-24，Linux / Godot4.3 Standard。以真实0.6.2/v11工程为基线，原1823项实际重跑通过；开发分支`development/0.7.0`，基线3968f07及A8fff842/B0b33ab6/C5699536/D7989209保留。全部测试玩家数据位于临时XDG目录，未读写真实玩家存档。

## 最终验收

| 执行项目 | 实际结果与证据 |
|---|---|
| 完整自动入口 | `python3 -u tools/check_project.py`，退出0，ALL CHECKS PASSED；`builds/check-0.7.0-acceptance.log` |
| 总数 | **2964项检查、0失败**；22个行为/质量/性能套件，不重复计算独立进程和窗口 |
| 原回归 | sleep29、integration452、mining98、star125、legend252、stability264、river448、aquaculture155，全部通过 |
| 新套件 | seasons87、controls/recovery52、fishing84、livestock112、kitchen100、ecology65、festivals87、social107、housing105、exploration106、world-progress170、quality39、performance3、finale24，全部通过 |
| 独立进程 | 原各版本链与备份继续通过；新增季节/鱼群/钓获桶/动物/厨房/个人任务/联合节日住房/探索/贸易的写入→重启→破坏主档→备份恢复均实际执行，通过；完整入口日志有各阶段PASS |
| 实窗口 | `python3 tools/check_windows.py`，10套合计**356项、0失败**；`builds/window-0.7.0-acceptance.log`与`window-070-*.log` |
| 窗口构成 | 原百层113、湖栏32、四季48、钓鱼23、畜牧25、厨房22、生活19、隐图39、永久建设22、花/月夜13 |
| 经济 | 10,000组×28日×各独立经营模型，配方/订单价格审计通过，新增正数钻石配置0；`balance-0.7.0-final.log` |
| 生命周期 | 原320次场景/模式切换及另240次含三新图切换有界；新压力节点1044→1044，静态内存变化−13,424字节；不是Android长时内存结果 |
| 桌面计时 | 新压力切图调用P50/P95约0.71/0.89ms，导航重建约3.40/4.58ms，不含异步呈现/手机GPU；`PERFORMANCE-0.7.0.json` |
| Android | Debug导出、原证书、包名/版本/双ABI、ZIP对齐/CRC、所有JSON/许可校验通过；`build-0.7.0-final.log` |
| 最终APK资源 | 从实际APK提取资源，在隔离桌面Godot启动180帧；`apk-runtime-0.7.0-final.log`。另验证包内实际v21/花/月夜及最新媒体加载代码一致；不等于Android设备执行 |
| 源码包 | 全新目录CRC/所有JSON/版本/不含缓存密钥、空缓存等待导入及独立主场景启动；source-runtime-0.7.0-final.log |
| 设备 | ADB查询无设备；无真机/覆盖更新/手机功耗帧率验收 |
| 格式 | `git diff --check`通过 |

窗口使用Xvfb/Mesa llvmpipe与原生触屏事件；三比例1280×720/1600×720/1280×960、相机/缩放、UI拦截、多指与切模式均实测。软件驱动可能给V-Sync不支持警告，无脚本/资源错误或对象泄漏；没有把测试截图当地图实现。

## 缺陷复现与修复

- 浇水：旧3968f07隔离副本运行28项中9项失败（包括分辨率重复覆盖，非9个独立Bug），`control-recovery-before.log`；新52项全过。根因为精灵x逐帧累加、动作中输入仍移动和释放时用已移动相机换坐标。现在固定原点、短锁脚底/朝向、按下世界点捕获。
- 白天恢复：真实椅边3次/20游戏分钟/15体力、零食3份、午夜边界、旧确认重放、满体力不耗、存档/日限与不跨天均通过。原睡眠时速/20点/24点唯一结算继续通过。
- 扩建：旧任务卡挡侧间家具，屋内收起；门洞新旧保存范围缺口补齐；spouse测试夹具重置背包后缺晶石，补真实材料，未放宽成本或婚姻标准。
- 社区日程：真实31px足底和三人实际行走发现站位/反复重设路径，改合法格心及每次只提交最终站位；没有仅靠两人计数掩盖第三人卡路。
- 补齐需求：特殊月夜、原庆典可栽春铃花种，24行为+13窗口全过；合法新世界seed覆盖雪月夜反例，未改天气公式或放宽断言。种花三日、满包、移动/撤苗守恒、旧v20迁移不发历史花均验证。
- 暖舍：旧112畜牧标准未改而全部再通过；临时18只出牧/返棚3条探针也过，未加进2964计数。
- 质量：39项损坏类型/跨分区/真实v11迁移/重复load检查通过，未解锁小京不能带其个人/夏日奖励标记。

源码包首次空缓存检查发现编译阶段提前预加载媒体，已将字体/图片/音频改为原路径运行时加载，并使用--import等待完整导入；独立副本从零导入/启动零错误，完整回归与窗口再次执行。早期失败/中间日志仍保留；最终以acceptance入口和最终制品验证为准。完整入口后仅缩短两条回执、将月影正文放入滚动水样册，月夜窗口13项复测通过（window-0.7.0-moon-copy.log），发布制品再次独立启动。夹具在新季节规则下改为适种春季，保留原520计数/120株利润/材料/奖励断言，冬季另有正反验证。没有删除旧功能、降低测试要求或忽略失败。

## 可复现命令

```bash
python3 tools/check_project.py
python3 tools/check_windows.py
python3 tools/simulate_070.py
python3 tools/build_android.py
python3 tools/verify_apk_runtime.py
python3 tools/package_source.py
python3 tools/verify_source_package.py
```

完整验收边界和待真人项目见[KNOWN-ISSUES-0.7.0.md](KNOWN-ISSUES-0.7.0.md)、[ANDROID.md](ANDROID.md)。模型/短时压力/软件窗口均不能代替手机20–60分钟实际负载或真人多季通关。
