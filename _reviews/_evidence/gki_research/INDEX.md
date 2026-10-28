# 证据文件索引：被引用 / 仅存档

- 生成：方案甲，2026-10-28（v2，按 复核官 要求加「被引用 / 仅存档」分类）
- 目的：满足 首席 验收标准 ②「引文必须可核」；并让 评审官 终稿**只引「被引用」那一类**。
- 落盘：`C:\AiWork\Polaris-TerminalOS\_reviews\_evidence\gki_research\`
- 入库：commit `923d2ed`（证据包）、`247405e`（本索引）

## 0. 分类定义（先说清口径，避免计数争议）

| 分类 | 定义 | 终稿可否引用 |
| --- | --- | --- |
| **A · 被引用** | **直接支撑 `_reviews/K2_CANDIDATES_C_O5.md` 中某条具体结论**（文档里有对应引文或断言） | ✅ 可以 |
| **B · 仅存档** | 抓取时的背景材料，**未支撑任何具体结论** | ❌ 不要引 |

> 注意：不能用「文件名是否出现在文档里」来判定——本文很多页面是**按 URL 或内容引用**的，文件名未写出。
> 所以本表按「是否支撑具体结论」人工判定，并逐条写明支撑点。

## A. 被引用（21 个 txt + 7 个 html）

### A1. GKI 判定（K2 §2.3）

| 文件 | 页面标题 | URL | 可信 | 支撑的具体结论 |
| --- | --- | --- | --- | --- |
| `kernel_overview.txt` | Kernel overview | https://source.android.com/docs/core/architecture/kernel | [推断] | **§2.3 引文1**：GKI ≡ "Any 5.10 and higher ACK kernel (aarch64 only)"（:469） |
| `android_common.txt` | Android common kernels | https://source.android.com/docs/core/architecture/kernel/android-common | [推断] | **§2.3 引文5**：支持矩阵最低一行 Android 12、无 4.x（`#compatibility-matrix`） |
| `vendor_boot.txt` | Vendor boot partitions | https://source.android.com/docs/core/architecture/partitions/vendor-boot-partitions | [推断] | **§2.3 引文3**：vendor_boot 需 boot header v3+（:425） |
| `vendor_odm_dlkm.txt` | Vendor and ODM DLKM partitions | https://source.android.com/docs/core/architecture/partitions/vendor-odm-dlkm-partition | [推断] | **§2.3 引文2**：vendor_dlkm/odm_dlkm 位于 super（:440） |
| `dynamic_partitions.txt` | Implement dynamic partitions | https://source.android.com/docs/core/ota/dynamic_partitions/implement | [推断] | **§2.3 引文4**：super 自 Android 10 出厂引入（:410-411）；**589/591-592 澄清**（system-as-root 是另一句）；**591 retrofit 原文**支撑 v6 自我修正 |
| `gki_versioning.txt` | GKI versioning scheme | https://source.android.com/docs/core/architecture/kernel/gki-versioning | [推断] | 「`android12-5.4` 与 `android12-5.10` 都存在而非二选一」的官方自证（示例用 5.4） |
| `gki_partitions.txt` | Implement a GKI module partition | https://source.android.com/docs/core/architecture/partitions/gki-partitions | [推断] | `system_dlkm` 在 super 内；`clo/la/kernel_platform` 为 GKI 构建树布局的旁证 |

### A2. CDD 否定断言（K2 §2.3 引用纪律 2）

| 文件 | 页面标题 | URL | 可信 | 支撑的具体结论 |
| --- | --- | --- | --- | --- |
| `cdd_11.txt` | Android 11 Compatibility Definition | https://source.android.com/docs/compatibility/11/android-11-cdd | [推断] | 「CDD 里没有 GKI 支持矩阵」——三份 CDD 查 `Generic Kernel Image\|\bGKI\b` **均 0 命中** |
| `cdd_12.txt` | Android 12 Compatibility Definition | https://source.android.com/docs/compatibility/12/android-12-cdd | [推断] | 同上 |
| `cdd_current.txt` | Android 15 Compatibility Definition | https://source.android.com/docs/compatibility/15/android-15-cdd | [推断] | 同上 |

> 复现：`Get-ChildItem raw -Filter *cdd* | ForEach-Object { (Select-String -Path $_.FullName -Pattern 'Generic Kernel Image|\bGKI\b' -AllMatches).Count }` → 全 0

### A3. CAF / CLO 无 SDM845 4.x/5.x（K2 §2.1.1、§2.3 证据4）

| 文件 | 内容 | URL（GitLab API） | 支撑的具体结论 |
| --- | --- | --- | --- |
| `clo_msm49_proj.txt` | msm-4.9 project 元数据 **id 12600** | `/api/v4/projects/12600` | 仓库真实存在；后续用该 id 查分支/tag |
| `clo_msm49_tags.txt` | msm-4.9 tags | `/api/v4/projects/12600/repository/tags` | **阳性对照**：`?search=sdm845` 在 4.9 大量命中 |
| `clo_msm49_branches.txt` / `_p2.txt` | msm-4.9 分支（两页） | `/api/v4/projects/12600/repository/branches` | **`KERNEL.PLATFORM.*` 分支数 = 0**；branch 名搜 `845` = 0 |
| `clo_msm54_branches.txt` | msm-5.4 分支 **id 22241** | `/api/v4/projects/22241/repository/branches` | 同上 = 0 |
| `clo_msm510_branches.txt` | msm-5.10 分支 id 29371 | `/api/v4/projects/29371/repository/branches` | 有 3 个 `KERNEL.PLATFORM.1.0.c25/c26/c27`（对比：4.9/5.4 为 0） |
| `clo_msm515_branches.txt` / `_retry.txt` | msm-5.15 分支 id 53431 | `/api/v4/projects/53431/repository/branches` | 有 1 个 `KERNEL.PLATFORM.2.0.c25` |
| `clo_api_kernel.txt` | `clo/la/kernel` 组 project 列表（46 个） | `/api/v4/groups/clo%2Fla%2Fkernel/projects?per_page=100` | §2.3 证据4 的「46 个 project」口径 |
| `clo_api_subgroups.txt` | `clo/la/kernel` 子组 | `/api/v4/groups/clo%2Fla%2Fkernel/subgroups` | 背景分组结构 |
| `clo_kernel_list.txt` | 该组网页 | https://git.codelinaro.org/groups/clo/la/kernel | 仓库清单（msm-3.10…5.15，**无任何 845 专属 5.x 仓**） |
| `clo_kp_group.txt` | `clo/la/kernel_platform` 组元数据 | `/api/v4/groups/clo%2Fla%2Fkernel_platform` | 该 GKI 产物组存在 |
| `clo_kp_projects.txt` | 该组 projects（**空 `[]`**） | `/api/v4/groups/clo%2Fla%2Fkernel_platform/projects` | 「高通 GKI 产物树与 845 无交集」 |
| `clo_kp_subgroups.txt` | 该组 9 个子组 | `/api/v4/groups/clo%2Fla%2Fkernel_platform/subgroups` | 子组即 GKI 构建树布局（bootable/build/external/kernel/prebuilts/system/test/toolchain/tools） |

### A4. kernel/common 分支谱系（K2 §2.3 补充）

| 文件 | 页面标题 | URL | 可信 | 支撑的具体结论 |
| --- | --- | --- | --- | --- |
| `gsource_root.txt` | kernel/common 仓库根 | https://android.googlesource.com/kernel/common/ | [推断] | 现存 heads 已无 `android-4.9-*` ACK 分支 |
| `gsource_refs.txt` | kernel/common 全部 refs | https://android.googlesource.com/kernel/common/+refs | [推断] | tag 保留 4.9 谱系（`ASB-*-4.9-o-mr1` = Android 8.1 世代），即 4.9 属 pre-GKI 命名体系 |

### A5. 被引用页面的原始 HTML（7 个，字节保真）

`raw/` 下同时保留了这 7 个页面的**原始 HTML**，与 txt 同名：
`kernel_overview.html`、`android_common.html`、`vendor_boot.html`、`vendor_odm_dlkm.html`、
`dynamic_partitions.html`、`gki_partitions.html`、`gki_versioning.html`。
sha256 见 `MANIFEST.md` §5，可用 `Get-FileHash` 校验。

> **为什么只保留 7 个 HTML**：其余 34 页未被引用，保留 HTML 会造成同页 html+txt 双份冗余（主机官已提示）。
> 41 个 txt 全部保留，任何断言都能 grep 复核。

## B. 仅存档（20 个 txt）——终稿不要引用

| 文件 | 页面标题 | 为什么归存档 |
| --- | --- | --- |
| `modular_kernels.txt` | Kernel overview | 与 `kernel_overview.txt` 同页的重复抓取 |
| `gki_page.txt` | Generic Kernel Image (GKI) project | 背景，未支撑具体结论 |
| `gki_dev.txt` | GKI development | 背景 |
| `gki_release.txt` | GKI release builds | 背景 |
| `gki_release_builds_hub.txt` | GKI release builds | 重复抓取 |
| `kernel_module_sup_retry.txt` | Kernel modules overview | 背景（模块机制，本文未用） |
| `kernel_module_sup2.txt` | Kernel modules overview | 重复抓取 |
| `kernel_module_support.txt` | Kernel module support | 背景 |
| `vendor_module_guidelines.txt` | Vendor module guidelines | 背景 |
| `partitions_overview.txt` | Partitions overview | 背景 |
| `api_flags.txt` | Vendor API level | 背景 |
| `vts_overview.txt` | VTS and infrastructure | 背景 |
| `clo_la_projects.txt` | `clo/la` projects | 粒度太粗，结论用的是 `clo/la/kernel` 那份 |
| `clo_la_subgroups.txt` | `clo/la` 子组 | 同上 |
| `gh_branches_api.txt` | GitHub 分支 API 响应 | **抓取时未记录仓库名，明确不作为任何结论依据** |

> 差集核对：A 类 21 + B 类 20 = **41 个 txt**，与 `raw/` 实际数量一致。

## 附：文件数口径（解释 55 vs 56 的争议，避免再耗一轮）

| 口径 | 数值 | 说明 |
| --- | --- | --- |
| commit `923d2ed` 下 `_reviews/_evidence/` | **55** | 主机官实测值，正确；当时只有 2 个 md（MANIFEST/REPORT） |
| commit `247405e` 起（新增本 `INDEX.md`） | **56** | 现 HEAD 值，也正确；3 个 md |
| 构成 | 41 txt + 7 html + 3 md + 2 py + 2 json + 1 `.gitattributes` = **56** | |

**两个数都对，差别只在测量时点**，不是谁数错。体积 4.75 MB。

## 未闭口项

1. `[推断]` 的 URL 未与抓取日志逐条对照——**`fetch_log.json` 只覆盖 5 个 URL**（`vendor_module_guidelines`、`api_flags`、`gki-partitions`、`partitions`、`modules`），其余靠页面标题推断。这正是 复核官 指出的追溯缺口；本索引用「标题 + 常规路径」补映射，但**不等于已验证**。如需绝对确认，用 `fetch.py` + `targets.json` 重抓比对 sha256。
2. VSR 原文（`/docs/compatibility/vsr`、`/15/vsr`）**均 404，未取得**，不得引用。
3. 不存在「Android 8.1 / 4.9 不适用 GKI」的单句原文，该结论只能按推导表述。
