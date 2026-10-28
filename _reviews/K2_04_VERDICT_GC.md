# K2-04 候选裁决（复核官 · 二次评估定案）

> **状态更新（2026-10-28）：本文件为过程记录（含 R0 自更正）。K2-04 已正式结案，最终口径见 `K2_04_CLOSURE_GC.md`。**
> 本文件保留的价值：§9 的错因记录与 §5.2 的修订过程；结案依据以 CLOSURE 文件为准。

- 时间：2026-10-28（Asia/Shanghai）
- 依据输入：`_reviews/K2_CANDIDATES_C_O5.md`（方案甲，383 行）、`_reviews/K0_AUDIT_G_6.md`（方案乙，30 行）、`docs/03:52-58`（K2-04 原始口径）、`docs/09`（77 行）、本地 `C:\AiWork\Polaris-TerminalOS-repos`
- 方法：**不采信转述**。可本地/API 复现的断言全部由我重跑；无法复现的标明采信级别。未执行 adb / boot / 刷写 / 构建，未改任何实现代码。
- 写入范围：仅本文件（`_reviews/K2_04_VERDICT_GC.md`）。

---

## 0. 裁决结论

| 项 | 内容 |
| --- | --- |
| **选定目标版本** | **Linux 4.9.337**，`LineageOS/android_kernel_xiaomi_sdm845`，分支 `lineage-22.2`，HEAD `aa8adfe9bf212c6e93238a86980b4024da4f819a`（构建时必须 pin 到 commit，见 §5.1） |
| **fallback** | **无同路线 fallback（当前）**。**4.19 已由「无候选」修订为「有候选但不可依赖」**（见 §5.2 与 §9 修订记录）；4.19 树存在不改裁决方向。5.4 仍判不可行；5.10+ 仍判「换产品」。若用户坚持升级，唯一有实机验证支撑的路径仍是主线 Linux 发行版。 |
| **裁决状态** | **方向性预裁决（可定）· 已含 R0 修订**；K2-04 的**正式结案**仍缺一项输入 → 见 §4 |
| **不动摇结论的瑕疵** | 方案甲报告有 3 处口径需返工（§3），均不影响「维持 4.9.337」的方向 |

一句话：**升级内核不解决本项目任何已知阻塞；维持 4.9.337 是唯一有厂商代码、有 HAL 配套、有维护的选项。**

---

## 1. 我亲自复现的证据（一手，可重跑）

| # | 断言 | 我的复现方式 | 结果 | 与方案甲 |
| --- | --- | --- | --- | --- |
| E1 | `v4.19` tag 指向的 commit = `84df9525b0c27f3ebc2ebb1864fa62a97fdedb7d` | GitHub `get_tag(torvalds/linux, v4.19)`，取 `object.sha`（annotated tag 的 tag-object sha 为 `2241b8bc`，须比对 `object.sha`） | `object.sha = 84df9525…`，tagger Greg KH，2018-10-22 | 一致 |
| E2 | OnePlus SDM845 的 `lineage-23.2` HEAD = `84df9525…` | `list_branches(LineageOS/android_kernel_oneplus_sdm845)` 全量 14 分支 | `lineage-23.2 = 84df9525b0c27f3ebc2ebb1864fa62a97fdedb7d`，**与 E1 完全相同** | 一致 |
| E3 | ⇒ 该 4.19 分支是 vanilla v4.19 原始 tag，**零厂商代码** | E1+E2 sha 全等 | **成立**。LineageOS 为 SDM845 开的 4.19 分支止步于上游发布点 | 一致 |
| E4 | Sony SDM845 的 `lineage-23.0` 与 `lineage-22.2` 同 sha | `list_branches(LineageOS/android_kernel_sony_sdm845)` | 两者均 `1a8fc01dce4296fc3d5437dc4f2a713ecec621e9` | 一致 |
| E5 | 该 sha 的内核版本 = 4.9.337 | 代码索引读 `Makefile@1a8fc01d` 原文片段 | `VERSION = 4` / `PATCHLEVEL = 9` / `SUBLEVEL = 337` | 一致 |
| E6 | Xiaomi SDM845 内核仓最高分支 = `lineage-22.2`，**无 23.x** | `list_branches(android_kernel_xiaomi_sdm845)` 全量 18 分支 | 最高 `lineage-22.2 = aa8adfe9…`；`lineage-21/22.0/22.1` 三者同 sha `88606771…`（冻结迹象成立） | 一致 |
| E7 | 该 sha 内核版本 = 4.9.337 | 代码索引读 `Makefile@aa8adfe9` | `PATCHLEVEL = 9` / `SUBLEVEL = 337`（`PATCHLEVEL=9` 唯一确定 4.9.x） | 一致 |
| E8 | 主线**无面板驱动**认领 `jdi,fhd-nt35596s` | ① `get_file_contents(torvalds/linux, drivers/gpu/drm/panel/panel-jdi-fhd-nt35596s.c)`；② 全树代码搜索 `fhd-nt35596s` | ① **404，文件不存在**；② `total_count=1`，`incomplete_results=false`，唯一命中 = `arch/arm64/boot/dts/qcom/sdm845-xiaomi-polaris.dts` | 一致，且该条在我这边**从「第三路转述」升为定级证据** |
| E9 | polaris blobs 条目 263、`.ko` 数量 **0** | 本地 `proprietary-files.txt` 统计 | 非空非注释 **263**；`\.ko$` 命中 **0** | 一致 |
| E10 | blobs 来源 = MIUI V12.0.3.0.QDGMIXM 全球稳定版 | 同上首行 | `# Device proprietary files - from polaris' MIUI package V12.0.3.0.QDGMIXM global stable version` | 一致 |
| E11 | 双指纹 HAL / PN553 / TAS2559 / SSC 传感器 | 同上 grep | `fingerprint.fpc.so` + `fingerprint.goodix.so`（各带 `FIX_SONAME`）、`libpn553_fw.so`、`libpn553_rec.so`、`tas2559_uCDSP.bin` + `_l/_r.ftcfg`、`sensors.ssc.so` 全部命中 | 一致 |
| E12 | `docs/09` 原文立场 | 本地 `docs/09_内核升级评估_K0.md` 按 UTF-8 读全文 77 行 | :13 只提 `polaris.config`；:17 表格记「上游 4.19 准备迹象」；**:19-22 原文明确写「公开仓库目前没有 4.19 内核分支」「不能仅凭一条提交信息就宣称 4.19 可用」** | **不一致，见 R1** |
| E13 | K2-04 原始验收口径 | `docs/03:55` | 「候选裁决：选定目标版本 + fallback，写清"为什么不是更高版本"」，**依赖 K2-01..03**，负责人 = 复核官 | 方案甲未提及 |

> **E8 的意义**：方案甲的 §3.3 整节来自第三方子代理，他本人只在 §3.3.5 标了 `CONFIG_RMI4` 待复验。但「主线面板无驱动」是判定 5.10+ 不可行的**决定性**一条，我不接受转述——现已独立复现：驱动文件 404，且该 compatible 全树只存在于 polaris 自己的 dts 里。**这条可以定了。**

---

## 2. 采信但未亲自复现（分级，不得当成我的实证）

| 内容 | 来源 | 级别 |
| --- | --- | --- |
| polaris 主线 dts 其余节点清单（`sound {}` 空壳、`&adsp_pas`/`&slpi_pas` 未使能、`pmi8998_charger` 未使能、无 pmi8998 电量计、无相机 CCI/NFC/指纹/传感器/振动节点） | 方案甲第三方子代理，`web_fetch` 两份全文 | **待证据（B 级）**。不影响裁决：E8 已单独锁死「屏点不亮」，其余项只是把「不可用」范围扩大 |
| `CONFIG_RMI4` / `CONFIG_TOUCHSCREEN_SYNAPTICS*` 在 arm64 defconfig 零命中 | 同上，方案甲自标「转写后 grep」 | **待证据**。不影响裁决（触屏不在他「八项」内）。转 主机官 在真机构建机 `make ARCH=arm64 defconfig` 后复验 |
| GitLab `sdm845-mainline/linux` 默认分支 `sdm845/7.1-dev`、HEAD `85f1df2a`、内核 7.1-rc1；Nura 设备包 2026-07-19 归档、maintainer 空 | GitLab API + pmaports | **参考级**。方向与 E8 一致，不作为我的实证 |
| polaris 在 Nura wiki 的各功能状态（Screen/Touch/Battery/Audio/Wi-Fi Partial，Camera/OTG Broken） | 外部 wiki 二手 | **参考级**，见 R5 |
| 「高通官方无 SDM845 的 msm-4.19/5.4 发布」 | CodeLinaro tag 命名推断，方案甲自标 **[疑]** | **未确证**，见 R2 |

---

## 3. 判定为「需返工」的口径问题（退回 方案甲，结论方向不受影响）

| # | 位置 | 问题 | 修法（可直接照做） |
| --- | --- | --- | --- |
| **R1** | §2.1 末尾引用块：「这条直接修正 `docs/09:17-22` 的乐观解读」 | **误读既有文档**。E12 实读：`docs/09:19-22` 原文已是保守立场，明确写「公开仓库目前没有 4.19 内核分支」「不能仅凭一条提交信息就宣称 4.19 可用」。不存在需要「撤回」的乐观解读，这是在打稻草人。 | 改写成不冤枉文档的因果：**「本项把 `docs/09:17-22` 列为待调查线索的 4.19 候选关闭为不可行，并补上 docs/09 当时未掌握的一手证据：OnePlus SDM845 的 `lineage-23.2` 分支 HEAD 就是上游 `v4.19` tag 指向的 commit（E1/E2/E3）。」** 同时删掉「撤回乐观解读」措辞。 |
| **R2** | §5.1 表格第一行裁决理由：「…零厂商代码；**高通无 SDM845 4.19 发布**」 | 裁决理由里混入了作者自己标 **[疑]** 的项（§2.1 注明「由 CodeLinaro tag 命名推断」）。裁决文本不能用推断级证据。 | 二选一：① **删掉该半句**，理由只留已证部分（E1–E3）；② 补 CodeLinaro 一手证据（tag 列表 + 对应 commit 直读）后升为 [确] 再写入。未补前不得出现在裁决/汇报口径里。 |
| **R3** | §0 结论 5 标题与 §4 结论：「**Android 16 根本不需要新内核**」「内核升级对本项目交付目标没有必要性」 | 表述强度超出证据。E4/E5 只证明：**Sony 的 SDM845 在 `lineage-23.0` 上沿用与 `22.2` 完全相同的 commit，未做任何内核改动**。这支持「LineageOS 未对该平台强制内核升级」，不等于「Android 16 在原理上不需要新内核」。 | 统一改为：**「LineageOS 的 SDM845 Android 16 分支（Sony `lineage-23.0`）内核 commit 与 `22.2` 完全相同，未做改动 ⇒ 对该平台未强制内核升级；23.x 路线的阻塞是 23.2 设备树与 blobs 缺失（docs/00 已证），不是内核版本。」** |
| R4（建议） | §2.4 标题「交叉调研（并行第二路，结论待并入）」 | 与正文「该路结果尚未返回」自洽，但标题易被 评审官 读成「整份报告未完成」。 | 标题改为「第二路（CodeLinaro）未并入——不影响主结论」，并在 §7 保留待证项。 |
| R5（建议） | §3.2 表下 [确] 引用块 | 「没有任何 SDM845 设备进入 Nura main」「指纹整体不可用」「modem 结构性缺陷」的对象是**wiki 页面记载**，不是设备实测。 | 断言前加限定：「据 Nura wiki（2026-10 快照）记载」。级别保持参考，不进裁决理由。 |

> **不构成打回的一项**：方案甲引用的 `docs/09:13`、`docs/09:17-22` 行号**我逐行核过，准确**（:13 确实只提 `polaris.config`、未提 `mi845_defconfig`；:17 表格 + :19-22 注释在同一区间）。行号无需修正。

---

## 4. 流程硬发现：K2-04 的依赖链未闭合

`docs/03:55` 写明 K2-04「**依赖 K2-01..03**」。当前实况：

| 依赖 | 负责人 | 交付 | 状态 |
| --- | --- | --- | --- |
| K2-01 候选源码调研 | 方案甲 | `_reviews/K2_CANDIDATES_C_O5.md` §2 | **可验收**（含仓库 URL/分支/commit/SDM845 支持度，符合 docs/03:52 交付格式） |
| K2-02 驱动覆盖评估 | 方案甲 | 同上 §3.4（13 项 + 等级） | **可验收**（等级级工作量估计；不要求工时，因裁决为「不升级」，31 项工作量无决策价值） |
| **K2-03 模块 ABI 与 vendor 接口评估** | **方案乙** | **未交付** | **缺** |

**判定**：本文件是**方向性预裁决**，「维持 4.9.337」的方向已由 E1–E11 一手证据锁死，不因 K2-03 缺失而动摇；但 K2-04 的**正式结案**（含「为什么不是 5.10+」中 HAL/ABI 影响面一节）必须等 K2-03。

## 4.1 给 方案乙 的 K2-03 可执行验收判据（**已扩展：4.19 优先**）

> **重要修正**：原判据只针对「5.10」。现 4.19 已被证明是**活候选**（E14–E19），而 5.10 主线已被 E8 否掉显示。**评估对象优先级改为：4.19 下游（meuira 树）> 5.10 主线**。5.10 可只给结论级说明，4.19 必须逐项量化。

交付 `_reviews/K2_03_ABI_G_6.md`，必须满足：

1. **覆盖全部依赖内核接口的闭源 HAL**，至少点名五类：FastRPC/ADSP（`libSuperSensor_skel.so`、`libarcsoft_dualcam_refocus_skel.so`）、QMI/SMD 传感器（`sensors.ssc.so`）、camera-kernel/CAMSS ioctl（CamX `com.qti.sensor.*`）、QSEECOM（`keymaster@3.0`、`secure_element@1.0`）、ICE（`fileencryption=ice`）。依据本地 `proprietary-files.txt`（263 条）+ `manifest.xml`，不得凭印象。
2. **对 4.19 路径逐个给出 uapi 判定**：必须比对 **4.9 树** 与 **meuira 4.19 树**（`meuira/android_kernel_xiaomi_sdm845_419` @ `5cd18f08`）的对应接口定义——至少覆盖 `techpack/display` 的 `sde_drm` uapi、`techpack/audio` 的 `apr`/`slate` 接口、`techpack/camera` 的 ioctl、`drivers/power/supply/qcom` 的 power_supply 属性名。**判据是「HAL 引用的常量/结构体/节点名在 4.19 树里是否仍在且语义一致」，不是「驱动文件是否存在」。**
3. 必须回答一个可判定的问题：**假设 4.19 树可用，哪几个闭源 HAL 会因 uapi 不匹配而失效？逐一点名并计数。**
4. 表格列固定为：`HAL 文件 | 依赖的内核接口 | 4.9 现状 | 4.19 目标(meuira) | 5.10 目标(主线) | 差异 | 闭源? | 结论`。
5. **禁止**把「blobs 里 0 个 `.ko`」（E9）当作「无需 ABI 评估」——恰恰相反：驱动全编进内核本体，意味着换内核要连驱动带 HAL 一起换，这正是 K2-03 要量化的。
6. **禁止**把「techpack 有源码」当作「HAL 兼容」——techpack 是内核侧源码，HAL 是 `vendor/lib64/hw/` 下的闭源 `.so`，中间还隔着 uapi。**方案甲「直接推翻了 HAL 全废论证」这句话我判定为过头**：正确表述是「从『必然全废』降为『待 uapi 验证』」。
7. 只读。不得跑构建、不得碰设备。

> K2-03 交付后，我把 §5.4 从「依据 E8 + 0 个 .ko」升级为「依据 E8 + HAL 逐项失效清单」，K2-04 即可正式结案。

---

## 5. 裁决正文（按 `docs/03:55` 要求：选定版本 + fallback + 为什么不是更高版本）

### 5.1 选定版本

- **Linux 4.9.337**，仓库 `LineageOS/android_kernel_xiaomi_sdm845`，分支 `lineage-22.2`，HEAD `aa8adfe9bf212c6e93238a86980b4024da4f819a`（E6/E7）。
- **可复现性判据（强制）**：`local_manifests/terminalos.xml` 现在的三条 `revision` 是**分支名不是 commit pin**（方案乙 K0 已否证「已锁固定 commit」，我采信）。因此构建流程必须满足：`repo sync` 后对内核、两个 blobs 仓各跑 `git rev-parse HEAD`，保留 `repo manifest -r` 输出，并与上列 sha 比对；不一致即中止构建并记账。**这条是构建机落地的前置，不是可选项。**

### 5.2 为什么不是 4.19（**R0 修订版**）

> **原文此处判「4.19 不可行 / 唯一公开分支是空壳」，该全称判断已被否证。** 我漏搜了社区移植树，属我的覆盖不足，不是方案甲的错。以下为修订后口径。

**5.2.1 事实更正：4.19 有真实候选，不是空壳**

| # | 事实 | 我的复现 |
| --- | --- | --- |
| E14 | `meuira/android_kernel_xiaomi_sdm845_419` 真实存在，**单分支** `lineage-23.2_xiaomi`，HEAD `5cd18f0867338fb22a497bd8e8c881b13a7d857e` | `search_repositories("user:meuira")` + `list_branches` |
| E15 | 内核版本 = **Linux 4.19.325** | 代码索引 `Makefile@5cd18f08`：`VERSION = 4 / PATCHLEVEL = 19 / SUBLEVEL = 325` |
| E16 | polaris DTS 目录存在：根目录 36 个 `.dts/.dtsi` + `battery/`(3) + `display/`(2) = **41**（方案甲报 43，差异在计数口径，不影响结论） | `get_file_contents` 三次目录列举 |
| E17 | **DTS 会被编译，不是摆设**：`arch/arm64/boot/dts/xiaomi/Makefile` 含 `polaris/polaris-p0.dtb`、`-p0-v2.dtb`、`-p1.dtb`、`-p2.dtb`、`-p2-v2.dtb`、`-p2-v2.1.dtb` 六个目标 | 代码索引命中该 Makefile 原文片段 |
| E18 | **面板驱动完整**：`drivers/video/fbdev/msm/mdss_dsi_panel.c` 有 `mdss_dsi_nt35596_read_status`；`mdss_dsi.h` 有 `ESD_REG_NT35596`；`display/dsi-panel-jdi-fhd-nt35596s-video.dtsi` 定义 `dsi_jdi_fhd_nt35596s_video` 节点；`polaris-p0.dtsi` 引用并配电源/背光/复位 GPIO | 代码索引 10 条命中，路径覆盖驱动 + dtsi + 板级引用 |
| E19 | techpack 齐全：`display` / `camera` / `camera-sdm845` / `camera-bengal` / `audio` / `data` / `video` / `video_msmnile` / `stub`；另有新增 `arch/arm64/configs/vendor/sdm845-perf_defconfig` | `get_file_contents` 目录列举 |

> **结论**：**Android 下游 4.19 路线是有人真做过的**——面板、显示、相机、音频驱动以源码形式随树提供，polaris 的 dtb 进了 Makefile。我原裁决的「4.19 无候选」与「换内核 = HAL 全废」两句，**都必须降级**。

**5.2.2 但 4.19 候选不可依赖（维持不升级的理由，已换）**

| 判据 | 实测 | 为什么算「不可依赖」 |
| --- | --- | --- |
| 维护形态 | 个人账户、**单分支**、0 fork、4 star；`pushed_at` 2026-09-28 只是重新上传 | 无组织背书、无并行维护、无 issue 追踪记录 |
| **实质活跃度** | HEAD commit `5cd18f08` 的**作者日期 2026-05-22**（距今约 5 个月）；其后无功能提交 | 相对本项目「现在就要出可刷机产物」，这是**停滞**状态 |
| 已知未修复缺陷 | `516e794d`「drivers: halls: **revert** changes — reason: **kernel panic on perseus with UAF error**」 | 树上自己记录了 kernel panic 且选择回滚而非修复 |
| 已知显示回归 | `02cf2eb9`「techpack: display: **drop** doze and fod changes for now — **they break dt2w** for some reason that i dont know」 | 显示子系统有未定位的回归，作者原话「不知道为什么」 |
| 构建/实机证据 | **无**。无 CI、无构建日志、无 polaris 上的 `uname -a` / boot 日志 / 刷机记录 | 「树能编译」≠「polaris 能开机」。本项目纪律：没有证据不算完成 |
| **是否解决真阻塞** | **否**。polaris 的 LineageOS 23.2 设备树与 blobs 不存在（`docs/00` 已证：device 仓 23.2 与 22.2 同 sha） | 内核是 23.2 缺件里的一件，不是唯一件；内核到位而设备树/blobs 缺失，23.2 依然装不起来 |

**5.2.3 裁决口径（修订后）**

- **不改方向：当前仍按 4.9.337 交付。** 理由不再是「4.19 不存在」，而是「4.19 候选存在但状态不可依赖，且升级内核不解决 23.2 设备树/blobs 这个真阻塞」。
- **4.19 树转为 Phase 1K 研究项**，不阻塞 Phase 0/构建/刷机/验收。
- **若用户指定要押 4.19**，前置门槛（缺一不可，且全部要证据）：
  1. polaris 实机 boot 到可用 UI 的日志 + `uname -a` 显示 4.19.325；
  2. 配套 23.2 设备树与 blobs 的来源与 sha；
  3. 263 条 blobs 中闭源 HAL 的 uapi 兼容性判定（即 K2-03 的产物，评估对象扩展为 4.19）。
- **我原 E8（主线面板 404）不受影响**：那是**主线**路线的结论；meuira 是 **Android 下游 fbdev/msm** 路线，两套面板框架不同，E8 不能拿来否 4.19，4.19 也不能拿来否 E8。

**5.2.4 关于「4.19 必须独立 DTBO、polaris 没 dtbo 分区所以 PoC 不能做」（方案甲 v2 前置阻塞）——方向对，推论错**

| 断言 | 我的核实 | 判定 |
| --- | --- | --- |
| polaris 无 dtbo 分区配置 | ① 本地 `init/fstab.qcom` 全文 21 行，分区只有 userdata/modem/dsp/persist/bluetooth/cache/misc/boot/recovery + 5 个 logical 分区，**无 dtbo**；② 本地 `Polaris-TerminalOS-repos` 全仓搜 `dtbo`/`SEPARATED_DTBO` **零命中**；③ 官方 polaris/common `BoardConfig` 无 `BOARD_KERNEL_SEPARATED_DTBO` | **成立**。官方 polaris 走 appended DTB（`Image.gz-dtb`） |
| OnePlus 用 4.19 布局 + 独立 DTBO | 代码索引 `android_device_oneplus_sdm845-common` 原文：`BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb`、`BOARD_KERNEL_SEPARATED_DTBO := true`、`TARGET_KERNEL_CONFIG := vendor/sdm845-perf_defconfig vendor/enchilada.config` | **成立**（方案甲此处说得对） |
| **「所以 4.19 必须独立 DTBO」** | **不成立**。meuira 树 `arch/arm64/configs/vendor/sdm845-perf_defconfig` 原文含 **`CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE=y`**；`arch/arm64/boot/Makefile` 与 `arch/arm64/boot/dts/Makefile` 都有 appended DTB 打包逻辑 | **推论被否**。独立 DTBO 是**设备树打包选项**，不是 4.19 的强制要求；OnePlus 选它是因为它有 dtbo 分区且 device 树这么配 |

> **正确的前置判据（替代方案甲的「阻塞」）**：
> 1. PoC **沿用 polaris 现有 appended 路径**（`BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb`，不启用 `BOARD_KERNEL_SEPARATED_DTBO`）——这条路不需要 dtbo 分区。
> 2. 构建期必须验证：`CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE_NAMES` 未在 defconfig 显式赋值（我查过无显式值），因此**要以实际产物为准**——产出 boot.img 后用 `unpack_bootimg` / `abootimg` 确认 dtb 确实 appended 在里面，且是 polaris 的 dtb。
> 3. 若构建结果要求走独立 DTBO，**才**需要先解决分区问题；那时 PoC 停在这一步，不得盲刷。
> 4. 因此 4.19 PoC 的 P1/P2（编译 + DTB 产物检查）**现在就可以做**，不必等 dtbo 分区确认。

### 5.3 为什么不是 5.4

- SDM845 是 pre-GKI 平台（2018 年 Android 8.1），本地 `fstab.qcom` 无 `vendor_boot`/`vendor_dlkm` 分区，GKI 的 vendor module 模型无从落地。
- 无厂商源码、无社区树。**三个候选里最空的一档**，无任何一手候选可评。

### 5.4 为什么不是 5.10+（主线 6.x/7.x）

| 理由 | 依据 | 级别 |
| --- | --- | --- |
| 面板在主线**无任何驱动认领**，DSI 不会 probe，屏点不亮 | `panel-jdi-fhd-nt35596s.c` **404**；`fhd-nt35596s` 全树唯一命中是 polaris 自己的 dts | **我亲验（E8）** |
| 换内核 = 整套闭源 HAL 报废 | blobs 263 条、`.ko` **0 个**（E9/E11）：驱动全编进内核本体，指纹双 HAL/PN553/TAS2559/SSC 全部绑 4.9 下游接口 | **我亲验（E9–E11）** |
| 充电器/电量计/声卡/ADSP/SLPI/相机/NFC/指纹/传感器节点缺失 | 方案甲 §3.3 | **待证据（B 级）**，但不影响：E8 已使「能开机看到画面」不成立 |
| 设备包已归档、maintainer 空，需自行接手维护 | Nura/pmaports | **参考级** |
| 必须放弃 Android，改做 Linux 发行版 | 由前两条直接推出 | 逻辑结论 |

> **判断**：5.10+ 不是「工作量大的候选」，而是**「换产品」**。TerminalOS 的交付物是 Android + Termux 终端机；走主线就不存在 Termux，也不存在 LineageOS。这**超出 K2-04 的技术裁决权限**，需用户书面决策。

---

## 6. 状态表（交 首席 拍板）

| 事项 | 状态 | 依据 / 下一步 |
| --- | --- | --- |
| K2-01 候选源码调研 | **v2 可验收（附 A7/A8 两处口径修正）** | v2 已修正 §2.1（官方层 / 社区层分开写），§3.1「HAL 全废」已降级并自带「techpack 不覆盖指纹/传感器/Keymaster/ICE」的反向限定，§0 有修正声明与错因记录。**A1–A6 大部分满足；A7（dtbo 因果链）、A8（OnePlus 双配置）需改**。**此项我同责**：我 §2.1 也下过同样的全称判断。 |
| 4.19 PoC 任务（方案甲 v2 新增建议） | **采纳方向，但判据按我 §5.2.4 改写** | P1 编译 / P2 DTB 产物检查可**现在做**（不依赖设备、不依赖 dtbo 分区）；P3 起点亮起必须等 Phase 0 + 首席。方案甲原「P3 起排队」对，但「P3 根本不该做因为没 dtbo 分区」这个理由错，见 A7。 |
| K2-02 驱动覆盖评估 | **可验收（限 5.10 主线口径）** | §3.4 覆盖 13 项；等级级工作量。B 级节点清单不影响裁决。**但 §3.4 只评了主线，未评 4.19 下游**——需在 K2-01 返工时补一列「4.19 下游（meuira 树）覆盖」。 |
| K2-03 ABI 评估 | **待交付** | 方案乙，判据见 §4.1（**已扩展评估对象：4.19 优先于 5.10**） |
| K2-04 候选裁决 | **方向性预裁决：维持 4.9.337（含 R0 修订）；正式结案待 K2-03** | 本文件 §5，修订记录见 §9 |
| 方案甲 K2 报告口径 | **v2 已达标；仅剩 A7/A8 两处口径** | R1/R2/R3 在 v2 中已改：§2.1 反转并记录错因、§3.1 降级「HAL 全废」、§0 有修正声明。**剩余**：A7 dtbo 因果链、A8 OnePlus 双配置漏列。见 §9.3 |
| K3-01 内核分支创建与编译脚本 | **建议 首席 改写任务目标，不是取消** | 目标「升级内核」消失，但「可复现构建」需求仍在 → 改为「22.2 commit pin + `repo manifest -r` 留档 + 构建脚本按 5.1 校验」。**任务表改动属 首席，我不改表。** |
| K4-01 最终版本裁定 | **blocked**，口径已建议 | 若 K2-04 结案，记「平台移植目标，内核维持 4.9.337，未做升级」，**不得宣称内核已升级** |
| 构建机（P0-08）/ 设备 Phase 0 | 不受本裁决影响 | 由 首席 推进；**Phase 0 完成前禁止任何刷写** |

---

## 7. 我未能确证、也不得当成已确认的

1. **设备当前实际运行的内核**（说明书称 iOS16 移植系统）。`adb` 不在线，源码版本 **不能** 代替 `uname -a` / `/proc/config.gz`。只由 首席 在 Phase 0 采集。
2. 「高通无 SDM845 4.19/5.4 发布」——**未确证**（R2）。裁决不依赖它。
3. §2 表内全部 B 级 / 参考级项，均未经我独立复现。
4. 5.10+ 路线下 TAS2559、ICE、Keymaster/QSEE 是否有替代实现——现状是**还轮不到讨论**（E8 已否掉显示）。

---

## 8. 复现入口

```powershell
# E1/E2：4.19 空壳（比对 tag 的 object.sha，不是 tag-object sha）
#   get_tag(torvalds/linux, v4.19).object.sha        -> 84df9525b0c27f3ebc2ebb1864fa62a97fdedb7d
#   list_branches(LineageOS/android_kernel_oneplus_sdm845) lineage-23.2 -> 84df9525...
#   （tag-object sha 是 2241b8bc，比对错项会得出"不同"的错误结论）

# E4/E5：Android 16 分支沿用 4.9.337
#   list_branches(LineageOS/android_kernel_sony_sdm845) lineage-23.0 == lineage-22.2 == 1a8fc01d
#   代码索引 repo:LineageOS/android_kernel_sony_sdm845 filename:Makefile PATCHLEVEL -> 4/9/337

# E6/E7：xiaomi 无 23.x，最高 22.2 = aa8adfe9
#   list_branches(LineageOS/android_kernel_xiaomi_sdm845)

# E8：主线面板无驱动
#   get_file_contents(torvalds/linux, drivers/gpu/drm/panel/panel-jdi-fhd-nt35596s.c) -> 404
#   search_code("repo:torvalds/linux fhd-nt35596s") -> total_count=1, 仅 polaris.dts

# E9-E11：本地 blobs
$d = 'C:\AiWork\Polaris-TerminalOS-repos\android_device_xiaomi_polaris'
(Get-Content "$d\proprietary-files.txt" | Where-Object { $_.Trim() -ne '' -and $_.Trim() -notmatch '^#' }).Count   # 263
(Get-Content "$d\proprietary-files.txt" | Select-String '\.ko$').Count                                           # 0

# E12：docs/09 原文（务必 UTF-8 读，GBK 会读成乱码误判）
Get-Content -LiteralPath 'C:\AiWork\Polaris-TerminalOS\docs\09_内核升级评估_K0.md' -Encoding UTF8 | Select-Object -Index 18..21
```

## 9. R0 修订记录（裁决自我更正）

### 9.1 我错在哪里

| 原表述（本文件 v1） | 事实 | 性质 |
| --- | --- | --- |
| §0/§5.2：「**唯一**公开的 SDM845 4.19 分支是 vanilla 空壳」 | 存在 `meuira/android_kernel_xiaomi_sdm845_419`，Linux 4.19.325，含 polaris 41+ 个 DTS、dtb 入 Makefile、完整面板驱动、techpack 全套（E14–E19） | **全称判断错误**。我的搜索只覆盖了 LineageOS 官方组织，未覆盖个人/社区移植树，就下了「唯一」。 |
| §3.1 引用块：「换内核 = 这套 HAL 全部失效」 | techpack 以源码形式随 4.19 树提供，内核侧接口有实现 | **过头论证**。应为「从『必然失效』降为『待 uapi 验证』」。 |
| §1 E1–E3 的**事实**本身 | `v4.19` tag object.sha == OnePlus `lineage-23.2` HEAD，仍是事实 | **无错**。错的是从它推出「唯一/全部」。 |

> **裁决方向不变，但依据已换**：维持 4.9.337 的理由，从「4.19 不存在」改为「4.19 候选存在但不可依赖（单分支个人仓、实质提交停滞 5 个月、自带未修复 kernel panic 与显示回归、零构建/实机证据），且升级内核不解决 23.2 设备树与 blobs 缺失这个真阻塞」（§5.2.2）。

### 9.2 教训（写成判据，防复发）

1. **全称判断（「唯一」「全部」「都不存在」）必须写清搜索面**：至少覆盖 `LineageOS/*`、`*/*_sdm845*`、社区组织（`sdm845-mainline`）、以及个人账户（`user:` 搜索）。**未覆盖的面必须写成「在我搜到的范围内」，不得写「唯一」。**
2. **「文件存在」三层递进，缺一层不算数**：① 文件在树里 → ② 被 Makefile/Kconfig 引用（会真编译） → ③ 有构建产物或实机日志。我在 E16→E17 做了 ②，③ 目前**对 meuira 树完全空缺**。
3. **判断「某路线可行」时，先问「它解决的是不是目标阻塞」**。内核版本不是 23.2 的阻塞，设备树与 blobs 才是。

### 9.3 对 方案甲 的更新后返工判据

在其重写 `K2_CANDIDATES_C_O5.md` 后按此复核：

| # | 要求 |
| --- | --- |
| A1 | §2.1 **必须反转**，且要给出 meuira 树的仓库 URL、分支、HEAD commit、版本号（4.19.325）、polaris DTS 数、techpack 目录清单——**每项带可复现查询**，不能只写「存在」 |
| A2 | **必须补「不可依赖」的量化**：最后实质提交日期、已知未修复缺陷（`516e794d` perseus UAF panic、`02cf2eb9` dt2w 回归）、无构建/实机证据。只写「有树」是单边论证 |
| A3 | §3.4 驱动覆盖表**加一列「4.19 下游」**——你现在只评了主线。4.19 是本项目唯一活的下游候选，它的覆盖必须逐项 |
| A4 | 「直接推翻了 HAL 全废」这句话**必须改**：techpack 是内核侧源码，HAL 是闭源 `.so`，中间隔着 uapi。改为「从必然降为待验证」，并指向 K2-03 |
| A5 | 原 R1/R2/R3 仍有效：**不要**再把「docs/09 有乐观解读」写进新版本（原文 :19-22 本就是保守立场）；「高通无 SDM845 4.19 发布」是 [疑]，**现在有了 meuira 树更不能再当裁决理由**；「Android 16 不需要新内核」表述收到「Sony `lineage-23.0` 与 `22.2` 同 commit，未强制升级」 |
| A6 | 必须明确区分**两条面板路线**：主线 DRM panel（E8：`panel-jdi-fhd-nt35596s.c` 404）vs Android 下游 fbdev/msm（E18：`mdss_dsi_nt35596_read_status` 存在）。**两者不可互相否证** |
| **A7** | **关于 dtbo 的因果链必须改**：正确写法是「polaris 官方走 appended DTB（无 dtbo 分区、无 `BOARD_KERNEL_SEPARATED_DTBO`）；meuira 4.19 树的 `sdm845-perf_defconfig` 含 `CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE=y`，**可走 appended 路径，不需要 dtbo 分区**。仅当构建结果强制独立 DTBO 时才是阻塞」。**不得写「4.19 用独立 DTBO，polaris 没分区，所以 PoC 不能做」**——这是从 OnePlus 的配置外推，跳步了 |
| **A8** | **修正一条新引入的说法**：LineageOS oneplus 树**同时**有 `BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb` **和** `BOARD_KERNEL_SEPARATED_DTBO := true`。你写「oneplus 那棵已经是 4.19 布局（SEPARATED_DTBO）」时漏了 appended 仍在，容易被读成「4.19 只能分离 DTB」。请把两行都列出来 |
| **A9** | v2 §3.1 的修正**我认可**，而且你补的「techpack 不覆盖指纹/传感器/Keymaster/ICE，所以 4.19 PoC 验收重点正是这几个」比我的要求更细，保留 |

---

本文件为复核官唯一写入产物。未越范围、未代改他人实现、未碰设备。
