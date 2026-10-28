# 主机官 · 构建脚本与 local manifest 审计

- 审计对象：`GStarX/Polaris-TerminalOS` 本地仓 `C:\AiWork\Polaris-TerminalOS`
- **审计基线 `f02df16`，终检基线 `800c1a1`**：审计期间有并行提交 `800c1a1`（默认分支翻转为 `lineage-22.2`、新增 `local_manifests/terminalos-22.2.xml` 与 `baseline-22.2.xml`、新增 `.github/` CI 脚本与工作流、改 `init-sources.sh` / `fetch-vendor-deps.sh` 各一处）。
  本报告已按新基线复核受影响项：§2 两行、§3.3、F13–F15 为增量。
- 审计时间：2026-10-28（Asia/Shanghai）
- 审计人：主机官
- 方法：逐行静态审读 + git 元数据核验 + **GitHub API 实测上游事实**（非引用文档）
- 引用文档：`docs/01`（manifest 设计）、`docs/02`（构建环境与依赖）、`docs/00`（上游核验）

> 口径：本文件区分「已实测」「静态推断」「无法在本机验证」三种证据等级。没有执行过的结论一律标注。

---

## 1. 结论摘要

1. **7 个脚本没有设备写入命令**：`grep -E 'adb|fastboot|flash|dd if=|payload\.bin|edl|fastbootd' scripts/*.sh` 无命中；均 `set -euo pipefail` + `ERR` trap。安全边界与 `docs/04` 一致。
2. **新加 CI 侧同样无设备写入**：`.github/scripts/*.sh`、`.github/workflows/*.yml` 扫描无真实刷机命令；`verify-wiring.sh` / `validate.yml` 只是**主动拦截** `fastboot flash/erase/update` 模式。但 CI 脚本本身**未做深度审计**（F15，范围外）。
3. **三份 local manifest 全部指向真实存在的分支**（2026-10-28 GitHub API 实测，见 §3）：`terminalos.xml`（23.2 实验）、`terminalos-22.2.xml`（22.2 + 自有仓库）、`baseline-22.2.xml`（纯上游基线）。未写 `remote` 的项按上游默认 remote 解析到 `github.com/<org>/<repo>`，**解析正确**（§3.2）。
4. **2 个高优先缺陷**，都影响"证据可信度"而非"能否跑"：
   - F01 `build-baseline.sh --lunch-target` 实际被 `brunch polaris` 覆盖，产物记录还硬写 userdebug；
   - F02 "未修改基线"没有出处证明：基线产物清单不记录 device/kernel/vendor commit。
5. **首次真实构建最可能的失败点不在现有预检里**（F03）：`device/xiaomi/sdm845-common` 由 `breakfast` 的 roomservice 在构建期拉取，需网络。
6. **`800c1a1` 引入 2 处新问题**（F13/F14）：`init-sources.sh` 22.2 分支缺 manifest 时会静默回退到 23.2 版本 manifest；`docs/02 §10` 仍写"默认 lineage-23.2"，与代码不一致（本报告交付时已修 docs/02，见 §5）。
7. 其余为健壮性/可复现性改进（F04–F11），不阻塞上构建机。
8. **本机无法复现 `bash -n`**：Git bash 在 DSH 沙箱下启动失败（`couldn't create signal pipe, Win32 error 5`），WSL 未安装。`docs/02 §11` 的"脚本通过 bash -n 静态检查"本次**未能复验**，复验命令见 §6。

**结论：可以进入真实构建机验证阶段；但 F01/F02、F13 必须在对外拿"基线可构建"结论之前修掉。**

---

## 2. 逐脚本审查

| # | 脚本 | 关键检查点 | 结果 | 证据 |
| --- | --- | --- | --- | --- |
| 1 | `setup-build-host.sh` | apt 清单与 `docs/02 §7.2` 是否一致 | **一致**：36 项、同顺序（逐项 diff 无差异） | `scripts/setup-build-host.sh:45-82`、`docs/02:128` |
| | | ccache 50G / repo 安装 / git-lfs / Change-Id | 逻辑正确；ccache 幂等；`~/bin` 不在 PATH 只提示不改 shell 配置（有意） | `:264-276`、`:281-309`、`:314-336` |
| | | `repo` 工具下载完整性 | **缺校验**（F07）：`curl -fsSL` 后只判非空 | `:293-297` |
| | | `--dry-run` 可运行范围 | **头注释与代码矛盾**（F06）：注释称"任意机器"，实际非 Linux 直接 `die` | `:16` vs `:210-212` |
| 2 | `init-sources.sh` | 分支默认值 | **`800c1a1` 后默认 `lineage-22.2`**（原 23.2），白名单仍是 22.2/23.2 | `:40`、`:112-123` |
| | | 按分支选 manifest | 22.2 → `terminalos-22.2.xml`；23.2 → `terminalos.xml`；但缺分支 manifest 时**静默回退**到 `terminalos.xml`（F13） | `:155-176` |
| | | `--no-local-manifest` 分支（P1-02/P1-03 纯上游基线） | 正确：跳过查找/复制，并跳过 `verify_layout` 断言 | `:232-238`、`:220-223` |
| | | 幂等 | 依赖 `.repo/manifests` 当前分支名，detached 检出会重复 init（F09，低） | `:177-181`、`:253-264` |
| | | `--dry-run` | 仍要求本机已装 `repo`（F08，低） | `:229` vs `:242` |
| 3 | `sync-sources.sh` | 失败指引 | 完整：降并发/磁盘/凭据/单项目重试，明确"不要删 `.repo` 重来" | `:144-155` |
| | | 同步后版本打印 | 5 个关键项目 HEAD + branch；缺目录警告 | `:166-200` |
| | | 漏检项 | `PROJECTS` 无 `device/xiaomi/sdm845-common`（属 F03） | `:34-40` |
| 4 | `fetch-vendor-deps.sh` | 默认是否掩盖上游缺口 | **不掩盖**：无目标分支时 exit 1，并打印 a/b/c 三个需 Lead 决策的选项 | `:263-280` |
| | | 默认目标分支 | **`800c1a1` 后默认 `lineage-22.2`**（基线）；23.2 需显式 `--target-branch lineage-23.2` | `:55` |
| | | 硬编码上游事实是否成立 | **成立**：内核 `lineage-22.2` = `aa8adfe9…`，与常量一致；内核确无 `lineage-23.2`（实测） | `:52` vs GitHub 实测 |
| | | `--allow-22.2-pinned-deps` 放行条件 | 必须同时满足"manifest 已锁定 22.2"或"HEAD=22.2"，才降级警告，否则仍阻塞 | `:251-261` |
| | | 参数归属 | 该参数在**本脚本**，不在 `init-sources.sh` | §5 口径纠正 |
| 5 | `build-baseline.sh` | 构建变体 | **缺陷**（F01）：`--lunch-target` 先 `lunch`，随后 `brunch polaris` 会按设备重选 `lineage_polaris-userdebug`，覆盖所选变体；产物清单硬写 userdebug | `:167-193`、`:216` |
| | | "未修改基线"可证明性 | **缺陷**（F02）：`out/baseline-artifacts.txt` 不记任何仓库 commit；preflight 不校验设备树是否上游原样 | `:199-226`、`:147-165` |
| | | preflight 完整性 | 缺 `device/xiaomi/sdm845-common`（F03）；root/`envsetup.sh`/设备树/vendor blobs/内核检查齐全 | `:147-165` |
| | | `set +u` 处理 | 正确：envsetup/构建函数不兼容 nounset，构建段临时关闭并恢复 | `:182-193` |
| 6 | `build-terminalos.sh` | Termux sha256 强制校验 | 存在且失败即停；但只校验"APK ↔ sha 文件"，不校验 sha 文件等于锁定版本（F05） | `:166-190` |
| | | 校验时机 | 在 `lunch` 之后才校验（F11，低） | `:208-211` |
| | | 产品注册检查 | 形同虚设（F10）：grep 命中的是 `vendor/terminalos/terminalos.mk:7` 的**注释**；真实注册在 `device/xiaomi/polaris/AndroidProducts.mk:18` | `:160-162` |
| | | `brunch <完整产品名>` | 未验证行为（F04）；脚本自己已标注备选方案 | `:26-30`、`:214` |
| 7 | `collect-artifacts.sh` | 不覆盖历史 | 正确：UTC 时间戳目录 + `-1..-50` 后缀，`(( suffix <= 50 )) \|\| die` 有 `\|\|` 保护不会误触 `set -e` | `:248-257` |
| | | 证据完整性 | **优于基线脚本**：`build-info.txt` 记录 6 个仓库 HEAD（含 `.repo/manifests`）、Build ID、sha256 清单 | `:201-235` |

---

## 3. local manifest 核验

### 3.1 `terminalos.xml`（23.2 实验路线，`f02df16` 起未改）

XML 可正常解析（`[xml]` 转换通过，1 remote + 6 project）。

| project | path | revision | 实测结果 |
| --- | --- | --- | --- |
| `android_device_xiaomi_polaris`（remote=terminalos） | `device/xiaomi/polaris` | `terminalos/lineage-23.2` | 存在 = `d1248003…` |
| `android_vendor_terminalos`（remote=terminalos） | `vendor/terminalos` | `terminalos/lineage-23.2` | 存在 = `9a5d5329…` |
| `android_packages_apps_TerminalHome`（remote=terminalos） | `packages/apps/TerminalHome` | `terminalos/lineage-23.2` | 存在 = `ccedcc4a…` |
| `LineageOS/android_kernel_xiaomi_sdm845`（默认 remote） | `kernel/xiaomi/sdm845` | `lineage-22.2` | 存在 = `aa8adfe9…`；**无 23.2** |
| `TheMuppets/proprietary_vendor_xiaomi_polaris`（默认 remote） | `vendor/xiaomi/polaris` | `lineage-22.2` | 存在 = `9e970795…`；**无 23.2** |
| `TheMuppets/proprietary_vendor_xiaomi_sdm845-common`（默认 remote） | `vendor/xiaomi/sdm845-common` | `lineage-22.2` | 存在 = `b971b2cc…`；**无 23.2** |

交叉印证：`GStarX/android_device_xiaomi_polaris` 的 `lineage-23.2` 与 `lineage-22.2` **同 sha**（`1b46255c…`），即 23.2 分支没有 Android 16 适配提交 —— 与 `docs/02 §2` 一致。

### 3.2 未写 `remote` 的项解析是否正确

上游 `LineageOS/android`（默认分支）`default.xml` 实测内容：

- `<remote name="github" fetch=".." review="review.lineageos.org" />`
- `<default revision="refs/heads/lineage-24.0" remote="github" sync-c="true" sync-j="4" />`
- 项目名**带 org 前缀**，例如 `<project path="build/make" name="LineageOS/android_build" …>`

由上游自身命名方式反推：`fetch=".."` 对其 manifest URL 解析后为 `https://github.com/`，故 `name` 必须写全 `org/repo`。本仓三份 manifest 的写法与此**同构 → 解析正确**。另外上游默认 `sync-c="true"`（只拉指定 revision），要求每个 project 显式给 `revision` —— 三份 manifest 的每一项**都显式指定** ✓。

> 最终以构建机 `repo manifest -o -` 输出为准（§6 步骤 4），本机无 repo、无外网，未执行。

### 3.3 `800c1a1` 新增的两份 manifest

| 文件 | 用途 | 校验结果 |
| --- | --- | --- |
| `terminalos-22.2.xml` | 22.2 主路线：自有 3 仓库 + 内核/blobs | 3 个自有仓库 `terminalos/lineage-22.2` 实测存在（device `a7f80174…`、vendor `d4559c34…`、home `ccedcc4a…`）；kernel/blobs 22.2 存在 ✓ |
| `baseline-22.2.xml` | 纯上游基线（CI baseline job）：只补 kernel + 2 个 blobs，不叠自有代码 | 3 项与上游实测一致 ✓；**不含设备树**，设备树与 `sdm845-common` 仍由 breakfast/roomservice 拉（与 F03 同一注意点） |

两份文件头注释与实际内容一致（`terminalos-22.2.xml` 声称"内核与 blobs 本来就是 22.2、无需锁定"，实际仍显式写了 `revision="lineage-22.2"` —— 这是**更可复现**的做法，建议顺手把注释改成"显式声明以保证可复现"，属文字级 F16）。

---

## 4. 缺陷清单

严重度：**高** = 会误导结论或直接失败；**中** = 构建/可复现性风险；**低** = 健壮性/文档。

| ID | 严重度 | 问题 | 证据 | 建议 |
| --- | --- | --- | --- | --- |
| F01 | 高 | `build-baseline.sh --lunch-target` 无效：`lunch <target>` 后仍 `brunch polaris`，brunch 按设备重选 `lineage_polaris-userdebug`；产物清单硬写该变体 | `build-baseline.sh:187-193`、`:216` | 去掉该参数，或改 `lunch <target> && mka bacon`，并写实际 `TARGET_PRODUCT` |
| F02 | 高 | "未修改基线"无出处：`baseline-artifacts.txt` 不记任何仓库 commit，preflight 不校验设备树是否上游原样 → 用带 local manifest 的树跑本脚本会被当成"基线可构建"证据 | `build-baseline.sh:199-226`、`:147-165`；对比 `collect-artifacts.sh:201-235` | 产物清单加各仓库 HEAD/branch + "是否应用 local manifest"；可选 `--require-pristine-baseline` 断言 |
| F03 | 中 | preflight 漏检 `device/xiaomi/sdm845-common`。该仓库由设备树 `lineage.dependencies` 指定，仅由 `breakfast` 的 roomservice 在构建期拉取（需网络） | 设备仓 `lineage.dependencies`；`build-baseline.sh:147-165`、`build-terminalos.sh:143-164`、`sync-sources.sh:34-40` | preflight 增加该目录检查并提示"由 breakfast/roomservice 拉取，需要网络"；`docs/02 §10` 补一句 |
| F04 | 中 | `brunch terminalos_polaris`（完整产品名而非设备别名）行为未验证，brunch 内部走设备名 breakfast 大概率不识别产品名 | `build-terminalos.sh:26-30`、`:214`；设备仓 `TERMINALOS_BRANCH.md` 同写法 | 首次真实构建优先 `lunch terminalos_polaris-userdebug && mka bacon`；若坚持 brunch 先验证并记录 |
| F05 | 中 | Termux 校验链可绕过：只校验 APK ↔ `Termux.apk.sha256` 一致，不校验该 sha 等于锁定版本（硬编码在 `fetch-termux.sh:43` = `72fdb596…`）。同时替换两文件即可通过 | `build-terminalos.sh:166-190`；`vendor/terminalos/scripts/fetch-termux.sh:43` | 在 `build-terminalos.sh` 增加硬编码期望 sha，或复用 `fetch-termux.sh` 校验函数 |
| F06 | 中 | `setup-build-host.sh` 头注释称 `--dry-run` "可在任意机器上预检"，实际非 Linux 直接 `die` | `:16` vs `:210-212`（`docs/02 §7.1` 写"任意 Linux 机器"，与代码一致） | 改注释一处 |
| F07 | 中 | `repo` 工具下载无完整性校验（仅判非空） | `setup-build-host.sh:281-299` | 固定 sha256，或至少把下载版本写入构建记录 |
| F08 | 低 | `init-sources.sh --dry-run` 仍要求本机已装 `repo` | `:229` vs `:242-250` | dry-run 允许缺 repo 时只打印 |
| F09 | 低 | 幂等判定依赖 `.repo/manifests` 当前分支名，detached/`default` 检出会每次重跑 `repo init` | `:177-181`、`:253-264` | 构建机上确认一次该命令输出，必要时改判 repo 记录 |
| F10 | 低 | 产品注册检查形同虚设：hash grep 命中注释即通过，真实注册在设备树 | `build-terminalos.sh:160-162`；`vendor/terminalos/terminalos.mk:7`；`device/xiaomi/polaris/AndroidProducts.mk:18` | 改查设备树 `AndroidProducts.mk` 是否含 `terminalos_polaris.mk` |
| F11 | 低 | Termux 校验在 `lunch` 之后，缺 APK 时白跑 envsetup/roomservice | `:208-211` | 提前到 preflight |
| F12 | 通过 | 安全边界：7 个脚本无设备写入、无静默 `sudo`、构建脚本拒绝 root | grep 实测无命中；`:143-146` 等 | — |
| F13 | 中 | **`800c1a1` 新增**：`init-sources.sh` 在 22.2 分支找不到 `terminalos-22.2.xml` 时**静默回退**到 `terminalos.xml`（revision 指向 `terminalos/lineage-23.2`）→ 22.2 树上叠 23.2 版本仓库，正是 `:119-122` 警告的错误组合 | `init-sources.sh:155-176` | 分支 manifest 缺失时应 `die` 或强警告，不回退到另一分支的 manifest |
| F14 | 中 | **`800c1a1` 新增**：`docs/02 §10` 仍写"默认 `lineage-23.2` + local manifest"，与代码（默认 22.2、按分支选 manifest）不一致；`§10.1 路线 1A` 也没提新的 `baseline-22.2.xml` | `docs/02:183`、`:192`；`init-sources.sh:40`、`:155-176` | 已在本报告交付内修正（见 §5） |
| F15 | 信息 | `.github/scripts/*.sh`（3 个）+ 工作流（3 个）为 `800c1a1` 新增，**未深度审计**；仅做了设备写入扫描（通过） | `.github/` | 建议另开一次 CI 专项审计（含 secrets 使用、runner 规格、缓存与产物上传） |
| F16 | 低 | `terminalos-22.2.xml` 注释称内核/blobs "无需锁定"，实际仍显式写 revision —— 注释与内容表述不一致（内容更好） | `terminalos-22.2.xml:12`、`:34-43` | 改一句注释 |

---

## 5. 口径一致性核对

| 项 | 结论 | 证据 |
| --- | --- | --- |
| `docs/02 §7.2` apt 清单 ↔ 脚本数组 | **一致**（36 项、同顺序，逐项 diff 无差异） | `docs/02:128` vs `setup-build-host.sh:45-82` |
| `docs/02 §10` 脚本默认分支 | **不一致**（F14，已修）：文档写"默认 lineage-23.2"，代码 `800c1a1` 后默认 22.2、并按分支选 manifest | `docs/02:183`、`:192` → 本次已更新 |
| `docs/02 §10` 脚本 ↔ 任务对应（P0-08/P1-01…P5-02） | 一致，无错配 | `docs/02:180-188` |
| `--allow-22.2-pinned-deps` 归属 | 在 `fetch-vendor-deps.sh`（`docs/02:185`、`docs/11 D-05` 均正确）；`init-sources.sh` 无此参数。首席 Wave 0 派单写成 init-sources 属表述误差 | `fetch-vendor-deps.sh:111` |
| 内核 22.2 sha 常量 | 与 GitHub 实测一致（`aa8adfe9…`），与 `docs/00:31` 一致 | `fetch-vendor-deps.sh:52` |
| Termux 锁定版本 | `fetch-termux.sh` 硬编码 `TERMUX_SHA256` 与 `prebuilt/Termux.apk.sha256` 实测一致（`72fdb596…`；2 空格分隔对 `awk 'NR==1{print $1}'` 友好） | 两文件实测 |
| README 与 `800c1a1` | 已同步为"22.2 先跑"、双分支表；仅 L10 对设备树 fork 只提了 23.2 分支（L48 表格已列双分支），属文字小瑕 | `README.md:10`、`:48` |

---

## 6. 本机无法验证项 + 构建机复验清单

### 6.1 本机不能做（如实记录）

| 项 | 原因 |
| --- | --- |
| `bash -n` 语法检查 | Git bash 在 DSH 沙箱下启动失败：`fatal error - couldn't create signal pipe, Win32 error 5`；WSL 未安装。**`docs/02 §11` 的"已通过 bash -n"本次未能复验** |
| 7 个脚本真实执行 | 需要 Ubuntu 构建主机（本机 Windows） |
| `repo init/sync/manifest` 解析 | 本机无 repo 工具、无外网（`Invoke-WebRequest`/`curl` 均失败）；上游事实改用 GitHub API 核验 |
| roomservice 行为、幂等性 | 同上 |

### 6.2 构建机上按序复验（每条都要留输出）

```bash
# 1) 语法（最基础、最先做）
for f in scripts/*.sh; do bash -n "$f" && echo "OK $f" || echo "FAIL $f"; done

# 2) 依赖安装预检（不修改系统）
bash scripts/setup-build-host.sh --dry-run

# 3) 初始化默认值（800c1a1 后默认 22.2）
bash scripts/init-sources.sh --dry-run          # 期望：分支 lineage-22.2、manifest terminalos-22.2.xml
bash scripts/init-sources.sh --no-local-manifest --dry-run   # 纯上游基线（另一种可复现做法见 baseline-22.2.xml）

# 4) 真实 init 后：确认 manifest 解析（把 §3.2 结论钉死）
repo manifest -o /tmp/manifest-expanded.xml && grep -c '<project' /tmp/manifest-expanded.xml
grep -A2 'kernel/xiaomi/sdm845' /tmp/manifest-expanded.xml   # 期望 remote 解析到 github.com/LineageOS/

# 5) 依赖检查三态（期望值已写明，不是"跑通就行"）
bash scripts/fetch-vendor-deps.sh --target-branch lineage-22.2   # 期望 exit 0
bash scripts/fetch-vendor-deps.sh --target-branch lineage-23.2   # 期望 exit 1 且报"内核缺少 23.2 分支"（预期行为，不是 bug）
bash scripts/fetch-vendor-deps.sh --target-branch lineage-23.2 --allow-22.2-pinned-deps  # 期望 exit 0 + 警告

# 6) 构建 + 产物收集（收集脚本会写各仓库 commit，可补 F02 的证据缺口）
bash scripts/build-baseline.sh
bash scripts/collect-artifacts.sh

# 7) 内核配置核验（K2 讨论项；主机官尚无 Linux 构建机，只能给命令）
#    重要：polaris 实际用的是 vendor/xiaomi/mi845_defconfig（sdm845-common 的
#    BoardConfigCommon.mk @35cf356 实测：TARGET_KERNEL_CONFIG := vendor/xiaomi/mi845_defconfig），
#    不是 arch/arm64/configs/defconfig —— 用 `make ARCH=arm64 defconfig` 验证会得到与本产品无关的结论。
cd kernel/xiaomi/sdm845
make O=/tmp/kcfg ARCH=arm64 vendor/xiaomi/mi845_defconfig
# 再按 BoardConfig.mk 的 fragment（device/xiaomi/polaris/BoardConfig.mk:19 TARGET_KERNEL_CONFIG += vendor/xiaomi/polaris.config）
# 合并后检查（实际合并由 LineageOS 构建系统完成，这里近似复现）
scripts/kconfig/merge_config.sh -O /tmp/kcfg /tmp/kcfg/.config arch/arm64/configs/vendor/xiaomi/polaris.config
grep -iE '^CONFIG_RMI4|^CONFIG_TOUCHSCREEN' /tmp/kcfg/.config
# 本机已做的静态替代证据（GitHub 代码搜索，2026-10-28）：kernel 仓 arch/arm64 全树
# `CONFIG_RMI4` 命中 **0**（仅 drivers/input 源码与 arch/arm defconfig 命中）→ 与"arm64 侧未启用 RMI4"一致。
```

---

## 7. 建议处置顺序

1. **上构建机前**（本机可改，小改动可一次提交）：F01、F02、F06、F10、F13。
2. **首次构建时验证**：F03（roomservice 拉 sdm845-common）、F04（brunch 产品名）、F05（Termux 期望 sha）、F08/F09。
3. **文档/范围**：F14（已修）、F16、F15（CI 专项审计另开）、F11。

> 本报告不含任何设备写入建议；刷写/`adb`/`fastboot` 仍只由首席在 Phase 0 核验后执行。
