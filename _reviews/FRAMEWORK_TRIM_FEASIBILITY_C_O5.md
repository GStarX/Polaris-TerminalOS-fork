# framework 裁剪可行性清单（方案甲 v1）

- 状态：v1（不依赖构建机部分；实施必须等 ≥350GB runner）
- 产出人：方案甲（C_O5）
- 归档：本地 `_reviews/FRAMEWORK_TRIM_FEASIBILITY_C_O5.md`，未提交、未推送，交 GITHUB 代写

## 0. 证据与前提（先讲清楚数据能支撑到什么程度）

**实测基线（首席，2026-11-01）**：`MemTotal 7.82GB`、`MemAvailable 5.90GB`、`Used RAM 1.83GB`（used pss **1.50GB** + kernel **330MB**）。

已分解的大头（PSS）：

| 组件 | PSS | 可裁剪性 |
| --- | --- | --- |
| `system_server` | 320 MB | 部分可裁（服务白名单） |
| `SystemUI` | 120 MB | 部分可裁，整体去掉是产品决策 |
| `surfaceflinger` | 72 MB | 基本不可裁（任何 UI 都要） |
| Termux | 80 MB | 不裁（项目本体） |
| TerminalHome | 17 MB | 不裁（项目本体） |
| **小计** | **609 MB** | —— |
| **未分解** | **≈890 MB** | **必须补测** |

**必须先说的一条**：剩下 ~890MB 没有分解，任何「精确节省量」都是拍脑袋。所以本清单只给**区间 + 置信度**，并把「补测」列为开工前置。

**补测命令（一条，不占构建机）**：
```
adb shell dumpsys meminfo -c > /data/local/tmp/meminfo_before.txt
adb shell dumpsys meminfo | sed -n '1,80p'
```
判据：能列出 Top-20 进程 PSS 与 kernel 分类（slab/shmem/pagecache），否则第 1 批裁剪无法定优先级。

## 1. 裁剪项清单

置信度定义：**高** = 结构占比可算；**中** = 有同类项目经验但未在本机验证；**低** = 方向性判断。

| # | 动作 | 影响面 | 预期节省（PSS） | 置信度 | 风险 | 需构建机 |
| --- | --- | --- | --- | --- | --- | --- |
| S1 | SystemUI 编译期移除锁屏/Keyguard 组件（设备已 `lockscreen disabled`） | 锁屏不可用（当前已禁用，无新增损失） | 15–25 MB | 中 | 低：可能残留引用导致编译错误 | 是 |
| S2 | 移除 QS/通知栏下拉 UI（kiosk 不需要） | 无法下拉通知面板 | 10–20 MB | 中 | 中：SystemUI 结构耦合 | 是 |
| S3 | 移除音量面板/媒体控件/多用户 UI | 音量键 UI 退化 | 5–12 MB | 低 | 中 | 是 |
| S4 | **整体不编 SystemUI**，由 TerminalHome + DshViewer 全屏接管 | 无状态栏、无通知、无 Recents UI | **100–120 MB** | 高（省的是实测值） | **高**：属产品形态变更，需注入官确认 TerminalHome 能全屏接管 | 是 |
| SS1 | `system_server` 服务白名单：去掉 Dream/Print/AdServices/Incremental/UWB/XR/Virtualization 等已无客户的 ManagerService | 对应 API 不可用 | 15–35 MB | 中 | 中：服务间依赖、CT S 兼容 | 是 |
| SS2 | 去掉 `WallpaperManagerService` / 壁纸相关（若 S4 走无 UI） | 无壁纸 | 5–10 MB | 低 | 中 | 是 |
| Z1 | 关闭 zygote 非必要 preload 类/资源 | 冷启动略慢 | 10–20 MB | 中 | 低 | 是 |
| Z2 | 去掉 32-bit ABI（`zygote32` + 32 位库） | 无 32 位应用支持 | 10–25 MB | 低 | **高**：polaris 部分 vendor HAL 可能是 32 位，需先核 blob 清单 | 是 |
| M1 | 去掉相机 HAL/相机服务（若确定不要相机） | 相机功能消失 | 20–40 MB | 中 | 中：需同时移除 `cameraserver` 与 provider | 是 |
| M2 | 去掉 NFC/UWB 服务与 HAL（若确定不用） | NFC 支付/标签不可用 | 5–12 MB | 中 | 中 | 是 |
| M3 | Stagefright/媒体解码器裁掉不用的格式 | 对应格式不可播 | 5–15 MB | 低 | 中 | 是 |
| K1 | kernel `defconfig` 去掉不用驱动（NFC/UWB/其他面板/传感器子集） | 对应硬件不可用 | 10–25 MB | 中 | 中：漏删/误删会 bootloop | 是 |
| K2 | 关闭 kernel 调试项（若开）：`DEBUG_*`、`FTRACE`、`KASAN` 等 | 无调试手段 | 5–20 MB | 中 | 低 | 是 |
| K3 | 开 zram | 不降 PSS，但提高 `MemAvailable` | 0（PSS 口径） | 高 | 低 | 否（设备层可先验） |

**不可裁**：`surfaceflinger`（72MB，任何界面都要）、Termux（80MB，项目本体）、TerminalHome（17MB，项目本体）、WebView（DshViewer 依赖，**不能删**）。

## 2. 组合测算（三种形态）

| 形态 | 组合 | 预期 Used pss | 预期 Used RAM | 与 800MB 差距 |
| --- | --- | --- | --- | --- |
| **保守裁** | S1+S2+S3 + SS1 + Z1 + K1+K2 | 1.50 → **1.30–1.38 GB** | 1.63–1.71 GB | 远 |
| **激进裁** | 保守 + M1+M2+Z2 + S4 部分 | 1.50 → **1.10–1.20 GB** | 1.43–1.53 GB | 仍远 |
| **无常规 UI 形态** | S4 全去 + SS1/SS2 + M1/M2 + Z1/Z2 | 1.50 → **0.85–0.95 GB** | ≈1.18–1.28 GB | 需把 kernel 也压下去才可能贴近 800MB |

**结论（与首席一致，不为了好看改口）**：删包已到 1.4–1.5GB 下限；framework 裁剪的现实目标是 **1.0–1.2GB**；**800MB 只有「去掉常规 UI + 极简 framework」这一种形态**才可能接近，且风险与工作量都是数量级上升。800MB 若作为硬指标，必须先由首席/用户确认产品形态（无状态栏、无通知、无 Recents）。

## 3. 判据（每项裁剪单独过）

1. **前后 PSS 对比**：`dumpsys meminfo -c` 同一进程 PSS 差值 ≥ 预期区间的下限，才算该项成立；只报「感觉变快」不算。
2. **启动与功能回归**：`boot_completed=1`、HOME=TerminalHome、锁任务 `LOCKED`、mFlags=7、T 项全过。
3. **无新增崩溃**：`logcat -b crash` 与 `dmesg` 30 分钟内无新增 fatal。
4. **可回退**：每项单独 commit，`git revert` 可回；产物与上一版可对比。
5. **一次只改一组**：S/SS/Z/M/K 各组分开构建，禁止一次打包全部改动——否则 PSS 变化归因不了。

## 4. 未闭口

1. **~890MB 未分解**：开工前必须补 `dumpsys meminfo -c`，否则 S/SS 两项无法定优先级。
2. **S4（去 SystemUI）是产品决策**：需注入官确认 TerminalHome/DshViewer 能接管全部 UI 与输入；若不能，S4 只能部分做。
3. **Z2（去 32 位）需先核 vendor blob**：`vendor/xiaomi/polaris` 的 32 位 HAL 清单，未核。
4. **构建机是硬前置**：本清单所有项都要改包编译，除 K3（zram，可设备层先验）。
5. **kernel 330MB 的构成未分解**：slab/shmem/pagecache 各占多少未知，K1/K2 的预期节省据此校正。
