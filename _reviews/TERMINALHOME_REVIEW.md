# P2-02 TerminalHome 代码审查（注入官）

- 审查日期：2026-10-28（Asia/Shanghai）
- 审查对象：`android_packages_apps_TerminalHome` @ `ccedcc4a9f6e74245dd6dcc51570a46768d579cb`（21 文件 / 9 个 Java 类）
- 审查人：注入官（注入层 · UI · 输入）
- 报告状态：**已在群内交付；未修改任何应用代码**（本轮任务是审查，不是实现）
- 判定：**有条件通过（代码级）**。5 项要求均在代码中实现，非 DO 降级诚实；但存在 **1 个 P0 可达性缺陷**，会使验收矩阵 T13/T19 必然失败、并把"锁任务设备无出口"变成现场风险。建议在 P2-04 构建前修掉 P0（补丁见 §4.1，TerminalHome 属注入官范围，可由我直接实施）。

---

## 1. 基线与取证（先说清我看的是哪份代码）

| 项 | 值 | 证据 |
|---|---|---|
| 本地路径 | `C:\AiWork\Polaris-TerminalOS-repos\android_packages_apps_TerminalHome` | `Get-ChildItem` |
| 本地分支标签 | `terminalos/lineage-22.2` | `git rev-parse --abbrev-ref HEAD` |
| 本地 HEAD | `ccedcc4a9f6e74245dd6dcc51570a46768d579cb` | `git rev-parse HEAD` |
| 远端分支 | `GStarX/android_packages_apps_TerminalHome` `terminalos/lineage-23.2` HEAD = `ccedcc4a9f6…`（与本地同一 commit，因此两棵树完全相同） | GitHub API `list_commits sha=terminalos/lineage-23.2` |
| 文件数 / Java 类 | 21 / 9 | `git ls-tree -r --name-only HEAD` 计数 |
| 本地 remote | **无**（`git remote -v` 为空）→ 本地无法 fetch，清点必须回远端取 | `git remote -v` |

> 注意（对全组）：本地三个仓库**都停在 `terminalos/lineage-22.2` 分支**（home `ccedcc4`、vendor `d4559c3`、device `a7f8017`）。home 的 `ccedcc4` 恰好也是远端 23.2 的 head，所以 TerminalHome 这套内容与交付一致；但 **vendor 本地 `d4559c3` 不是 23.2 的内容**（远端 23.2 是 `9a5d532`）。拿本地 vendor 副本评价 23.2 的 overlay 会得出错误结论。

已抽查 blob SHA（本地 == 远端，GitHub `get_file_contents` 返回的 SHA 与本地 `git rev-parse HEAD:path` 一致）：

```
ccc713113ca052daeb323fd0f6685f3b534241a2  src/…/MainActivity.java
ad064464f10f0f041ca913fe003f461cf86eb945  src/…/KioskController.java
378dc60cba323a6c968246104235a22e563e795f  src/…/RestartLimiter.java
1db9b6257bb337c57b78ea30523b324c43751f9b  AndroidManifest.xml
```

## 2. 核对结论（按首席给的 5 条要求逐条）

| # | 要求 | 结论 | 证据（文件:行） |
|---|---|---|---|
| 1 | Lock Task + DO 接管 HOME | **有实现，语义正确，未实机验证** | `KioskController.java:192-223`（`setLockTaskPackages` 白名单 = 自身 + `com.termux`）、`:230-266`（特性 `SYSTEM_INFO\|NOTIFICATIONS\|HOME`，OVERVIEW/GLOBAL_ACTIONS 刻意不开）、`:309-343`（`startLockTask`）、`:406-471`（`addPersistentPreferredActivity`，filter = MAIN+HOME+DEFAULT，后台线程） |
| 2 | 非 DO 时不伪装锁定 | **满足** | `KioskController.java:193-196`（非 DO 直接跳过，不调任何 DPM）、`:313-317`（`attempted=false` 返回"非 Device Owner，锁任务不可用"）、`:407-413`（只落 `NOT_DEVICE_OWNER`）、`:500-511`（仅 DO 才查白名单）；`MainActivity.java:388-395`（文案"锁定：未启用（非 Device Owner，已降级为不锁定）"） |
| 3 | 10 分钟 5 次 + 8 秒阈值重启限流 | **满足，但见 F-02/F-04/F-05** | `TerminalOsConfig.java:43-55`（10 min / 5 次 / 4 s 冷静期 / 8 s 阈值）、`RestartLimiter.java:110-181`（滑动窗口、持久化、只计失败）、`MainActivity.java:143-161`（8 s 判定来源） |
| 4 | PIN 维护入口 | **代码有，实际不可达（P0，见 F-01）** | `MainActivity.java:180-204`（标题 7 击）、`MaintenanceActivity.java:163-186`（PIN 门禁）、`:208-243`（退出锁定/改 PIN 均需 PIN）、`AdminPinManager.java:93-168`（PBKDF2） |
| 5 | 监督角色申请（ROLE_SYSTEM_SUPERVISION） | **应用侧满足；ROM 侧 23.2 已具备** | `MaintenanceActivity.java:275-313`（API36+DO 才显示/申请）、`:317-331`（`isRoleHeld` 复核后如实提示）、`:348-363`；常量值已对 AOSP gen-src 取证 = `android.app.role.SYSTEM_SUPERVISION`；vendor 23.2 已有 `config_allowedSupervisionRolePackages`（commit `d5f8d47`，blob `68b5028`） |

## 3. 静态一致性检查（全部通过，属"可自动化"的部分）

| 检查 | 结果 | 做法 |
|---|---|---|
| 布局 ID ↔ Java `R.id.*` | 13/13 全部存在 | 抽取 `res/layout/*.xml` 的 `android:id` 与 Java 引用求差集 |
| 字符串引用 | 71/71 全部存在（无缺失）；15 个仅布局引用 | 同上，注意 `android.R.string.ok/cancel` 属系统资源 |
| `diagnostics_format` 占位符 | `%1$…%14$` 连续完整，实参 14 个，顺序与注释一致 | `strings.xml:50` vs `MaintenanceActivity.java:385-402` |
| 权限面 | 仅 `RECEIVE_BOOT_COMPLETED`（normal）；无网络/危险权限 | `AndroidManifest.xml:16` |
| 组件暴露面 | HOME activity exported=true（必须）；`MaintenanceActivity exported=false`；`AdminReceiver` 由 `BIND_DEVICE_ADMIN` 保护；`BootReceiver` 只收 BOOT_COMPLETED 并带 action 校验（`:86-93`、`BootReceiver.java:39-43`） | manifest + 代码 |
| 包可见性 | `<queries><package android:name="com.termux"/></queries>` 存在（`:19-21`），否则 Android 11+ 探测恒为"未安装" | manifest |
| SDK 一致性 | manifest `minSdk 28 / targetSdk 35` == `Android.bp` `min_sdk_version 28 / target_sdk_version 35` | `AndroidManifest.xml:23-25`、`Android.bp:29-34` |
| PIN 密码学 | PBKDF2WithHmacSHA256 / 120000 迭代 / 256 bit / 16 B SecureRandom salt / `MessageDigest.isEqual` / char[]&byte[] 清零 / `commit()` 返回值检查 | `AdminPinManager.java:47-50, 93-125, 132-195` |
| Termux 启动入口 | 已复核上游：`termux/termux-app` `v0.118.3` manifest 中 MAIN+LAUNCHER 在 `com.termux.app.TermuxActivity`，`.HomeActivity` 是指向它的 activity-alias（IOT_LAUNCHER）→ 显式组件 + `getLaunchIntentForPackage` 回退策略正确 | GitHub raw, blob `992de637…` |

## 4. 缺陷清单

### 4.1 F-01【P0】维护入口在正常运行态**不可达**（7 击被 500 ms 自动拉起挤掉）

**现象**：`MainActivity.onResume()` 先 `scheduleAutoLaunchIfAllowed()`（`MainActivity.java:100-101`），后者在 500 ms 后 `attemptTermuxLaunch()`（`:257`、`TerminalOsConfig.AUTO_LAUNCH_DELAY_MS=500`）。标题的 7 连击入口（`:180-204`）**不取消已调度的启动**（`cancelScheduledLaunch()` 只在 `onPause` 调，`:105-109`）。因此从 Termux 按 Home 回到 HOME 后，约 500 ms 内就会被再次拉起 Termux；7 次点击（README §4.3：相邻间隔 ≤1.5 s，实际人类点击 ≥120 ms/次 ≈ 840 ms 起）无法在前 500 ms 内完成。

**影响**：
- 维护界面、退出锁定、PIN 管理、监督角色申请**全部走这个入口** → T13（PIN 退出锁定）、T19（维护模式闭环）必然失败；
- 唯一现实入口变成"限流锁定后出现的『进入维护界面』按钮"（需 8 s 内连按 Home 5 次，见 F-04）或"维护模式已开"；
- 更危险的是组合效应：若 Termux 崩溃循环发生在系统更新后，重启又按 F-03 清掉一切 → 锁任务设备只能靠 adb 救回，与"管理员可退出"的需求冲突。

**最小修复（建议，TerminalHome 属注入官范围，需首席确认后实施）**：

```java
// TerminalOsConfig.java —— 新增常量
/** 标题首击后，为完成 7 连击保留的自动启动抑制窗口。 */
public static final long MAINTENANCE_ENTRY_WINDOW_MS = 15_000L;

// MainActivity.java —— 新增字段
private long maintenanceEntryWindowUntilElapsed;

// setupTitleTapEntry() 的 onClick 开头（第一次点击即生效）
cancelScheduledLaunch();
maintenanceEntryWindowUntilElapsed = SystemClock.elapsedRealtime()
        + TerminalOsConfig.MAINTENANCE_ENTRY_WINDOW_MS;

// scheduleAutoLaunchIfAllowed() 中 isFinishing 检查之后
if (SystemClock.elapsedRealtime() < maintenanceEntryWindowUntilElapsed) {
    statusDetailView.setText(getString(R.string.notice_maintenance_entry_window));
    return;
}
```

配套新增字符串资源 `notice_maintenance_entry_window`（例如"维护入口已就绪：请继续点击标题，15 秒内有效"）。

**判据（修完的验证）**：真机从 Termux 按 Home → 屏幕停在 TerminalHome；`adb shell dumpsys activity activities | grep -i termux` 15 s 内无启动；15 s 后自动进 Termux；7 击 + PIN 可完整进入维护界面。**保留原行为**：开机/回 HOME 正常流程仍是 500 ms 自动进终端。

### 4.2 F-02【P1】限流判定顺序错：冷静期先于"窗口耗尽"

`RestartLimiter.beginAutomaticAttempt()` 先查 4 s 冷静期（`:115-129`），再查失败预算（`:131-143`）。若预算已耗尽且刚好处于冷静期，返回 `windowExhausted=false`，`MainActivity` 据此走"冷静期 → 再排一次延迟重试"（`MainActivity.java:291-296`），界面短暂显示"冷静期"而不是"已限流"，验收按 logcat 判定时会看到两条互相矛盾的原因。

**修复**：把 `failures.size() >= MAX` 的判定整体移到冷静期判定之前（trim 之后立刻判），保持"exhausted 优先"语义。

### 4.3 F-03【P1】重启恢复是 fail-open：崩溃循环重启后回到循环

`BootReceiver.onReceive()` 无条件 `resetForBoot()` + `setMaintenanceMode(false)`（`BootReceiver.java:44-55`）。若上一会话恰好以"限流锁定"结束（典型崩溃循环），重启 = 清空失败预算 + 回终端模式 → 循环重来；叠加 F-01（出口不可达），设备可能无法自愈。

**建议（语义决策，需首席/方案定，不由我单方面改）**：`resetForBoot()` 前先看 `RestartLimiter.getStatus()`，若上一会话 `lockedOut == true`，则**不清**失败窗口、并置维护模式（fail-safe），界面如实显示"上次会话以限流结束"。

### 4.4 F-04【P1】8 s 阈值把"用户主动按 Home"计为失败重启

`MainActivity.evaluateTermuxReturnIfNeeded()`（`:143-161`）只看时长：Termux 前台 <8 s 就返回 HOME 即记一次失败。用户为看状态而按 Home 属于正常操作，却会消耗 5 次预算（10 min 内 5 次 → 限流）。这与"只统计失败重启"的表述冲突；但 8 s 阈值是需求给定，不能单方面改。

**当前处理**：保留 8 s，但（a）在验收矩阵 T10 的制造方法里**明确用"Termux 立即退出/崩溃"制造失败，禁止用 Home 键**（否则计数来源不纯）；(b) 阈值是否下调（如 2–3 s，崩溃循环仍可捕获）由方案/首席决策。本条列入"已知误伤"，README §8.4 已有部分说明，但未说明"会误伤正常用户操作"。

### 4.5 F-05【P2】限流基于墙钟，可被时钟调整绕过 / 可被回拨拉长

`RestartLimiter` 用 `System.currentTimeMillis()`（`:111, 153, 168, 202`）。失败窗口按时间戳裁剪（`:273-278`）：设备时间**前跳** ≥10 min 会一次性清空窗口（限流被绕过）；时间**后跳**会让 `windowRemainingMs` 变成远超 10 min 的锁定（`:133-137`），只有冷静期那条路径处理了回拨（`:117-120`）。

**建议（低成本）**：改用 `SystemClock.elapsedRealtime()` + 持久化 `Settings.Global.BOOT_COUNT`（读该值不需要权限）判重启；或至少在 `now < oldestFailure` 时清窗口并记日志。此项与 F-03 一起改更省事。

### 4.6 F-06【P2】`isLockTaskActive()` 把"用户屏幕固定（PINNED）"也算作锁任务激活

`KioskController.java:374-391` 用 `getLockTaskModeState() != LOCK_TASK_MODE_NONE`，包含 `LOCK_TASK_MODE_PINNED`。DO 分支下用户自己开屏幕固定会被显示成"锁任务模式已激活"（映射在 `MainActivity.java:391-394`）——不是伪装锁定（非 DO 分支优先显示"未启用"），但属于把状态说大了。建议区分 `LOCK_TASK_MODE_LOCKED`，或在文案里区分"（用户屏幕固定）"。

### 4.7 F-07【P2】"隐藏入口"被常显文案公开

`res/layout/activity_main.xml:88-96` 常显 `hint_entry`："维护入口：连续快速点击标题 7 次（需要维护 PIN）"，与 README §4.3"隐藏维护入口"的表述矛盾。有 PIN 兜底，不算安全漏洞；但 F-01 修好后等于把出口告诉使用者，与 kiosk 目标冲突。建议：仅在阻塞态（维护模式 / 限流 / Termux 缺失，此时"进入维护界面"按钮已在）显示提示，平时删除该 TextView 的文案（保留视图也可以）。

### 4.8 F-08【P2】`Android.bp` 两个属性需构建机确认（交 P2-04 / 主机官）

- `Android.bp:13` 写了 `manifest: "AndroidManifest.xml"`。**本机无 `build/soong` 源码、GitHub 代码搜索取证失败（限流/无命中）**，我无法断定该属性对 `android_app` 合法；若非法，Soong 会直接 `unknown property "manifest"` 失败。该文件默认就取模块目录的 `AndroidManifest.xml`，**建议直接删掉这一行**（合法则等价，非法则修好）。
- `platform_apis: true` 与 `target_sdk_version: "35"` 并存也建议构建机一次确认（`m TerminalHome` 单模块）。
- 已确认一致的部分：`certificate: "platform"`、`privileged: false`（与"不申请 privileged 权限"自洽）、`optimize.enabled: false`、`min_sdk_version: 28`。

### 4.9 F-09【P2】DO 部署时序约束没进验收步骤

DO 只能"无账号、无多用户、setup 前"设置（`adb shell dpm set-device-owner org.terminalos.terminalhome/.AdminReceiver`）。若先跑完 setup/登录账号再设 DO 会失败；而失败后非 DO 状态下无锁定，叠加 F-01 又无维护出口。**建议**：T18/T19 前置步骤写成固定顺序"擦除数据 → 首启不登录 → 设 DO → 进维护界面设 PIN → 再登录账号"，并在 `docs/06` 记录 `dpm` 输出。

### 4.10 F-10【P3】文档精度：`ROLE_SYSTEM_SUPERVISION` 不是"Android 16 才有"的常量

已取证：`android-34/35/36` 的 `RoleManager.java` 均含 `ROLE_SYSTEM_SUPERVISION = "android.app.role.SYSTEM_SUPERVISION"`（`@SystemApi`，API 34 起）。应用把按钮/诊断 gate 在 API 36 对 `QUICK_SETTINGS` 是合理的，但 README §5.4 与 `MaintenanceActivity.java:61-64` 注释说"Android 16 中标注为 @SystemApi"不准确；诊断文案"不适用（系统低于 Android 16）"会把 API 34/35 的角色状态说成"不适用"。属文案问题，建议顺手改。

### 4.11 F-11【P3】`exitLockTask()` 在"当前不在锁任务"时直接返回 true

`KioskController.java:356-363`：不在锁任务时 `return true`（不调用 `stopLockTask`）。`performExitLock()` 据此提示"已退出锁定"。若锁任务实际由**另一个 task** 持有（见 F-12），提示会偏乐观。实机 T13 时同时看 `dumpsys activity activities | grep -i locktask` 再下结论。

### 4.12 F-12【P2】Termux 用 `FLAG_ACTIVITY_NEW_TASK` 启动，锁任务是否延续是最大未验证风险

`TerminalLauncher.java:156-180` 对显式/回退 Intent 都加了 `FLAG_ACTIVITY_NEW_TASK`。README §8.3 已把它列为关键风险。**建议**：实机第一步就抓 `logcat -b system | grep -E 'LockTaskController|ActivityTaskManager'`；若 Termux 落到独立 task 且 lock task 未延续，最小改法是 HOME 场景去掉 `NEW_TASK`（Activity 已在前台），保留 `RESET_TASK_IF_NEEDED`。这条同时决定 T03/T04 能否通过。

### 4.13 F-13【P2】预置 Termux APK 的包名假设（跨仓，交主机官/首席取证）

`fetch-termux.sh` 锁定的是 `termux-app_v0.118.3+github-debug_arm64-v8a.apk`（SHA256 `72fdb596…`，35,106,607 B）。TerminalHome 把 `com.termux` 硬编码在三处（`TerminalOsConfig.TERMUX_PACKAGE`、manifest `<queries>`、锁任务白名单）。若该 debug 变体的 applicationId 带后缀（如 `com.termux.debug`），会出现：探测恒"未安装"、`<queries>` 无效、锁任务白名单漏项——**静默失败**，且 T01/T02 全废。

**取证（需 35 MB APK，本机未下载，禁止我造数据）**：构建机上 `aapt2 dump badging prebuilt/Termux.apk | head -1`（或 `unzip -p prebuilt/Termux.apk AndroidManifest.xml` 后 aapt2 解码）确认 `package: name='com.termux'`。建议在 `fetch-termux.sh` 校验里加一条包名断言（可选，需改 vendor 仓，不是我的写入范围，仅提议）。

## 5. 跨仓集成核对

| 项 | 结论 | 证据 |
|---|---|---|
| local manifest 映射 | 正确：`packages/apps/TerminalHome` | `Polaris-TerminalOS/local_manifests/terminalos.xml:35-36` |
| 产品集成 | 正确：模块名 `TerminalHome` 与 `Android.bp` `name` 一致 | `vendor/terminalos/terminalos.mk` `PRODUCT_PACKAGES += TerminalHome` |
| 监督角色 overlay（D-11） | **23.2 已有**：`config_allowedSupervisionRolePackages` = `org.terminalos.terminalhome`（`<string>` 类型正确，Settings/PermissionController 侧按 `;` 切分） | 远端 `GStarX/android_vendor_terminalos` `terminalos/lineage-23.2` commit `d5f8d47`，blob `68b5028`；本地 22.2 副本 `d4559c3` **不含**该 overlay |
| 角色资格格式风险 | **待验证**：overlay 只写裸包名（"系统应用只需包名"）。TerminalHome 是 `platform` 签名但 `privileged: false`；若 RoleController 把"非 privileged"判为非系统应用，则需要写成 `包名:签名摘要`。**判据**：构建机上读 `role-controller/…/v36r1/SupervisionRoleBehavior.java` 的 `isPackageQualified/parsePackageOrSignatureAndDigest` 逻辑，或实机 `adb shell dumpsys role | grep -i supervision` 看申请结果 | vendor overlay 注释、应用日志 |
| DPM 要求监督角色的原文 | **未取到**。我复核到：aconfig flag `enable_lock_task_feature_quick_settings`（`android.app.supervision.flags`）与 `LockTaskController` 使用 `LOCK_TASK_FEATURE_QUICK_SETTINGS=128`（GitHub 代码搜索命中 `LineageOS/android_frameworks_base`）；`DevicePolicyManagerService.setLockTaskFeatures` 的拒绝逻辑原文未取（GitHub 代码搜索 `path:services/devicepolicy` 限定失败）。**标"待补证"**，不当作已证 | 见上 |

## 6. 未能在本机验证的项（不得当作结论）

1. Soong 构建（无 AOSP 树、无 JDK、Windows 主机）——`m TerminalHome` 是唯一权威判据（覆盖 F-08）。
2. 真机行为：DO 设置、HOME 接管、锁任务对 Termux task 的延续（F-12）、QS 可下拉、PIN/限流全部分支（F-01/F-02/F-04）。
3. `ROLE_SYSTEM_SUPERVISION` 申请/授予流程与 `config_allowedSupervisionRolePackages` 的资格格式（§5）。
4. 预置 Termux APK 实际包名（F-13）。
5. Android 16 `setLockTaskFeatures` 对 QUICK_SETTINGS 的角色校验原文（§5 最后一行）。

## 7. 与验收矩阵（`acceptance/验收测试矩阵.md`）的映射

| 用例 | 与本次审查的关系 | 当前可做性 |
|---|---|---|
| T01 冷启动 / T02 重启 | 依赖 F-13（Termux 包名）与 F-12（NEW_TASK/锁任务） | 无设备不可做 |
| T10 Termux 崩溃 | 限流逻辑 F-02/F-04/F-05；"超限进入维护界面"依赖 F-01 修复后的可达性 | 无设备不可做 |
| T13 管理员维护 | **直接受 F-01 阻塞**；PIN 分支 F-09/F-11 | 无设备不可做 |
| T17 通知面板 / T06 QS | 依赖 D-11 overlay + 角色授予（§5） | 无设备不可做 |
| T18 DO 持久性 | F-09 时序约束 | 无设备不可做 |
| T19 维护模式闭环 | **F-01 + F-03 组合风险** | 无设备不可做 |

**给测试官的可执行建议（写进 EXEC_MATRIX 时直接用）**：
- T10 的失败要用"Termux 立即退出"制造（在 Termux 里 `exit` 或 `am force-stop com.termux` 后观察 HOME 回弹），**不要用 Home 键**（8 s 误伤，F-04）；
- 每步统一 `adb logcat -s TerminalHome:V`，判定关键字：`TerminalHome.MainActivity`（started/paused）、`TerminalHome.RestartLimiter`（允许/拒绝/记录失败重启）、`TerminalHome.Kiosk`（白名单/特性/拒绝）、`TerminalHome.Pin`（校验通过/不匹配）；
- T13 在 F-01 修复前标记"前置阻塞"，不要记成"未通过"。

## 8. 建议的处置顺序

1. 【现在可做，无设备无构建机】F-01 补丁（我实施，等首席确认）+ F-02 顺序修正 + F-10 文案；F-07 顺手去掉常显入口提示。
2. 【决策项，交首席/方案】F-03 fail-open 语义、F-04 阈值是否下调、F-05 时间基准迁移。
3. 【构建机】F-08 Soong 属性、F-13 Termux 包名、§5 角色资格格式；`m TerminalHome` 通过后再谈 P2-04。
4. 【真机】T13（F-01）、T10（F-02/F-04）、T03/T04+T17（F-12/§5）、T18（F-09）。

## 附录 A：可复现命令

```powershell
$p='C:\AiWork\Polaris-TerminalOS-repos\android_packages_apps_TerminalHome'
git -C $p rev-parse HEAD
git -C $p ls-tree -r --name-only HEAD | Measure-Object
git -C $p rev-parse HEAD:src/org/terminalos/terminalhome/MainActivity.java
# 资源/ID 一致性（自定义脚本，见本报告 §3）
Select-String -Path "$p\res\layout\*.xml" -Pattern 'android:id'
Select-String -Path "$p\src\org\terminalos\terminalhome\*.java" -Pattern 'R\.id\.\w+' -AllMatches
```

远端取证（GitHub API / raw）：

```
GStarX/android_packages_apps_TerminalHome  terminalos/lineage-23.2  HEAD ccedcc4a9f6e74245dd6dcc51570a46768d579cb
GStarX/android_vendor_terminalos           terminalos/lineage-23.2  HEAD 9a5d5329a396a85914fff8a13a4755ba578f88cb
  └─ d5f8d471f451fa0c40c5953aef3512978dd33fdc  "feat: allow TerminalHome to hold supervision role via static overlay"
  └─ overlay/…/values/config.xml blob 68b502810d98206b7f2147729e20da4089b38ba8
termux/termux-app v0.118.3 app/src/main/AndroidManifest.xml blob 992de637ff405080c32be805eecf2e3e0a35e3bc
```

## 附录 B：审查未改动任何文件

本报告是唯一新增文件（`_reviews/TERMINALHOME_REVIEW.md`）。TerminalHome 仓库工作树保持干净（`git status --porcelain` 为空）。F-01/F-02 补丁以上面示例形式给出，**未经首席确认不落地**。
