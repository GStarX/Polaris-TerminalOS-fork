# Polaris-TerminalOS

把小米 MIX 2S（代号 `polaris`，SDM845，8 GB / 256 GB）改造成以 Termux 为主要交互界面的终端专用设备的
LineageOS 自定义 ROM 项目。

- 需求基线：[`Polaris-TerminalOS_实施说明书.md`](../Polaris-TerminalOS_实施说明书.md)（用户提供，v0.2）
- 结构化交付物：本仓库（文档 / local manifest / 构建脚本 / 验收矩阵）
- 自建代码仓库：[`android_vendor_terminalos`](https://github.com/GStarX/android_vendor_terminalos)、
  [`android_packages_apps_TerminalHome`](https://github.com/GStarX/android_packages_apps_TerminalHome)
- 设备树 Fork：[`android_device_xiaomi_polaris`](https://github.com/GStarX/android_device_xiaomi_polaris)（分支 `terminalos/lineage-23.2`）

> **当前状态：脚手架与上游核验完成，尚未编译、尚未刷机、尚未实机测试。**
> 本仓库里没有任何"构建成功 / 测试通过"的结论。所有 ROM 行为结论都必须来自真实构建日志与实机测试记录。

## 目标（摘自说明书）

1. 开机解锁后自动进入 Termux 终端，不显示普通 Android 桌面。
2. 正常操作不能退出终端或切换到未授权应用。
3. 隐藏底部导航条 / 手势提示条。
4. 顶部下拉仍可使用系统快捷设置（Wi-Fi / 亮度 / 蓝牙等）。
5. 实体音量键正常。
6. 保留管理员维护入口与可恢复路径。
7. 通过同步上游 + 合并自有提交的方式长期维护，而不是每次刷机后手工配置。

## 已核实的上游事实（2026-10-27）

| 事实 | 结论 | 证据 |
| --- | --- | --- |
| LineageOS 主 manifest 是否有 `lineage-23.2` | **有**（默认分支已是 `lineage-24.0`） | `LineageOS/android` 分支列表，`lineage-23.2` = `9776e518…` |
| `polaris` 设备树是否有 `lineage-23.2` | **有，但与 `lineage-22.2` 同一 commit** `1b46255c…`，即尚未做 Android 16 适配提交 | `LineageOS/android_device_xiaomi_polaris` |
| `sdm845-common` 设备树是否有 `lineage-23.2` | 有，同样与 22.2 同 commit `35cf356b…` | `LineageOS/android_device_xiaomi_sdm845-common` |
| 内核 `android_kernel_xiaomi_sdm845` 是否有 `lineage-23.2` | **没有**（最高 `lineage-22.2` = `aa8adfe9…`，Linux 4.9） | 分支列表 |
| vendor blobs（TheMuppets）是否有 `lineage-23.2` | **没有**（polaris 与 sdm845-common 都止于 `lineage-22.2`） | 分支列表 |
| 官方支持状态 | wiki（2026-10-26 生成）当前版本 **22.2 / Android 15**，内核 4.9；构建文档"官方支持分支"止于 `lineage-22.2` | [wiki](https://wiki.lineageos.org/devices/polaris/) |
| Termux 预置来源 | 官方 release `v0.118.3`，arm64-v8a APK sha256 `72fdb596…e83a4e`，Debug 签名 → 必须 presigned | termux/termux-app release |

**推论（重要）**：直接对纯上游执行 `repo init -b lineage-23.2` + `breakfast polaris` 会在内核分支解析处失败
（roomservice 找不到 `lineage-23.2` 内核分支时会退出），且缺少 23.2 vendor blobs 分支。
本仓库的 `local_manifests/terminalos.xml` 显式把内核与 blobs 锁定在 `lineage-22.2`，把"Android 16 移植"
作为**实验性、待验证**的路线记录，不当作已成立的支持。

详见 [`docs/00_上游核验报告.md`](docs/00_上游核验报告.md)。

## 仓库地图

| 仓库 | 路径 | 分支 | 用途 |
| --- | --- | --- | --- |
| `GStarX/android_device_xiaomi_polaris` | `device/xiaomi/polaris` | `terminalos/lineage-22.2`、`terminalos/lineage-23.2` | 新增 `terminalos_polaris` 产品配置（fork 自 LineageOS） |
| `GStarX/android_vendor_terminalos` | `vendor/terminalos` | `terminalos/lineage-22.2`、`terminalos/lineage-23.2` | 产品片段、Termux 预置、静态 overlay（22.2 分支已按该版本缺少的资源做差异适配） |
| `GStarX/android_packages_apps_TerminalHome` | `packages/apps/TerminalHome` | `terminalos/lineage-22.2`、`terminalos/lineage-23.2` | 默认 HOME / 终端拉起 / 有限重启 / 维护入口 / Lock Task（代码与分支无关） |
| `GStarX/Polaris-TerminalOS`（本仓库） | 构建机上任意位置 | `main` | 文档、local manifest、CI workflow、验收矩阵 |

其余 LineageOS 仓库（frameworks/base、SystemUI、vendor/lineage 等）**继续跟踪上游**，暂不 Fork。
`frameworks/base` 只有在 Phase 3 证明标准 Lock Task / Device Policy 无法满足"禁止退出 + 完整快捷设置"时才考虑改动。

## 阶段与当前进度

| 阶段 | 内容 | 状态 |
| --- | --- | --- |
| Phase 0 | 设备身份、Bootloader、分区、恢复路径核验 | **已执行**：polaris、已解锁、单槽、GLOBAL/国行确认、可恢复；详见 [docs/15](docs/15_真机零构建验证记录.md) |
| Phase 1 | 云构建 + 真机基线：先 `lineage-22.2`，再 23.2 实验 | **22.2 官方镜像已真机跑通**（docs/15）；云同步/结构校验全绿（run `40541735974`，docs/13）；整包构建等待 ≥350 GB runner |
| Phase 1K | 内核审计与 4.19 / 5.4 / 5.10+ 候选评估 | **未开始**（计划见 `docs/09`） |
| Phase 2 | Termux + TerminalHome 预置与自启动 | **ADB 部署真机验证通过**：开机自动进 Termux、重启保持、崩溃恢复、DO 锁任务（docs/15）；ROM 预置待整包构建 |
| Phase 3 | 锁定模式、导航栏隐藏、快捷设置保留 | 锁任务真机通过（Home/最近任务出不去）；**导航栏隐藏需 ROM 静态 overlay（RRO 被系统拒绝）；QS 磁贴需 22.2 框架补丁**（docs/15、docs/08） |
| Phase 4 | 精简与稳定性 | 未开始 |
| Phase 5 | 发布、升级、回滚 | 版本与记录模板已写；Release 由 CI 可选发布 |

## 云构建（GitHub Actions）——本项目不做本地构建

| workflow | 触发 | runner | 作用 |
| --- | --- | --- | --- |
| `validate.yml` | push / PR | GitHub 托管 | 静态校验：manifest、脚本语法、禁止刷机命令、跨仓库分支存在性 |
| `sync-check.yml` | 手动 / push `ci/**` | GitHub 托管 | 同步终端相关项目 + 结构契约校验 + Termux sha256 |
| `build-rom.yml` | 手动 | **需 ≥350 GB 磁盘的 self-hosted / larger runner** | 整包构建 22.2（先 baseline 再 terminalos），产物 upload + 可选 Release |

详见 [`docs/12_云构建_GitHub_Actions.md`](docs/12_云构建_GitHub_Actions.md)。
托管标准 runner 只有约 14 GB 磁盘，**不能**整包构建 LineageOS；不要再尝试在本机或托管 runner 上硬编。

## 快速开始（云构建，不在本地编译）

```bash
# 0) 一次性：给仓库配置一个够大的 runner（self-hosted 云主机或 larger runner），见 docs/12
#    托管标准 runner 只有 ~14 GB 磁盘，不能整包构建

# 1) 校验：push 任意提交即触发 validate.yml
# 2) 同步校验：Actions → sync-check → Run workflow，lineage_branch=lineage-22.2
#    或 push 一个 ci/22.2-sync 分支触发
# 3) 整包构建（需要大 runner）：Actions → build-rom → Run workflow
#    lineage_branch = lineage-22.2
#    build_target  = baseline     # 先验证未修改基线
#    runner        = ["self-hosted","linux","x64","lineage-builder"]（按你的 runner label）
# 4) 基线通过后，再跑 build_target = terminalos（Termux + TerminalHome 产品）
```

本地只做静态检查（`bash -n`、`--help`、结构化自测）；**不执行 Android 编译**。

> 本机（Windows、23.7 GB RAM、16 核、1.7 TB 可用、无 WSL）**不作为构建机**。
> 除 Phase 0 的真机核验外，刷机只由首席执行；本仓库不含任何 fastboot/adb 刷机脚本。

## 文档索引

- [`docs/00_上游核验报告.md`](docs/00_上游核验报告.md) —— A：上游与设备支持核验结论
- [`docs/01_仓库与local_manifest设计.md`](docs/01_仓库与local_manifest设计.md) —— C：仓库、分支、local manifest 设计
- [`docs/02_构建环境与依赖.md`](docs/02_构建环境与依赖.md) —— B：构建主机与环境
- [`docs/03_任务清单_Phase0_基线_内核.md`](docs/03_任务清单_Phase0_基线_内核.md) —— D：Phase 0 / 基线 / 内核任务清单
- [`docs/04_风险与验收.md`](docs/04_风险与验收.md) —— E：风险清单与验收标准
- [`docs/05_构建与产物记录模板.md`](docs/05_构建与产物记录模板.md)
- [`docs/06_Phase0_设备核验清单.md`](docs/06_Phase0_设备核验清单.md) —— 真机核验 runbook（首席执行）
- [`docs/07_刷机与恢复流程_草案.md`](docs/07_刷机与恢复流程_草案.md)
- [`docs/08_锁定模式与导航栏方案评估.md`](docs/08_锁定模式与导航栏方案评估.md)
- [`docs/09_内核升级评估_K0.md`](docs/09_内核升级评估_K0.md)
- [`docs/10_发布与升级.md`](docs/10_发布与升级.md)
- [`docs/11_决策记录.md`](docs/11_决策记录.md) —— 影响后续工作的决策与理由
- [`docs/12_云构建_GitHub_Actions.md`](docs/12_云构建_GitHub_Actions.md) —— 云构建/runner/首次跑 22.2 流程
- [`docs/13_首次云构建记录.md`](docs/13_首次云构建记录.md) —— 真实云运行记录（run id、通过/失败项）
- [`acceptance/验收测试矩阵.md`](acceptance/验收测试矩阵.md) —— T01–T15
- [`docs/15_真机零构建验证记录.md`](docs/15_真机零构建验证记录.md) —— 官方 22.2 + ADB 部署真机验证（T01–T13 实测）
- [`evidence/2026-10-28/`](evidence/2026-10-28/) —— 真机验证截图与日志证据

## 边界与安全约定

- 不承诺抵御拥有物理访问 / Fastboot / Recovery / ADB 授权的人；目标是限制正常 Android 界面中的误操作。
- 设备型号、固件区域、分区布局、活动槽位未确认前，不执行任何 `fastboot flash`。
- 自定义 ROM 未完成验证前，不重新锁定 Bootloader。
- 每次精简/框架改动必须单独提交、单独验证，并附回滚方式。
