# 0.7.1《匠心打磨》实际验证记录

UI05最终实际结果：**3794项自动化、2291项窗口检查，零失败**；[完整报告](REPORT-UI05.md)、[机器统计](TEST-UI05.json)。112个计划进程全部执行，另真实异常中断重启通过，原签名code13 APK构建及包内桌面运行检查通过。没有Android真机。

UI04历史实际结果：**3402项自动化、1899项窗口检查，零失败**；[完整报告](REPORT-UI04.md)与[机器统计](UI04-TEST.json)。原签名APK已重新构建；Android真机未验收。

后续源码精修的独立验证见[任务01](TOUCH-POLISH-01.md)、[任务02](FARMING-POLISH-02.md)和[饮食调整](FOOD-RECOVERY.md)。以下保留0.7.1初版验证记录。


基于5323ce2干净工作区，在development/0.7.1增量开发。独立原提交副本基线2964自动化、356窗口均通过；全部测试仅临时用户目录。原0.7.0完整记录见[历史记录](VALIDATION-0.7.0-final.md)。

## 最终结果

| 项目 | 实际执行结果 / 证据 |
|---|---|
| 全部自动化 | **3090项，0失败**，包含原2964和新增126；builds/check-0.7.1-acceptance.log |
| 桌面窗口 | **706项，0失败**，包含原356和新增350；builds/window-0.7.1-acceptance.log |
| 新触控/生命周期/迁移/交易 | palm_runner 28项，无头和窗口均通过 |
| 恢复事务 | recovery_071_runner 55项，涵盖椅子/零食/料理/茶/营地/补给重入、日限、失败回滚、后台/读取/午夜 |
| UI教学 | tutorial_071_runner 26项，无头与窗口均通过 |
| 新横屏全面板 | palm_ui_render 296项，1280×720、1600×720、1280×960及左右各64安全区，全部按钮尺寸/裁剪/滚动可达/防穿透及实际操作 |
| 新性能正确性 | performance_071 17项；NPC12→1静态采样，原路径/动障碍/天气/18动物行为保持 |
| 旧关卡与生命周期 | 原100层实际碰撞闭闸/开闸可达性全过，320次及新增240次地图/模式切换保持有界 |
| 独立进程 | 原全部write/restart/corrupt/backup继续通过，新增palm六步涵盖已婚/矿中途/家具储物/动物/鱼栏/恢复配额/摇杆 |
| 真实异常退出 | 半写tmp点实际SIGKILL(-9)后独立重启，已提交主档完整恢复；builds/interrupt-0.7.1.log |
| Android构建 | 原证书、包名、code12、双ABI、SDK21/34、清单/无权限/对齐/CRC/数据/许可通过；builds/build-0.7.1-final.log |
| APK包内运行 | 提取最终APK实际资源，隔离桌面Godot180帧与v22/教学/出售确认API检查通过；builds/apk-runtime-0.7.1-final.log |
| Android实体设备 | ADB无设备；安装/覆盖/触感/手机性能/系统回收均未验收 |
| 格式 | git diff --check通过 |

全套分项和统计见[TEST-0.7.1.json](TEST-0.7.1.json)。进程持久化/中断步骤不重复计入断言。窗口为Linux Xvfb/Mesa原生事件，不是Android运行。软件驱动可能出现VSync支持警告；脚本错误、FAIL及instances leaked仍由入口拒绝。

## 缺陷及夹具调整记录

- builds/palm-071-before.log：原按住移动人物丢目标、工具动画内重复执行、混合鼠标/触屏、切工具旧释放复现。新28项全通过。
- builds/recovery-0.7.1-before.log：40项中13项失败，含连带状态污染；同步库存信号可跨料理入口双吃、同日露营双恢复、补给超3。新55项全部通过。
- builds/ui071-before-repro.log：旧按钮隐藏/再显示、无Drag跳动释放、切模式滚动指针三种误触均复现；新UI26项通过。
- 整合首轮旧工具夹具50项失败：同帧清冷却连续工具导致后续场景未进入。只在runner/expansion/story三个夹具等待真实16物理帧再发下一独立动作，保留原收获/扣体力/故事断言；新增反向测试仍要求动画中拒绝重复。
- 新迁移夹具最初把规范后的整数与JSON浮点容器作严格类型比较；现对两边统一canonical后逐字段比较，仍严格验证每个原值。未改变生产迁移或资源条件。
- 无头去掉FPS上限的加速尝试发生退出ObjectDB清理警告，未忽略；撤回该尝试，最终全入口沿用原帧率与正常混音清理后全部通过。

## 可复现命令

```bash
python3 tools/check_project.py
python3 tools/check_windows.py
python3 tools/check_interrupt_071.py
python3 tools/build_android.py
python3 tools/verify_apk_runtime.py
python3 tools/package_source.py
python3 tools/verify_source_package.py
```

窗口入口先等待素材导入，防止新副本尚未注册全局脚本就启动场景；历史截图和0.7.0性能文档保留，旧性能套件新输出到builds，不覆盖已发布证据。真机清单见[ANDROID.md](ANDROID.md)。
