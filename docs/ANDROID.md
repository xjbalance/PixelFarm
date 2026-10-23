> 当前工作区开发0.7.0阶段A，尚未统一导出0.7.0。以下0.6.2 APK为上一完整交付。阶段A窗口验证见[阶段A记录](VALIDATION-0.7.0-A.md)，真机仍未连接。

# 像素世界0.6.2 Android构建与验收

已生成`builds/PixelWorld-0.6.2-debug.apk`，67,575,928字节。SHA256：`64d37655b8af1d37fca76a5b5c793fa78078e95c030990d58a60e6bf1caeaa55`。

导出、原证书、ZIP对齐/CRC、清单、双架构、全部JSON与许可验证通过。提取最终APK实际资源在隔离桌面Godot启动180帧通过。**没有连接Android设备，不代表手机运行、触感或覆盖安装通过。**

| 项目 | 保留/当前配置 |
|---|---|
| 显示名称 | 像素世界 |
| applicationId | org.pixelfarm.windbud，不变 |
| 版本 | 0.6.2 / versionCode9 |
| 引擎 | Godot4.3 Standard，Compatibility/GLES3 |
| 架构 | ARM64 + ARMv7 |
| 最低/目标SDK | 21 / 34 |
| 存档 | v11，原应用私有目录/用户目录不改 |
| 签名证书SHA256 | 89455063278c15e708389a2caff957c7254ff2e88b3e19aaf23cdd755c90414b |
| 权限 | aapt结果无uses-permission声明；不申请网络权限 |

## 构建与核验

```bash
python3 tools/check_project.py
python3 tools/simulate_aquaculture.py
python3 tools/build_android.py
python3 tools/verify_apk_runtime.py
```

构建入口使用.tools/android中的JDK17、SDK34、匹配4.3模板、原密钥与独立编辑器/XDG配置；不依赖全局SDK，不自动下载、创建或替换签名。导出写pending，全部校验通过后才替换最终APK。原`.tools/android/keys/pixelfarm-debug.keystore`必须安全保留。Windows需安装Godot4.3模板、JDK17/SDK34并使用**同一更新签名**；本轮未做Windows实机验证。

日志：`builds/build-0.6.2-final.log`、`android-{preflight,export,signature,alignment,manifest,manifest-tree}-0.6.2.log`、`apk-runtime-0.6.2-final.log`、`android-permissions-0.6.2.log`。APK资源桌面启动不是Android模拟器测试。

## 输入和性能处理

默认点击移动，设置可随时切换备用摇杆并保存。湖栏沿用原输入过滤、相机坐标转换、32px AStar网格与到达后一次交互；点击水面栏体的目标被解析为岸边锚点，湖水仍阻挡。建造工具箱使导航失效并等待物理同步，箱体位于合法交互圈外，避免生成于玩家脚下。

新增四个固定湖岸实体，六鱼共用两帧图集，最多每栏画三条示意鱼，2Hz重绘，不按真实鱼群数量创建节点、不加动态光源。模态面板、切图、模式切换与后台暂停沿用原取消路径规则。操作按钮至少48逻辑像素，面板支持原生触摸滚动；确认时锁定支付方式，关闭/加载丢弃待办。

实际桌面结果：1823项自动化、145项窗口检查零失败；320次场景/模式切换节点794→794、Godot静态内存−1272字节。以上不等于手机RSS、GPU或20分钟真实负载。

## 待执行真机清单

ADB独立端口15037查询为空。连接已授权设备后，先保留其真实存档与原APK，再执行覆盖安装测试；不要卸载旧版本来代替覆盖验证。

```bash
adb install -r builds/PixelWorld-0.6.2-debug.apk
adb shell am start -n org.pixelfarm.windbud/com.godot.game.GodotApp
adb logcat -s godot
```

以上命令为待执行步骤，本轮没有实际安装。

- 0.6.1/v10覆盖到0.6.2/v11：原金币、钻石、作物、矿洞、任务、婚姻、操作模式保持；旧档不凭空产生鱼或历史收益。已建栏保存后覆盖、主档坏损恢复备份。
- 16:9、宽屏、平板比例及刘海/系统导航条；点击水上成熟鱼、岸边木牌、±数量、取消/确认、滚动鱼谱，不穿透地图。
- 长距离到四岸、工具箱新碰撞、不可达湖心、移动NPC、水样日程、摇杆双指与模式切换，操作后没有重复扣料/鱼。
- 首轮建造→投苗→投喂→真实跨天→成熟→部分收获→出售→料理；二/三级升级保留混批鱼龄，自动饲料只耗储备。
- 湖岸、矿洞、菜单中切后台/锁屏/恢复/系统回收；20点睡眠与24点昏睡，作物/矿石/鱼群每天只结算一次。
- 低端设备连续20–60分钟运行：记录设备型号/系统、FPS、切图时间、CPU/GPU、内存、温升和电量；特别检查鱼栏面板反复打开/关闭和百层往返。
- 婚礼中断恢复、1314只扣一次、婚后520日及原主线继续可用。

无真机或Android模拟器验收记录。请将上述项目标记待验收，不用APK成功替代它们。
