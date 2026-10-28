# 验收执行矩阵（T01–T20 可执行化）

- 来源：`acceptance/验收测试矩阵.md`（T01–T15 主矩阵 + T16–T20 扩展项），未改动原矩阵的通过标准与判定原则，本文件把每条测试**落到可执行动作、可量化判据、证据路径与当前替代验证**。
- 执行人边界：**所有需要设备的项只由首席执行**（群规与 `docs/04` §3.2）；测试官只提供命令、判据与夹具，不代填真机结果。
- 生成：测试官，2026-10-28；仓库快照：home `ccedcc4`、vendor `d4559c3`、device `a7f8017`（三个本地工作树均在 `terminalos/lineage-22.2` 分支，见 §0.3 的基线注意）。
- 配套夹具：`acceptance/static_checks.py`（无设备静态预检 + 变异自检）；证据：`acceptance/_evidence/`。

## 0. 分类、当前阻塞与执行规则

### 0.1 分类标签（本文件统一使用）

| 标签 | 含义 | 需要什么 | 现在能否执行 |
| --- | --- | --- | --- |
| **A** | 无设备可做 | 三个仓库工作树 + Python 3 | ✅ 现在可执行（静态预检 S01–S11） |
| **B** | 需要构建产物 | Linux 构建机 + `out/` 产物（不需要设备） | ❌ 阻塞：无构建机（P0-08 / R4） |
| **C** | 需要设备 | 实机 + adb/fastboot（只首席操作） | ❌ 阻塞：`adb devices` 为空（Phase 0） |
| **D** | 需要构建产物 + 设备 | 刷入自制 ROM 后实机验证 | ❌ 阻塞：B 与 C 同时未就绪 |

状态取值：`未执行` / `通过` / `失败` / `阻塞` / `不适用(基线原因)`。**A/B 类结果不能把任何 C/D 项判为"通过"**，只能降低风险（见 §2 每项的"替代验证盲区"）。

### 0.2 执行顺序（前置依赖）

```
A（现在）── 静态预检 S01–S11、变异自检
   │
P0-01..05（首席，只读核验，Phase 0）──┬──> P1-06 官方 22.2 基线刷机验证（T15 的实战演练）
P0-08（构建机）──> P1-01..05 ──> 构建产物 ──┤
                                          └──> 2A 段设备测试：T01/T02/T09/T11/T12/T16/T20
TerminalHome DO 部署（维护步骤）──> 3A 段：T03–T08、T10、T13、T17–T19
Phase 5：T14、T15
```

- **Phase 0 未完成前禁止任何刷写**（群规 + `docs/04` §2 第 1 条），因此所有 C/D 项目前一律记 `阻塞`，禁止写"应该没问题"。
- 每个 C/D 用例执行前：`adb logcat -c` 清日志、截图记 ROM 版本、状态栏计数先记基线（见 §5 污染控制）。

### 0.3 基线注意（影响判据，必须先看）

1. **22.2 与 23.2 不是同一判据**：T06/T07/T08（锁任务下拉快捷设置）依赖 `LOCK_TASK_FEATURE_QUICK_SETTINGS`，该常量/特性只存在于 **Android 16（API 36）/ lineage-23.2**；lineage-22.2 的 frameworks/base 没有该资源（`docs/08` §A.1 与 vendor overlay 注释已核验）。因此：
   - 在 **22.2** 上执行 T06–T08 → 预期 `失败/不适用`，**不得据此判 ROM 有 bug**，也不得为了让其通过而改框架；
   - T06–T08 的正式判定必须在 **23.2**（或 22.2 + 评审通过的最小补丁，见 `docs/08` 方案 C）上进行。
2. **本地工作树是 22.2 分支**，`terminalos/lineage-23.2` 远端 head（device `d124800` / vendor `9a5d532` / home `ccedcc4`）的树尚未 `repo sync` 到本机。`S08` 的"监督角色白名单"断言因此 SKIP（22.2 预期无该资源，见 §1 注）；**23.2 树同步后必须复跑 `S08`**，这是 Phase 3 工单的前置。
3. **`config_showNavigationBar=false` 的恢复风险**：MIX 2S 无实体导航键；隐藏导航条后若手势导航不可用，将没有返回/主页入口。T05 必须与"恢复手段"一起验收：先确认 `adb shell settings get secure navigation_mode`、维护入口可达、`adb` 可改 `navigation_mode`，再判定通过。
4. **Termux 启动入口**按 termux-app v0.118.3 核实（`com.termux.app.TermuxActivity`）；若预置版本不同，T01/T02/T10 的失败原因需先排除入口变化，不得直接归因于 TerminalHome。

## 1. A 类：现在就能执行的（已于 2026-10-28 执行）

### 1.1 静态预检夹具

```bash
# 全部检查（当前结果：11 项检查 / 126 条断言 / 0 失败）
python acceptance/static_checks.py --root C:\AiWork\Polaris-TerminalOS-repos
# 单跑某一项，如 PIN 安全
python acceptance/static_checks.py --root C:\AiWork\Polaris-TerminalOS-repos --check S05 --verbose
# 变异自检：注入 11 个真实缺陷，要求全部由 PASS 变 FAIL（当前 11/11 检出）
python acceptance/static_checks.py --root C:\AiWork\Polaris-TerminalOS-repos --mutation-test
# 存证：--log 由脚本写 UTF-8（不要用 PowerShell 重定向，会写成 UTF-16）
python acceptance/static_checks.py --root C:\AiWork\Polaris-TerminalOS-repos --verbose \
  --log acceptance/_evidence/2026-10-28_static_checks_baseline.txt
```

| 检查 | 覆盖用例 | 断言内容 | 替代验证盲区（不能证明什么） |
| --- | --- | --- | --- |
| S01 | T01/T02/T03/T13 | HOME 过滤（MAIN+HOME+DEFAULT）、`singleTask`、`excludeFromRecents`；维护页 `exported=false`；AdminReceiver/BIND_DEVICE_ADMIN/device_admin 元数据；BootReceiver 仅 `RECEIVE_BOOT_COMPLETED`、无 `INTERNET`；`<queries>` 含 termux | 不能证明 aapt2 编译通过与系统解析结果，需构建产物 + 实机 |
| S02 | T10 | 常量 = 10 min / 5 次 / 4 s 冷静期 / 8 s 快速返回 / 7 击 / 1.5 s 点击窗 | 常量对但逻辑可错（S03/S04 补），运行时行为仍需实机 |
| S03 | T10 | 窗口上限判定、windowExhausted、冷静期、时钟回拨、失败持久化、重启重置、手动重试保留冷静期、窗口裁剪、lockedOut 一致 | 文本结构证明；时钟边界与 SharedPreferences 行为需 Robolectric/实机 |
| S04 | T10 | `onResume` 调用判定、8 s 阈值比较、**else 分支真实调用** `recordLaunchFailed`、启动成功记录起点、启动前必须过限流 | 不能证明 onResume 时序与 Termux 崩溃路径，需实机 force-stop 演练 |
| S05 | T13 | PBKDF2WithHmacSHA256、16 B salt、120000 次、`MessageDigest.isEqual`、4–12 位数字、无明文 `putString`、派生值清零、`commit()` 落盘、NOT_SET 语义 | 未证明 PBKDF2 在目标 ROM 可用；需实机设置/校验/重启后校验 |
| S06 | T13/T19 | 退出锁定先要求 PIN 并先验证、PIN 回调内才执行、退出锁任务 + 进维护模式、手动重试重置窗口、改 PIN 验旧、7 击入口与超时重计 | 界面交互、PIN 对话框、锁任务下能否打开维护页需实机 |
| S07 | T03/T04/T06/T18 | 非 DO 直接返回不 `startLockTask`、`attempted=false` 不伪装、白名单含自身+Termux、三个基础特性位、QUICK_SETTINGS 反射+被拒回退、`addPersistentPreferredActivity` + HOME 过滤、非 DO 不接管 HOME | DPM 真实授权、SYSTEM_SUPERVISION 角色、反射隐藏 API 是否放行需实机 |
| S08 | T05/T06 | `config_showNavigationBar=false`、`PRODUCT_PACKAGES` 含 TerminalHome/Termux、overlay 路径、产品继承与 `PRODUCT_NAME` | overlay 是否被链接、手势提示条表现需构建产物 + 实机；23.2 白名单条需同步后复查（当前 SKIP 原因见 §0.3） |
| S09 | T02/T20 | BootReceiver 重置/清维护模式/记录时间/不启 Activity、first_boot.sh 幂等与原子标记、无 rm -rf、无 pm/am 安装、始终 exit 0、Termux presigned + 跳过 preopt、fetch 脚本 SHA256/大小双校验且与 `.sha256` 文件一致 | `first_boot.sh` 尚未接入任何开机流程；Termux 首次启动与数据幂等需实机 |
| S10 | 构建前置 | Java/manifest 的 `R.*`/`@xxx/yyy` 引用全部存在；全部 XML 语法合法 | 不能替代 Soong 编译，只抓引用级错误 |
| S11 | 构建前置 | 占位符索引连续 1..N、全为位置参数、`getString`/`String.format` 实参个数匹配 | 不能替代 lint/编译，只抓数目/位置参数错配 |

**证据**
- 基线：`acceptance/_evidence/2026-10-28_static_checks_baseline.txt`（11 项 / 126 断言 / 0 失败）
- 变异：`acceptance/_evidence/2026-10-28_static_checks_mutation.txt`（11 个变异 / 11 检出 / 0 漏检）

### 1.2 A 类剩余可做项（未做，限期到 Phase 3 前）

| ID | 动作 | 判据 |
| --- | --- | --- |
| A-01 | 23.2 树（device `d124800`/vendor `9a5d532`/home `ccedcc4`）同步后复跑 `S01–S11`，重点看 `S08` 的 `config_allowedSupervisionRolePackages` 断言 | 11 项全 PASS，且 `S08` 无 SKIP |
| A-02 | 对 23.2 树重跑 `--mutation-test`（锚点文本可能因分支差异失效，失效则更新锚点，不得删检查） | 11/11 检出 |
| A-03 | 用 `aapt2` 能解析的静态方式预检 manifest（若构建机上已有 aapt2，B 段第 1 步顺手做） | 见 §3 B-01 |

### 1.3 A 类不能替代的（说清楚，防止假通过）

- 静态检查只证明"代码文本里存在正确结构"，**不证明** Android 会按预期执行：DPM 授权、锁任务行为、快捷设置、PBKDF2 可用性、overlay 链接都是运行时事实。
- 断言对重构敏感：若 TerminalHome 重构，应同步更新断言，**禁止为了变绿删断言**；每条检查的盲区已写在脚本输出与 §1.1 表。

## 2. 主矩阵逐条执行卡（T01–T15）

> 通用证据目录：`acceptance/evidence/Txx_<UTC 时间戳>_<ROM ID>/`，至少含 `commands.txt`（原始命令与输出）、`logcat.txt`、`screencap-*.png`；失败项额外含 `reason.txt`。命名与采集见 §5。
> 通用前置：C/D 项均要求 Phase 0 完成、`adb devices` 能看到设备、已记录 ROM 版本；执行前 `adb logcat -c`。

### T01 冷启动 —— 分类 D（构建产物 + 设备）

- **前置**：P1-06 已刷入含 TerminalHome 的 ROM；`dpm set-device-owner` 已执行（DO 部署属于 Phase 3 前置，若 T01 在非 DO 下执行需在记录里注明）。
- **动作**
  1. 关机 → 开机 → 解锁（记录锁屏类型）。
  2. 30 秒内不触碰屏幕，观察最终界面。
  3. `adb shell dumpsys activity activities | grep -i -E "topResumedActivity|mResumedActivity"`
  4. `adb shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME`
  5. `adb logcat -d -s TerminalHome.MainActivity TerminalHome.TermuxLauncher`（看是否走了自动启动）
- **判据（通过）**：30 s 内 `mResumedActivity` 为 `com.termux/.app.TermuxActivity` 或 `org.terminalos.terminalhome/.MainActivity`（Termux 已在前台），**且**全程截图中不出现 `Launcher3QuickStep` 桌面；logcat 有 `MainActivity onResume` + "已发出 Termux 启动请求"。
- **判据（失败）**：落到 Launcher3 桌面；或 TerminalHome 崩溃（logcat 有 `FATAL EXCEPTION`）；或 30 s 内停在 TerminalHome 且无 Termux 启动记录。
- **反例校验（防假通过）**：仅"屏幕看起来是黑的/终端样式"不算——必须确认前台组件名。若 Termux 未预置，应先判 `失败：预置缺失`，不能算 T01 通过。
- **替代验证（A 类）**：S01 组件声明、S09 Termux 预置声明。**盲区**：系统是否真的把 TerminalHome 当 HOME 候选、开机时序，只有实机能证。

### T02 重启 —— 分类 D

- **动作**：`adb reboot` → 等 90 s → `adb devices` → 解锁 → `adb shell dumpsys activity activities | grep -i topResumedActivity`；重复 2 次（覆盖冷启动 + 已解锁重启两种状态）；`adb logcat -d -s TerminalHome.BootReceiver TerminalHome.RestartLimiter TerminalHome.MainActivity`。
- **判据（通过）**：两次重启后都无需手动点 Termux 即回到终端；logcat 有 `BOOT_COMPLETED：重置限流与维护模式`、`BOOT_COMPLETED 重置：失败重启窗口已清空`。
- **判据（失败）**：重启后落桌面/黑屏；或需手动点；或 BootReceiver 崩溃。
- **相对增量断言**：重启前的失败计数（维护界面"最近 10 分钟失败重启 x/5"）必须被清零——先制造 1 次快速返回失败，再重启，复查计数为 0。只查"重启能进终端"不足以发现"BootReceiver 没跑但 HOME 仍拉起"。
- **替代验证**：S09（BootReceiver 重置/清维护模式、不启 Activity）。**盲区**：广播是否送达、directBootAware 时序、开机竞态。

### T03 Home 手势 —— 分类 C（需要 DO 部署）

- **前置**：DO 已部署；`dumpsys device_policy` 显示本应用为 Device Owner；先做**非 DO 基线对照**：未部署 DO 时按 Home 能回桌面（记录基线），再部署 DO 重复同一动作。
- **动作**
  1. `adb shell input keyevent KEYCODE_HOME`（在 Termux 前台时按下）
  2. `adb shell dumpsys activity activities | grep -i -E "topResumedActivity|mLockTaskModeState"`
  3. `adb shell dumpsys activity activities | grep -i "LockTask"`（确认 lock task 激活）
  4. 手势返回（若导航模式为 gesture）：从屏幕左/右边缘向内滑，重复 3 次
  5. 每次动作后截图。
- **判据（通过）**：Home 后前台只可能是 TerminalHome（允许列表内 HOME），不能进入 Launcher3/其它应用；返回手势不能把 Termux 之外的应用带到前台；`mLockTaskModeState` 非 `NONE`。
- **判据（失败）**：任一动作进入普通桌面/设置/最近任务；`mLockTaskModeState=NONE` 却显示"已锁定"（伪装）。
- **反例校验**：只在"没有其它可切换应用"的情况下观察 Home 不算通过——必须确认 Launcher3QuickStep 仍存在且被抑制（`pm list packages | grep launcher` 有包，但 Home 不落到它）。
- **替代验证**：S07（DO 门禁、白名单、特性位、非 DO 不伪装）。**盲区**：DPM 真实授权与 HOME 解析。

### T04 最近任务 —— 分类 C（DO）

- **动作**：`adb shell input keyevent KEYCODE_APP_SWITCH`（187）→ 截图 → `adb shell dumpsys activity recents | head -40`；再 `adb shell am start -n com.android.settings/.Settings` 试探能否离开（应被锁任务拦截）；`adb shell input keyevent BACK` 多次。
- **判据（通过）**：最近任务界面不可用或被限制在允许列表内，无法切到非授权应用；Settings 不能进入或进入后被立即拉回。
- **判据（失败）**：能切到 Settings/Launcher/其它应用；或最近任务里出现 Termux 之外的应用并可切换。
- **替代验证**：S07（未开启 `LOCK_TASK_FEATURE_OVERVIEW`）。**盲区**：实际任务栈行为。

### T05 底部导航 —— 分类 D（overlay 需要构建产物）

- **前置**：22.2 或 23.2 构建产物中 overlay 已链接（B-02 先在构建机上验证 `config_showNavigationBar=false` 生效）；**执行前先记恢复手段**：`settings get secure navigation_mode`（2=手势，0=三键），并确认 `adb` 可改回、7 击维护入口可达。
- **动作**：`adb shell dumpsys window | grep -i -E "NavigationBar|navigationBar"`；`adb shell wm size`；截图；分别测试：三键导航是否消失、手势提示条（底部白条）是否可见、边缘滑动返回/Home 是否仍可用；`adb shell settings get secure navigation_mode`。
- **判据（通过）**：导航条不可见（或高度为 0）且**系统可用**（能返回/回 Home，不出现"无入口"）；手势提示条行为已按实际记录（可见/不可见都算记录，但必须写明）。
- **判据（失败）**：导航条仍显示；或导航条消失后手势不可用且无任何回 Home/返回手段（需要回滚 overlay）。
- **替代验证**：S08（overlay 资源）、B-02（产物里 framework-res 的 bool 值）。**盲区**：SystemUI 运行时布局、手势提示条资源名未核验（`docs/08` §3）。

### T06 顶部下拉（快捷设置） —— 分类 C/D

- **前置**：DO + 持有 `ROLE_SYSTEM_SUPERVISION`（23.2）；**22.2 上预期失败，见 §0.3**。执行前在维护界面确认"锁任务快捷设置特性"显示"已启用"。
- **动作**
  1. 在 Termux 前台 `adb shell input swipe 500 0 500 900`
  2. 截图；`adb shell dumpsys statusbar | head -60`；`adb logcat -d -s TerminalHome.Kiosk SystemUI`
  3. 分别检查：整体面板能否展开、能否二次展开（通知页/快捷页）、能否下拉到 Wi-Fi/蓝牙详情。
- **判据（通过）**：锁任务模式下快捷设置面板可展开并操作（至少亮度/Wi-Fi 入口可见）。
- **判据（失败）**：面板完全拉不下；或被 `DISABLE2_QUICK_SETTINGS` 挡住。
- **关键诊断（必须记录，决定归因）**：logcat 是否出现 `探测到 Android 16 锁任务快捷设置特性位`：
  - 出现 → 反射成功，问题在角色/系统策略；
  - 出现 `当前系统没有 LOCK_TASK_FEATURE_QUICK_SETTINGS 字段` → **隐藏 API 反射被限制或系统版本不符**，这是实现问题，不是设备问题，需换实现方案（不能记"设备不支持"结案）。
- **替代验证**：S07（反射+回退结构）、S08（23.2 白名单）。**盲区**：角色授予、系统策略、隐藏 API 可达性。

### T07 亮度 —— 分类 C/D

- **动作**：T06 面板内拖动亮度滑块；`adb shell settings get system screen_brightness`（拖前/拖后各一次）；`adb shell dumpsys power | grep -i -E "mScreenBrightness|brightness"`；截图。
- **判据（通过）**：滑块可操作，`screen_brightness` 值发生可观察变化，屏幕亮度实际改变（截图亮度或 `dumpsys` 数值）。
- **判据（失败）**：滑块灰/不可拖；或数值变但亮度不变（可能被自动亮度覆盖 → 记录是否需先关自动亮度）。
- **相对增量断言**：必须记录拖前值 A、拖后值 B，且 B≠A；只写"能拖"不算。
- **替代验证**：无（纯运行时）。**盲区**：全部。

### T08 Wi-Fi —— 分类 C/D

- **动作**：从快捷设置进入网络面板 → 连接已知 AP → `adb shell cmd wifi status`（或 `dumpsys wifi | head -40`）→ 断开 → 再连接；每次截图；`adb logcat -d -s wpa_supplicant`（可选）。
- **判据（通过）**：网络面板可进入；能完成一次连接与一次断开，系统状态与面板显示一致。
- **判据（失败）**：面板进不去（锁定策略）；只能看到开关不能进详情；连接失败（记录错误码）。
- **替代验证**：无。**盲区**：QUICK_SETTINGS 二级面板在锁定模式下的行为（`docs/08` 风险 1）。

### T09 音量 —— 分类 D

- **动作**：Termux 前台按 `adb shell input keyevent KEYCODE_VOLUME_UP` / `KEYCODE_VOLUME_DOWN`；`adb shell cmd media_session volume --stream 3 --get`（或 `dumpsys audio | grep -A3 STREAM_MUSIC`）；截图音量条。
- **判据（通过）**：音量值随按键变化，且锁任务/锁定模式不阻止音量键。
- **判据（失败）**：按键无响应；音量条出现但值不变。
- **替代验证**：无。**盲区**：全部（属实体按键路径）。

### T10 Termux 崩溃（限流） —— 分类 D（重点用例）

- **前置**：维护界面可见"最近 10 分钟失败重启 x/5"作为基线；`adb logcat -c`。
- **动作（制造快速返回）**
  ```bash
  for i in 1 2 3 4 5 6; do
    adb shell am force-stop com.termux
    sleep 1
    adb shell dumpsys activity activities | grep -i topResumedActivity
  done
  ```
  （Termux 被关后回到 HOME → `<8 s` 判为失败重启；两次自动尝试之间有 4 s 冷静期，属预期。）
- **观察**：`adb logcat -d -s TerminalHome.RestartLimiter TerminalHome.MainActivity`；界面计数与提示；再等 60 s 确认不再自动拉起。
- **判据（通过）**
  1. 第 5 次失败后进入"限流"提示状态，`5/5`；60 s 内 logcat **没有**新的"已发出 Termux 启动请求"；
  2. 成功停留不消耗额度：手动打开 Termux，停留 ≥10 s 后按 Home，计数保持 5/5 不变（相对增量断言：before=after）；
  3. 维护界面"重新打开 Termux"→ 计数清零、维护模式清除，且**仍受一次 4 s 冷静期约束**（不应立刻连发）。
- **判据（失败）**：一直循环拉起（无限重启）；或计数不涨；或正常停留也涨；或手动重试后立刻连发。
- **反例校验**：只观察"没崩"不算；必须主动制造 6 次快速返回。仅开一个 Termux 后等 1 min 不触发失败，不能证明限流有效。
- **替代验证**：S02/S03/S04（参数、逻辑、8 s 接线）。**盲区**：真实 onResume 时序、SharedPreferences 进程持久化、force-stop 行为。

### T11 屏幕休眠 —— 分类 D

- **动作**：Termux 前台 `adb shell input keyevent KEYCODE_SLEEP` → 等 5 s → `adb shell input keyevent KEYCODE_WAKEUP` →（无锁屏则直接）截图 + `dumpsys activity activities | grep -i topResumedActivity`；重复 3 次；`dumpsys power | grep -i wakefulness`。
- **判据（通过）**：每次唤醒都回到 Termux（或 TerminalHome 自动再拉起 Termux），不出现黑屏/桌面。
- **判据（失败）**：唤醒落桌面；黑屏不恢复；TerminalHome 反复重启。
- **替代验证**：无（休眠时序纯实机）。**盲区**：全部。

### T12 输入法 —— 分类 D

- **动作**：`adb shell ime list -s`；Termux 里点输入区域唤起 IME；`adb shell input text "echo terminal_os_ime_test"`；截图（含 IME）；检查终端关键内容是否被遮挡（能滚动/可见提示行）。
- **判据（通过）**：IME 可显示、可输入、文字出现在终端；IME 出现时不遮挡终端当前输入行（或可滚动看到）。
- **判据（失败）**：IME 无法显示；输入丢字；IME 全屏遮挡且不可滚动。
- **替代验证**：无。**盲区**：全部。

### T13 管理员维护 —— 分类 C/D（重点用例）

- **前置**：能进维护界面（标题 7 击）；`adb logcat -c -s TerminalHome.Pin TerminalHome.MaintenanceActivity`。
- **动作（完整闭环，逐条记录）**
  1. 7 击标题 → 弹出 PIN 设置（首次未设置）；
  2. 设置 PIN `1234`（合法）→ 记录 toast；再设为 `abcd`（非法）应被拒；设为 `123`（过短）应被拒；
  3. 退出维护界面 → 再 7 击 → 输错 PIN 3 次 → 应拒绝并停留；输对 → 进入；
  4. 修改 PIN：输入旧 PIN → 新 PIN；旧 PIN 错误应拒绝；
  5. 退出锁定（需 PIN）→ 记录 toast 与 `dumpsys activity activities | grep -i LockTask`；
  6. 重新进入终端模式（维护界面"重新打开 Termux"或重启）；
  7. `adb reboot` → 重启后应回到终端模式（BootReceiver 清维护模式）；
  8. 检查 `adb shell dumpsys device_policy | sed -n '/Device Owner/,+6p'`：DO 状态未被退出锁定破坏。
- **判据（通过）**：每一步行为与上述一致；PIN 不落明文（可从应用数据不可读 + S05 证明；实机侧只能验证行为）；未设置 PIN 时**不能**退出锁定。
- **判据（失败）**：PIN 可绕过；错误 PIN 被接受；退出锁定后无法回来；重启后停在维护模式；退出锁定把 DO 也清掉。
- **反例校验**：只测"输对了能进"不够——必须覆盖"未设置 PIN 时退出锁定被拒""错误 PIN 被拒""重启回终端"三条，否则维护入口的失败路径没被测到。
- **替代验证**：S05（PIN 存储/校验）、S06（门禁顺序）。**盲区**：对话框交互、锁任务下能否打开维护页。

### T14 OTA/升级 —— 分类 B + C（最小可执行版）

- **前置**：有可刷入的构建产物与 `docs/10` 升级/回滚规则；LineageOS updater 存在。
- **动作**：审查 `docs/10` 是否给出兼容性判据；在设备上制造一次"同版本 OTA 包"演练（本地 updater 或 recovery 侧载），记录 `logcat -s UpdateEngine`；升级后跑 T01/T02/T13 冒烟；记录回滚步骤并演练一次。
- **判据（通过）**：文档 + 至少一次真实演练：升级后 DO/锁定状态、Termux 数据、维护 PIN 的保持情况均有记录；回滚步骤可执行。
- **判据（失败）**：只有文档没有演练；升级后 DO 丢失或终端起不来且无恢复记录。
- **替代验证**：S09（BootReceiver 重置语义）、S05（PIN 存储格式可跨版本）。**盲区**：OTA 对 DO/持久化偏好、Termux 数据的影响。

### T15 恢复流程 —— 分类 C（只首席；Phase 0/5）

- **前置**：Phase 0 全部完成；官方 22.2 包 + 对应 recovery 已获取且记录校验值；bootloader 解锁状态已知。
- **动作**：按 `docs/06` §3 的恢复路径草案补齐命令；在**已确认分区/固件**后执行"回到官方 22.2 可启动状态"演练；记录每步命令与输出；恢复后跑基本硬件冒烟（开机、触摸、Wi-Fi、音量）。
- **判据（通过）**：能按文档从当前状态恢复到官方 22.2 可启动；每步命令可复现；恢复后设备可用。
- **判据（失败）**：任一步无法执行；恢复后不启动；需现场猜命令。
- **替代验证**：Phase 0 只读核验（分区/解锁状态/回退路径确认）。**盲区**：真实刷写与启动路径；禁止用推断代替演练。

## 3. B 类：构建产物阶段可执行（不需要设备）

在构建机上，产出 `out/target/product/polaris/` 后执行；结果决定能否进入 C/D：

| ID | 动作 | 判据 | 证据 |
| --- | --- | --- | --- |
| B-01 | `aapt2 dump badging out/.../system/app/TerminalHome/TerminalHome.apk` 与 `aapt2 dump xmltree --file AndroidManifest.xml` | 存在 HOME 类别、`MaintenanceActivity exported=false`、`AdminReceiver` 带 BIND_DEVICE_ADMIN 与 device_admin 元数据；`<queries>` 含 termux；无 INTERNET 权限 | `evidence/B01_aapt2.txt` |
| B-02 | 查 framework-res：`aapt2 dump resources out/.../system/framework/framework-res.apk \| grep -A2 config_showNavigationBar`（或反编译 overlay） | 值为 `false`（T05 前置）；23.2 树还要确认 `config_allowedSupervisionRolePackages` 含 `org.terminalos.terminalhome`（T06 前置） | `evidence/B02_overlay.txt` |
| B-03 | 校验 Termux 预置：产物里 `system/app/Termux/Termux.apk` 的 sha256 = `prebuilt/Termux.apk.sha256`；`aapt2 dump badging` 包名 `com.termux`、Main Activity 为 `com.termux.app.TermuxActivity` | 与锁定版本一致；未重签（签名摘要与官方 release 一致，记录 `apksigner verify --print-certs`） | `evidence/B03_termux.txt` |
| B-04 | 构建日志确认 `PRODUCT_PACKAGES` 生效、无 "module TerminalHome not found"；产物 sha256 + build-info 归档（`docs/05` 模板） | 构建可重复（同源码同机两次 sha 一致，若增量构建差异需说明 `out` 状态） | `evidence/B04_build.txt` |
| B-05 | 若构建机有 `apkanalyzer`：`apkanalyzer manifest permissions/print`，核对仅 `RECEIVE_BOOT_COMPLETED` | 与 S01 交叉一致 | `evidence/B05_apkanalyzer.txt` |

B 类**不能**判 T01–T20 任何一项通过；只用于"产物里确实带着正确的声明/资源/预置"。

## 4. 扩展项执行卡（T16–T20）

### T16 屏幕旋转 —— 分类 D

- **动作**：`adb shell settings put system accelerometer_rotation 1` → 横屏握住 3 s → 截图 → 转回；再 `settings put system accelerometer_rotation 0; settings put system user_rotation 1`（强制横屏）→ 截图；Termux 内输入一行文字确认可用。
- **判据**：横竖屏都能显示终端，无崩溃、无布局错位到不可用；恢复竖屏后正常。
- **失败判据**：TerminalHome/Termux 崩溃；横屏黑屏；输入区域不可用。
- **替代验证**：无。

### T17 通知面板 —— 分类 C/D

- **动作**：在 Termux 前台下拉通知面板（若与快捷设置同一手势，记录是哪个层级）；`adb shell dumpsys notification | head -40`；截图；尝试从通知点击进入 Settings（应不能离开锁定）。
- **判据**：面板行为（允许/禁止/受限）被**明确记录**，且不与锁定冲突（不能借此离开终端）。
- **失败判据**：能借通知进入设置/其它应用；或面板导致 SystemUI 崩溃。
- **替代验证**：S07（`LOCK_TASK_FEATURE_NOTIFICATIONS` 已开启、无 OVERVIEW）。**盲区**：真实面板层级与点击路径。

### T18 Device Owner 持久性 —— 分类 C/D

- **动作**：`adb shell dumpsys device_policy | sed -n '/Device Owner/,+8p'` 记录；`adb reboot`；再记录；检查锁定状态（`dumpsys activity activities | grep -i LockTask`）与维护界面"Device Owner：是"；可选：升级（T14）后再记录。
- **判据**：重启、升级后 DO 身份与锁定/白名单配置保持；状态行不显示"未启用（非 Device Owner）"。
- **失败判据**：重启后 DO 丢失；或显示 DO 但锁任务未生效（伪装）。
- **替代验证**：S07。**盲区**：系统对 DO 的持久化与升级迁移。

### T19 维护模式闭环 —— 分类 C/D

- **动作**：7 击 + PIN → 退出锁定（进维护模式）→ 维护界面"重新打开 Termux" → 回到终端流程 → 再次 7 击 + PIN → 退出 → `adb reboot` → 应自动回终端模式。
- **判据**：全程可逆；每步都有明确提示；重启能恢复终端模式；DO 不被破坏。
- **失败判据**：任何一步无法回到终端；维护模式重启后仍停在维护（BootReceiver 失效）。
- **替代验证**：S06 + S09。**盲区**：完整 UI 闭环。

### T20 首次开机初始化幂等 —— 分类 C（当前部分阻塞）

- **现状（必须先写进结论）**：`vendor/terminalos/scripts/first_boot.sh` **未被任何 init.rc/服务/广播触发**（脚本头部自述），因此"首次开机初始化"目前**没有接入系统**，Phase 2 的 P2-06 尚无实现。本用例分为两半：
  - T20a（脚本层，现在就能做）：在设备上（userdebug + `adb root`）手动演练：
    ```bash
    adb push vendor/terminalos/scripts/first_boot.sh /data/local/tmp/first_boot.sh
    adb shell sh /data/local/tmp/first_boot.sh   # 第 1 次：应创建标记并写日志
    adb shell sh /data/local/tmp/first_boot.sh   # 第 2 次：应打印 already initialized 并 exit 0
    adb shell ls -la /data/local/terminalos/      # 标记存在
    adb shell cat /data/local/terminalos/logs/first_boot.log  # 日志恰好 +1 条
    ```
    判据：第 2 次不新增日志、不产生额外副作用、exit 0；标记为 tmp+rename 原子写。
  - T20b（系统接入后）：重启设备验证自动执行且幂等，且不破坏用户数据。
- **判据（通过）**：a 与 b 都满足；b 未接入前只能记 `阻塞（未接入）`，不得记通过。
- **替代验证**：S09（脚本幂等结构与原子标记）。**盲区**：init 触发时机、SELinux、/data 加密状态。

## 5. 证据规范、污染控制与"断言是否测得出缺陷"

### 5.1 证据目录与采集

```text
acceptance/evidence/Txx_<UTC时间戳>_<ROM ID>/
  commands.txt     # 原始命令 + 输出（含 adb devices、getprop、时间）
  logcat.txt       # adb logcat -d -v threadtime（必要时按 TAG 过滤并保留原始文件）
  screencap-01.png # 关键步骤截图，文件名带步骤号
  reason.txt       # 仅失败项：复现步骤 + 预期/实际 + 归因
```

设备端证据一次性采集（首席执行，测试官提供）：

```bash
adb shell getprop ro.build.display.id
adb shell getprop ro.product.device
adb shell getprop ro.build.version.release
adb shell dumpsys device_policy | sed -n '/Device Owner/,+8p'
adb shell dumpsys activity activities | grep -i topResumedActivity
adb logcat -d -v threadtime > logcat.txt
adb exec-out screencap -p > screencap-01.png
```

### 5.2 污染控制（避免"前一个用例的计数/状态"污染下一个）

1. 每个用例开始 `adb logcat -c`，并在记录里写清用例开始时间。
2. 限流类（T10）与维护类（T13）：先记录当前失败计数/PIN 状态/维护模式作为基线，用**相对增量**判定（+1、清零、不变），不依赖"看起来对"。
3. T01/T02/T19 之前把维护模式关掉（否则自动启动被正确禁止，会误判失败）。
4. T05 之前先记录 `navigation_mode`，改了必须在记录里写回滚结果。
5. 同一 ROM 的多轮测试之间重启一次，避免"上一次已锁任务"干扰 Home 手势判定。

### 5.3 每条断言"能测出缺陷"的设计（反例清单）

| 用例 | 容易假通过的写法 | 本文件的强化断言 |
| --- | --- | --- |
| T01 | 看到终端界面就判过 | 必须核对前台组件名，且全程无 Launcher3；Termux 缺失判失败而非通过 |
| T02 | 重启后手动点开也算 | 不得手动干预；且用"制造 1 次失败→重启→计数归零"证明 BootReceiver 真跑了 |
| T03/T04 | 设备上没有其它应用可切 | 先确认 Launcher3 仍在包列表，再证明 Home/最近任务被抑制；非 DO 基线可退出 vs DO 不可退出 |
| T05 | 导航条"看不见"就过 | 必须同时证明仍能回 Home/返回（否则是"失去导航"而非"隐藏导航"） |
| T06 | 面板拉得下来就过 | 必须区分反射成功/隐藏 API 被拦（logcat 关键字），否则归因错误 |
| T07/T09 | "能拖动/能按"就过 | 记录操作前后数值（`screen_brightness` / 音量 stream 值），必须变化 |
| T08 | 面板能进就过 | 必须完成一次连接 + 一次断开 |
| T10 | 开个 Termux 没崩就过 | 主动制造 6 次快速返回；同时验证"成功停留不消耗额度"与"手动重试不连发" |
| T13 | 输对 PIN 能进就过 | 必须覆盖未设 PIN 不可退出、错误 PIN 被拒、重启回终端、DO 不被破坏 |
| T14 | 文档写了就过 | 至少一次真实升级演练 + 回滚演练 |
| T15 | 推断"应该能刷回" | 必须实际恢复演练并记录命令输出 |

### 5.4 不可测 / 不可替代声明

1. 在没有构建产物前，T01–T20 的**任何一项**都不能记为通过；A 类只降低风险。
2. `first_boot.sh` 未接入系统（T20b）属于"实现缺失"，不是测试缺失，结论应写 `阻塞（未接入）`。
3. 22.2 基线不提供锁任务快捷设置（T06–T08），在 22.2 上的失败是**基线限制**，不是回归；正式判定需 23.2 或评审通过的最小补丁。
4. 锁任务内打开系统设置/维护页是否被 `stopLockTask` 时序挡住，只有实机能测（T19 风险点）。
5. 隐藏 API 反射（`LOCK_TASK_FEATURE_QUICK_SETTINGS`）在目标 ROM 上是否放行未验证；这是 T06 的**首要未验证假设**，已写入判据与 logcat 诊断关键字。

## 6. 工单映射（给首席排期用）

| 用例 | 阶段 | 前置工单 | 阻塞原因 |
| --- | --- | --- | --- |
| T01/T02/T09/T11/T12/T16 | Phase 2 | P2-04 构建 → P2-05 实机 | 构建机 + Phase 0 |
| T10/T13/T19 | Phase 2/3 | P2-04/P2-05 + DO 部署 | 同上 |
| T03/T04/T06/T07/T08/T17/T18 | Phase 3 | P3-01..P3-04 + 23.2（T06–T08） | DO + 角色 + 构建 |
| T05 | Phase 3 | P3-02（overlay 构建） | 构建 + 恢复手段确认 |
| T14 | Phase 5 | P5-02/P5-03 | 构建 + 一次真实 OTA |
| T15 | Phase 0/5 | P0-01..05 | 设备 |
| T20 | Phase 2 | 需先接入 first_boot（P2-06 设计） | 实现缺失 |

---

**变更记录**：2026-10-28 测试官创建；把 T01–T15 主矩阵与 T16–T20 扩展项全部落到执行卡，形成 A/B/C/D 分类、命令、相对增量判据、反例清单与证据规范；配套静态预检 126 条断言全绿、11 个变异全部检出。
