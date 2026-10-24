# 像素世界0.7.0 Android构建与待真机验收

已生成`builds/PixelWorld-0.7.0-debug.apk`，**67,960,718字节**。SHA256：`b0d6e07ca7efdeb1889ab7bce071de6115902e51bb6706ea47f19c54231a4d17`。

导出、原证书、清单/双ABI、ZIP对齐/CRC、所有数据JSON与许可验证通过。提取最终APK实际资源在隔离桌面Godot启动180帧，不是Android设备运行。ADB没有连接设备，本轮未安装/未覆盖更新。

| 项目 | 当前配置 |
|---|---|
| 显示名称 | 像素世界 |
| applicationId | org.pixelfarm.windbud，不变 |
| 版本 | 0.7.0 / code11 |
| 引擎 | Godot4.3 Standard / Compatibility GLES3 |
| ABI | ARM64 + ARMv7 |
| 最低/目标SDK | 21 / 34 |
| 存档 | v21，原应用私有目录/旧自定义用户目录不变 |
| 原证书SHA256 | 89455063278c15e708389a2caff957c7254ff2e88b3e19aaf23cdd755c90414b |
| 权限 | aapt无uses-permission声明；不申请网络权限 |

## 构建

```bash
python3 tools/check_project.py
python3 tools/check_windows.py
python3 tools/simulate_070.py
python3 tools/build_android.py
python3 tools/verify_apk_runtime.py
```

Linux入口使用.tools/android中本地JDK17、SDK34、4.3模板与**原更新keystore**，隔离编辑器/XDG/ADB15037，不修改系统SDK或创建替代签名。先导出pending，全部验证通过才替换最终APK。密钥未入源码压缩包，本机原`.tools/android/keys/pixelfarm-debug.keystore`继续保留。Windows需Godot4.3模板、JDK17/SDK34与同一签名，按编辑器导出；本轮未Windows实测。

## 触控和性能策略

默认点击移动/自动交互，设置随时切摇杆并保存；切换清旧路径/触点。按下坐标捕获避免相机跟随漂移；浇水固定脚底/朝向且不累加精灵偏移。新钓点/动物/厨房/家具/节日/隐图/码头沿用原32px导航与合法近距/视线规则，UI原生触点≥48逻辑像素、长文滚动、多指过滤。

天气固定绘制预算，室内/后台/模态无过渡时停止无效重绘；无大规模动态粒子。鱼群只画少数示意鱼，动物最多18实体，家具40件上限，地图只处理当前可见区域；家具几何仅尺寸/实体属性改变时重建。单无阴影玩家灯沿用原矿区，社区灯光批量绘制；NPC最终站点一次提交，避免反复全网格规划。

桌面2964检查、356窗口检查通过；新增240切换节点1044→1044，静态内存−13,424字节。这些不是手机FPS/RSS/GPU/功耗数据。

## 真机待验收

连接授权设备后先备份真实存档与原APK，再覆盖安装。不要卸载旧包来冒充覆盖更新。

```bash
adb install -r builds/PixelWorld-0.7.0-debug.apk
adb shell am start -n org.pixelfarm.windbud/com.godot.game.GodotApp
adb logcat -s godot
```

以上命令尚未实际执行。

- 0.6.2/v11→0.7.0/v21覆盖：金币/物品/作物/公共设施/矿区/520次数/三属性/钻石/婚姻/婚后日/模式不变；主档损坏回备份。
- 不同比例、刘海/导航条：点水抛竿与长按追鱼、多指/拖动/UI不穿透；水壶位置/朝向、移动NPC/动物跟随重规划、两输入模式重启恢复。
- 三舍18只、40家具、新老地图与百层切换：动障碍/机关开关/新碰撞后导航正常；屋内扩建门洞可保存、原床/出口可达。
- 实际养鱼/养畜/队列/菜/巡灯/贸易/节日完整日循环，20点睡/午夜昏睡只结算一次；三次椅子不刷作物或资源。
- 长文本、家具网格/成熟花标记、月夜观测、节日限购/取消确认/满包待领；中断婚礼仍1314只扣一次。
- 切后台/锁屏/系统回收/低电量：恢复不重复鱼获/产物/队列/奖励，未完成QTE收线，成功满包桶保留。
- 低端/常用设备20–60分钟记录型号/OS、FPS、CPU/GPU、RSS/内存、加载时间、温升和电量；桌面软件渲染不能替代。

最终报告清楚标记真机未验收；包名和证书一致只是覆盖兼容的必要配置，不是实际安装通过的证明。
