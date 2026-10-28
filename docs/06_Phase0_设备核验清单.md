# 06 · Phase 0 设备核验清单（首席执行，其他角色不得代操作）

> 目的：在任何刷写之前，确认设备身份、启动/恢复路径、分区与固件状态。
> 当前设备据说明书称运行基于 `IOS_ON_MIX2S` 的 iOS 16 移植系统，**不能假设 Android adb 命令可用**。
> 本清单只做"读取/确认"，**不包含任何刷写命令**。真机操作只由首席执行，结果记录在本文件末尾的表格里。

## 0. 安全前置

- [ ] 确认设备电量 > 50%。
- [ ] 确认有一台可用的 PC 与数据线（已装好本次会话可用的 platform-tools；版本与路径待记录）。
- [ ] 确认已知的**回退目标**：官方 LineageOS 22.2 polaris 安装包 + 对应 Recovery 的获取方式。
  （下载地址：<https://download.lineageos.org/devices/polaris>；本文件不保证链接长期有效，执行时核对官方页面）
- [ ] 确认用户个人数据已备份，且做过至少一次恢复验证。
- [ ] 明确本次会话只做核验，不做刷写；刷写需另开任务并由用户确认。

## 1. 设备身份与启动状态

- [ ] 记录设备外观/型号/IMEI 后四位（不记录完整 IMEI）。
- [ ] 尝试进入 Bootloader：关机后 **音量下 + 电源**，直到出现 `FASTBOOT` 字样。
  - [ ] 可进入 / 不可进入（记录屏幕现象）
  - [ ] 若可进入：`fastboot devices` 是否能看到设备（记录输出）
  - [ ] 若可进入：`fastboot getvar product`、`fastboot getvar unlocked`（只读，不刷写）
- [ ] 尝试进入 Recovery：关机后 **音量上 + 电源**，直到 MI logo 出现后松开。
  - [ ] 可进入 / 不可进入；进入的是 Lineage Recovery？TWRP？其他？记录版本画面信息。
- [ ] 记录当前系统启动现象（Logo、动画、最终界面、是否 iOS 界面）。
- [ ] 记录当前系统是否能在 PC 上被识别：`adb devices`（可能为 iOS 侧工具，**不要执行任何写入命令**）。

## 2. 固件与分区状态（只读）

若 Android adb 可用（仅当设备确实以 Android 启动）：

- [ ] `adb shell getprop ro.product.device`（期望 `polaris`）
- [ ] `adb shell getprop ro.build.version.release` / `ro.build.display.id`
- [ ] `adb shell getprop ro.boot.slot_suffix`（A/B 或单槽）
- [ ] `adb shell getprop ro.boot.verifiedbootstate` / `ro.secureboot.lockstate`
- [ ] `adb shell getprop ro.vendor.build.fingerprint`（固件来源）
- [ ] `adb shell ls -l /dev/block/by-name/`（分区名清单，只列不写）
- [ ] `adb shell cat /proc/cmdline`（启动参数，判断启动链）

若 Android adb 不可用：

- [ ] 记录不可用的具体表现（命令报错、设备无响应、被识别为其他设备）。
- [ ] 明确写出结论：**在恢复 Android 系统之前，无法确认分区与固件状态 → 不进行刷写**。

## 2.1 DTBO 分区确认（K3-01P 4.19 PoC 的 P3 前置，只读）

> 背景：4.9 采用扁平 DTB 布局；4.19 PoC 需要 `BOARD_KERNEL_SEPARATED_DTBO := true` + 独立 dtbo.img，
> 刷入前必须确认设备分区表里**存在 dtbo 分区**，否则「刷进去起不来、也刷不回去」。
>
> 静态证据（2026-10-28 GitHub 实测 `LineageOS/android_device_xiaomi_sdm845-common` @`35cf356`）：
> - `BOARD_KERNEL_SEPARATED_DTBO`、`BOARD_PREBUILT_DTBOIMAGE` 在该仓**均未设置**（两次全仓检索 0 命中）→ 4.9 不产 dtbo.img；
> - 但 `sepolicy/vendor/file_contexts` 明确映射 `/dev/block/platform/soc/1d84000.ufshc/by-name/dtbo`，
>   `releasetools.py` 的 `OTA_InstallEnd` 会向 `/dev/block/bootdevice/by-name/dtbo` 写 dtbo.img，
>   `sepolicy/vendor/fastbootd.te` 允许 fastbootd 写 `dtbo_block_device`
>   → **平台分区表里本应有 dtbo 分区**（OEM 固件使用），只是 LineageOS 4.9 不生成/不刷它；
> - 因此「`fstab.qcom` 无 dtbo 条目」**不等于**「无 dtbo 分区」：Android 不挂载 dtbo，它不是 fstab 项；
> - 仍须实测：设备当前跑 iOS 移植系统，GPT 可能被改过。**分区表只读检查由首席执行。**

- [ ] `adb shell ls -l /dev/block/by-name/ | grep -i dtbo`（或 `/dev/block/bootdevice/by-name/`）——是否出现 dtbo 节点
- [ ] `adb shell ls -l /dev/block/platform/soc/1d84000.ufshc/by-name/ | grep -i dtbo`
- [ ] `adb shell cat /proc/partitions`——记录含 dtbo 的行
- [ ] `adb shell getprop | grep -i dtbo`（如有 `ro.boot.dtbo_idx` 一并记录）
- [ ] 与 `device/xiaomi/polaris/init/fstab.qcom` 的 by-name 列表逐项对照，记录差异（fstab 不含 dtbo 属正常）

判据：

- 出现 dtbo 分区 → K3-01P 的 **P3 前置满足**（仍需 Phase 0 其余项完成，且刷写另行授权）；
- 无 dtbo 分区 → **P3 禁止执行**，K3-01P 止步 P2（编译/DTB），由首席决定后续。

## 3. 恢复路径确认（Phase 0 的关键交付）

- [ ] 写出从"当前状态"回到"官方 LineageOS 22.2 polaris 可启动状态"的**完整步骤草案**（描述性即可，
      命令由首席在确认分区/固件后再补）。
- [ ] 确认该路径所需的全部文件（ROM zip、Recovery img、可能的 fastboot 包）可获取且校验值可查。
- [ ] 确认 bootloader 解锁状态是否允许刷入第三方镜像；若未解锁，记录解锁前置条件与风险。
- [ ] 确认**不**会在本次核验中重新锁定 Bootloader。

## 4. 记录表（首席填写）

| 项 | 结果 | 证据（命令输出/照片文件名） | 时间 |
| --- | --- | --- | --- |
| 设备身份（代号/型号） | 待填 | | |
| Bootloader 可进入 | 待填 | | |
| Bootloader 解锁状态 | 待填 | | |
| Recovery 可进入 | 待填 | | |
| 当前系统（Android? iOS?） | 待填 | | |
| adb 可用性 | 待填 | | |
| 活动槽位/分区清单 | 待填 | | |
| dtbo 分区存在性（K3-01P P3 前置） | 待填（出现 / 未出现） | | |
| 固件区域/版本 | 待填 | | |
| 回退到官方 22.2 的步骤草案 | 待填 | | |
| 数据备份与恢复验证 | 待填 | | |

## 5. 结论模板

```
Phase 0 结论：<可继续 / 有阻塞>
阻塞项：
1. ...
可开始的下一个动作：<仅允许：补全恢复路径 / 准备构建机 / 基线构建>
禁止动作：在以上项目未确认前，禁止 fastboot flash / 刷入任何镜像 / 重新锁定 bootloader。
```
