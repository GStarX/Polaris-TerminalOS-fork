# 01 · 仓库与 local manifest 设计（C 项）

## 1. 总原则（来自说明书 §3.2）

- 用 `repo` 管理多仓库，不把整个 Android 源码放进一个巨型 Fork。
- 只 Fork 有实际改动需求的仓库；其余跟踪上游。
- 所有自定义修改以 Git commit 保存，每提交写明原因、影响范围、验证步骤、回滚方式。
- 上游更新时优先 rebase/merge 小而独立的补丁。

## 2. 仓库清单与写入边界

| 仓库 | 检出路径 | 分支 | 谁改 | 改动内容 |
| --- | --- | --- | --- | --- |
| `GStarX/android_device_xiaomi_polaris`（fork） | `device/xiaomi/polaris` | `terminalos/lineage-23.2` | 产品配置负责人 | 新增 `terminalos_polaris.mk`、注册到 `AndroidProducts.mk`；不修改设备基础配置 |
| `GStarX/android_vendor_terminalos` | `vendor/terminalos` | `terminalos/lineage-23.2` | 产品配置负责人 | `terminalos.mk` 产品片段、Termux 预置（`android_app_import` presigned）、静态 overlay、辅助脚本 |
| `GStarX/android_packages_apps_TerminalHome` | `packages/apps/TerminalHome` | `terminalos/lineage-23.2` | TerminalHome 负责人 | 默认 HOME、拉起 Termux、有限重启、维护入口、Lock Task 控制 |
| `GStarX/Polaris-TerminalOS` | 构建机任意目录 | `main` | 文档/构建负责人 | 文档、local manifest、构建脚本、验收矩阵 |
| `LineageOS/android_device_xiaomi_sdm845-common` | `device/xiaomi/sdm845-common` | `lineage-23.2` | 上游，暂不改 | — |
| `LineageOS/android_kernel_xiaomi_sdm845` | `kernel/xiaomi/sdm845` | 锁定 `lineage-22.2` | 内核负责人（Phase 1K 才 Fork） | 23.2 阻塞项；内核升级另开分支 |
| `TheMuppets/proprietary_vendor_xiaomi_polaris` | `vendor/xiaomi/polaris` | 锁定 `lineage-22.2` | 上游，暂不改 | 23.2 无分支 |
| `TheMuppets/proprietary_vendor_xiaomi_sdm845-common` | `vendor/xiaomi/sdm845-common` | 锁定 `lineage-22.2` | 上游，暂不改 | 23.2 无分支 |
| `frameworks/base`、SystemUI 等 | 上游路径 | `lineage-23.2` | 暂不改（Phase 3 评估） | 仅在标准 API 无法满足需求时才 Fork |

**写入边界规则（多 Agent 协作）**：

1. 一个仓库同一时间只允许一个负责人改动；跨仓库接口先写简短设计记录（本目录 docs）再并行。
2. 设备树只加"产品配置"文件，不改 `device.mk` / `BoardConfig.mk` / `polaris-vendor.mk`。
3. `frameworks/base`、SystemUI 在 Phase 1 基线构建成功前**不允许**修改（说明书 §11 最后一段）。
4. 任何仓库的默认分支（`lineage-23.2`）只接收合并后的可构建提交，不直接堆实验改动。

## 3. local manifest 设计

文件：`local_manifests/terminalos.xml`（部署到 `.repo/local_manifests/`）。

```xml
<remote name="terminalos" fetch="https://github.com/GStarX/" />
<project name="android_device_xiaomi_polaris" path="device/xiaomi/polaris" remote="terminalos" revision="terminalos/lineage-23.2" />
<project name="android_vendor_terminalos" path="vendor/terminalos" remote="terminalos" revision="terminalos/lineage-23.2" />
<project name="android_packages_apps_TerminalHome" path="packages/apps/TerminalHome" remote="terminalos" revision="terminalos/lineage-23.2" />
<project name="LineageOS/android_kernel_xiaomi_sdm845" path="kernel/xiaomi/sdm845" revision="lineage-22.2" />
<project name="TheMuppets/proprietary_vendor_xiaomi_polaris" path="vendor/xiaomi/polaris" revision="lineage-22.2" />
<project name="TheMuppets/proprietary_vendor_xiaomi_sdm845-common" path="vendor/xiaomi/sdm845-common" revision="lineage-22.2" />
```

设计理由：

- **设备树必须 fork**：产品配置（`terminalos_polaris.mk`）属于设备树目录，LineageOS 的 `AndroidProducts.mk`
  必须能枚举到产品 mk，只有设备树里的注册方式可靠。
- **公共设备树不 fork**：未做修改，`breakfast` 会自动从上游取 `lineage-23.2`（该分支存在）。
- **内核/blobs 显式锁定 22.2**：唯一让 23.2 `repo sync` 可完成、且不依赖环境变量的方式；
  同时把"23.2 内核/blobs 缺失"作为显式事实留在配置里，避免后来人误以为 23.2 已被支持。
- **不声明 `frameworks/base`**：暂不需要框架补丁；保持上游可追踪。

## 4. 分支策略

| 分支 | 用途 | 规则 |
| --- | --- | --- |
| `lineage-23.2`（各自有仓库中） | 上游跟踪分支，只做 rebase/merge | 不在其上直接做实验提交 |
| `terminalos/lineage-23.2` | Android 16 目标分支（当前默认工作分支） | 每个功能一个提交；提交信息含验证结果与回滚方式 |
| `terminalos/lineage-22.2`（待建） | 官方支持基线分支，用于"先证明可构建/可启动" | 由 `terminalos/lineage-23.2` 同等补丁复制创建 |
| `lineage-22.2`（内核仓库） | 当前锁定的内核基线 | 内核升级（Phase 1K）另建分支，不改此分支 |

> 分支名 `terminalos/lineage-23.2` 是项目内部约定；若上游后续正式支持 23.2，可重新命名。
> `terminalos/lineage-22.2` 目前**尚未创建**（等 Phase 1 基线构建启动时再建，避免空分支混淆）。

## 5. 上游更新流程（对应说明书 §10）

```bash
# 1) 在干净工作区先验证上游仍可构建（基线构建）
# 2) 更新自有 fork 的上游跟踪分支
git remote add upstream https://github.com/LineageOS/android_device_xiaomi_polaris.git
git fetch upstream
git rebase upstream/lineage-23.2 terminalos/lineage-23.2
# 3) 逐仓库合并自有补丁，检查冲突与 API 变化
# 4) 重建 ROM + 执行对应实机测试
# 5) 打 tag，记录 commit 与产物校验值
```

注意：

- 本仓库的 `terminalos/lineage-23.2` 提交必须**小且独立**，避免一次 rebase 冲突过多。
- 每次 merge 上游后，必须重新跑构建与至少 T01/T02/T03 实机测试，再更新 tag。

## 6. 提交规范

```
<type>: <subject>

Why:     修改原因
Scope:   影响仓库/模块
Build:   编译验证结果（没构建就写"未构建"）
Device:  实机测试编号与结果（没测就写"未测试"）
Risk:    已知限制
Rollback:回滚方式（通常是 git revert <sha> 或移除产品继承）
```

类型：`feat` / `fix` / `docs` / `build` / `config` / `revert`。
