# K2-01 / K2-02 独立研判：内核候选来源与驱动覆盖差距（方案甲）

- 时间：2026-10-28（Asia/Shanghai）
- 方法：只读。本地 Git 工作树 + GitHub REST/代码索引（固定 commit/blob）+ GitLab API。**未执行 adb、未 boot、未刷写、未构建。**
- 范围：K2-01（真实可访问仓库与 commit）、K2-02（SDM845 驱动覆盖差距）。裁决属复核官，本文件只给候选与判据。
- 证据强度标注：**[确]** 有可复现的命令输出或固定 commit/blob 原文；**[疑]** 有间接证据但未直接验证；**[否]** 已被证据否证。

---

## 0. 结论先行

> **⚠️ 本文件已修正一次。** 初版把 4.19 判为「已否证可用」，理由只查了 LineageOS **官方**组织下的仓库。
> 社区 fork 存在真实的 4.19.325 移植且**已包含 polaris**（§2.1）。该否证结论已撤回，见 §2.1 的修正声明。

1. **[确] 官方层面：SDM845 没有厂商 4.19/5.4。** CAF msm-4.19/5.4 的 `arch/arm64/configs/vendor/` 里都没有 sdm845
   （有 bengal/kona/lito/msm8937/sdm660，没有 845）；CAF msm-4.9 才有 `sdm845_defconfig`。
   LineageOS 官方给 oneplus sdm845 开的 `lineage-23.2` 分支是**上游 vanilla v4.19 tag 本身**（sha `84df9525` 与
   `torvalds/linux` 的 `v4.19` tag 完全一致），零厂商代码（§2.1.1）。
2. **[确] 社区层面：4.19.325 移植真实存在，polaris 有完整设备树。**
   `meuira/android_kernel_xiaomi_sdm845_419` @ `lineage-23.2_xiaomi` = **Linux 4.19.325**，
   `arch/arm64/boot/dts/xiaomi/polaris/` 下 **43 个 polaris DTS**、`vendor/xiaomi/polaris.config`、
   `vendor/sdm845-perf_defconfig`，且 **`techpack/` 完整**（display/camera-sdm845/audio/data/video）（§2.1.2）。
   同源活跃树至少 4 个（共同上游 `duckyduckG`），其中 `EdwinMoq@lineage-24.0` 是 **LineageOS 官方 oneplus 设备树
   所需配置的实际来源**；迁移者有 LineageOS 官方 committer 参与（§2.1.3）。
3. **[确] techpack 缓解但**不**「推翻」HAL 风险（v4 措辞已改）。** 下游 4.19 把 display/camera/audio 的厂商驱动
   以源码随树走，所以闭源 HAL 的**内核接口大概率还在**；但 techpack 是内核侧源码、HAL 是 `vendor/lib64/hw/` 的闭源 `.so`，
   中间隔着 **uapi**。风险等级从「必然全废」降为**「待 uapi 验证」**——不是「已可迁移」（§3.1）。
4. **[确] 平台级已有 4.19 真机启动证据；设备级（polaris）仍无。**
   `AlexFurina/kernel_samsung_sdm845-419` commit `b24e86503d40…` 贴出
   `Linux version 4.19.113 … Machine model: Samsung STARQLTE`（Galaxy S9，SDM845）真机日志
   → 证明 **4.19 能跑在 845 硬件上**。但**不是 polaris，不得外推**：
   43 个 polaris DTS 是从 Xiaomi 4.9 源码搬进 4.19 的，DT binding 差异会导致编译或 probe 失败。
   且 LineageOS **官方小米设备树仍未迁移**（仍 `vendor/xiaomi/mi845_defconfig`）（§2.1.3）。
   **注意判据**：`vendor/` 子目录不是 4.19 标志（4.9 树也有）；正确判据是 `mi845_defconfig` 是否存在（§2.1.2b）。
5. **[确] 主线（5.10+/6.x/7.x）路线对 polaris 不可用**：polaris 的 dts 在主线是半成品——
   面板 `jdi,fhd-nt35596s` **无任何驱动认领**、`pmi8998_charger` 未使能、主线**全树无 pmi8998 电量计**、
   **无声卡节点**、`&adsp_pas`/`&slpi_pas` 未使能（§3.3）。设备包也已于 2026-07-19 归档无人维护（§2.2）。
6. **[确] Android 16 分支未强制内核升级。** 证据：同平台 Sony SDM845 的 `lineage-23.0` 与其 `lineage-22.2`
   **同 commit、`Makefile` 未做任何改动**，实测仍是 **Linux 4.9.337**（§4）。
   推论（不超出证据）：内核升级**不是** Android 16 移植的前置必要条件。
   ~~「Android 16 根本不需要新内核」~~——此全称表述过强，已按 复核官 意见收窄。
7. **建议裁决（交复核官）**——三条一起看：
   - **deliverable 目标版本**：**维持 4.9.337**。理由：唯一与现有 blobs/设备树/官方支持完全配套；且内核升级不是 23.2 的前置（§4）。
   - **新增一个独立 PoC 任务**：验证 `meuira` 4.19.325 树能否**为 polaris 编译出可启动的 boot/dtbo**。
     这是**唯一值得投入的升级方向**，但必须以「能不能点亮」为准，不能以「仓库存在」为准。PoC 失败则 K2 闭环为「不升级」。
   - **主线路线**：判定不可行，除非用户愿意换产品形态（放弃 Android + 当无人维护设备口接盘维护者 + 从零补面板/充电/声卡驱动）。

---

## 1. 现状基线（本次重新实证，不引用 wiki）

| 项 | 实测值 | 证据 |
| --- | --- | --- |
| 内核版本 | **Linux 4.9.337** | `LineageOS/android_kernel_xiaomi_sdm845` @ `aa8adfe9bf212c6e93238a86980b4024da4f819a` 的根 `Makefile`：`VERSION = 4` / `PATCHLEVEL = 9` / `SUBLEVEL = 337`（GitHub 代码索引返回原文片段） |
| 内核仓库最高分支 | `lineage-22.2`，**无 23.x/24.x** | `list_branches` 全量 18 个分支，最高 `lineage-22.2` = `aa8adfe9…`；`lineage-21`/`22.0`/`22.1` 同为 `88606771…`（冻结） |
| 目标 defconfig | `vendor/xiaomi/mi845_defconfig` + `vendor/xiaomi/polaris.config` | 公共树 `BoardConfigCommon.mk` 定 `TARGET_KERNEL_CONFIG := vendor/xiaomi/mi845_defconfig`、`TARGET_KERNEL_SOURCE := kernel/xiaomi/sdm845`；本地 `BoardConfig.mk:19` 追加 polaris 片段（方案乙 K0 已核，本文采信并复用） |
| boot 镜像结构 | header v1、`Image.gz-dtb`（DTB 附加在内核镜像后） | 公共树 `BOARD_BOOT_HEADER_VERSION := 1`、`BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb`（方案乙 K0 已核） |
| 分区布局 | **非 A/B + 动态分区**，独立 boot/recovery | 本地 `init/fstab.qcom:6-19`：`system`/`vendor`/`product`/`odm`/`system_ext` 带 `logical,first_stage_mount`；`boot`、`recovery` 为 `emmc` + `recoveryonly`；无 `_a`/`_b` 后缀 |
| 数据加密 | `fileencryption=ice` | `init/fstab.qcom:11`。ICE = 高通 Inline Crypto Engine，依赖下游内核的 ICE 驱动与 UFS 集成 |
| 专用固件分区 | `modem`、`dsp`、`bluetooth`、`persist` | `init/fstab.qcom:12-15`，分别挂到 `/vendor/firmware_mnt`、`/vendor/dsp`、`/vendor/bt_firmware`、`/mnt/vendor/persist` |
| blobs 来源 | **MIUI V12.0.3.0.QDGMIXM 全球稳定版**（Android 10 期） | 本地 `proprietary-files.txt:1` 注释原文 |
| blob 条目数 | 263 条（非注释行） | `proprietary-files.txt` 统计 |

> **[确] 关键推论**：blobs 取自 Android 10 期 MIUI，针对 4.9 下游内核编译。
> 这是后面所有「换内核即废 HAL」判断的根据，不是推测。

---

## 2. K2-01：候选来源逐条核实

### 2.1 Linux 4.19（Android 下游路线）——**[确] 社区移植真实存在，polaris 在其中（本版已修正）**

> **⚠️ 修正声明**：本节初版结论为「**[否] 已否证可用**」，理由是「LineageOS 唯一公开的 SDM845 4.19 分支是 vanilla tag」。
> **该结论是错的，现撤回。** 错因：我只查了 **LineageOS 官方组织**下的仓库，把「官方没有」当成「不存在」，
> 漏掉了社区 fork。实际上社区 4.19 移植真实、活跃，而且**已经包含 polaris**。
> 下面分「官方状态」与「社区状态」两层重写。

#### 2.1.1 官方（CAF / LineageOS）层——**[确] 确实没有 SDM845 的 4.19**

> **证据分级说明（v5 升级，按 复核官 要求）**：
> - LineageOS 部分 = **一手 [确]**（我直接 `list_branches` / `get_tag` 比对 sha）。
> - CAF 部分 = **可复现（GitLab API，project id + ref 已给出）**：
>   我本人访问 `git.codelinaro.org` 时返回 **HTTP 429 限流**，未能自取；但独立调研路已通过 GitLab API 直取到
>   **defconfig 目录原文**，并把仓库 project id 与 ref 全部给出（见下表），任何人可用
>   `GET /api/v4/projects/<id>/repository/tree?path=arch/arm64/configs/vendor&ref=<ref>` 复现。
>   **阳性对照成立**：同一 `?search=sdm845` 参数在 msm-4.9 上正常返回大量命中，而在 4.19/5.4/5.10/5.15 上返回空数组，
>   证明空结果是真实的「无」而非查询失效。
> - 结论：**CAF 无 SDM845 的 4.19/5.4 可判定为 [确]**。但按 复核官 意见，§5.1 裁决理由仍**不依赖**这条——
>   裁决只依赖 LineageOS 一手证据与社区证据，CAF 这条作为**加强证据**列出。
>
> **另一条对交付有正面意义的事实**：SDM845 的 CAF 4.9 线**至今仍在收安全补丁**——
> 最新 tag `LA.UM.8.3.c25-13000-sdm845.0` 的 target commit `1a01f77fdafb…` 日期为 **2026-08-24**。
> 说明高通把 845 的维护一直留在 4.9、没有迁移，这对「维持 4.9.337」的裁决是**支持性证据**。

| 检查 | 结果（ref 已给出，可复现） |
| --- | --- |
| 高通 CAF msm-4.19 的 `arch/arm64/configs/vendor/` | project id **13110**，ref `kernel.lnx.4.19.r37-rel`：bengal, bengal-lite, kona, kona-iot, lito, msm8937, sdm660 —— **无 sdm845** |
| 高通 CAF msm-5.4 | project id **22241**，ref `kernel.lnx.5.4.r1-rel`：autogvm, bengal, direwolf_auto, gen3auto, genericarmv8-64, holi, lahaina, sa2150p, sdmsteppeauto —— **也无 sdm845** |
| 高通 CAF msm-5.10 / msm-5.15 | project id 29371 / 53431，`?search=sdm845` 均返回 `[]`；tag 命名已改为 `KERNEL.PLATFORM.*` |
| CAF msm-4.9 | project id **12600**，`?search=sdm845` **大量命中**；`LA.UM.8.3.c25-13000-sdm845.0` 顶层即有 `sdm845_defconfig` + `sdm845-perf_defconfig` |
| LineageOS xiaomi sdm845 内核仓库 | **无** 4.19 分支，最高 `lineage-22.2`（4.9.337）**[确]** |
| LineageOS oneplus sdm845 内核仓库 | 有 `lineage-23.2`，HEAD = `84df9525b0c27f3ebc2ebb1864fa62a97fdedb7d`**[确]** |
| 该分支内容 | `get_tag(torvalds/linux, v4.19)` 的 `object.sha` **也是** `84df9525…` → 该分支 = **上游 vanilla v4.19 tag 本身，零厂商代码**，是占位分支**[确]** |

→ **官方层面**：厂商内核止于 4.9；LineageOS 官方的 4.19 迁移**尚未落地**（开了空分支）。

#### 2.1.2 社区层——**[确] 4.19.325 移植真实，polaris 有完整设备树**

| 仓库 | 关键事实 | 证据强度 |
| --- | --- | --- |
| **`meuira/android_kernel_xiaomi_sdm845_419`**<br>分支 `lineage-23.2_xiaomi`，HEAD `5cd18f0867338fb22a497bd8e8c881b13a7d857e` | **Linux 4.19.325**（根 `Makefile`：`VERSION = 4` / `PATCHLEVEL = 19` / `SUBLEVEL = 325` / `NAME = "People's Front"`）**[确]** | 一手：GitHub contents API 取回 base64 原文解码 |
| 同上 · polaris 设备树 | `arch/arm64/boot/dts/xiaomi/polaris/` 下 **43 个 DTS**，含 `polaris-p0/p1/p2/p3/mp.dts`、`-v2`、`-v2.1`、`-overlay.dts` 等量产版本变体 **[确]**。**计数口径（与 复核官 对齐）**：根目录 **38** 个文件 + `battery/` **3** 个（`batterydata-d5-atl-3400mAh` / `-d5-cos-3400mAh` / `-itech-3020mAh`）+ `display/` **2** 个（`dsi-panel-jdi-fhd-nt35596s-video.dtsi` / `dsi-panel-ebbg-fhd-ft8716-video.dtsi`）= **43**。复核官 数到 41 是根目录少计 2 个，不是口径分歧 | 目录列举（三个目录各列一次，可复现） |
| 同上 · 配置 | `arch/arm64/configs/vendor/xiaomi/` 下有 `polaris.config`(526 B)、`beryllium`、`dipper`、`equuleus`、`perseus`、`ursa`、`lxc`、`sdm845-common.config`；且 `vendor/sdm845-perf_defconfig` **存在** **[确]**。**注意：没有 `mi845_defconfig`**，见下方「4.19 判据更正」 | 目录列举 |
| 同上 · **techpack** | `techpack/` 完整：`display`、`camera-sdm845`、`camera`、`audio`、`data`、`video`、`stub` 等 **[确]** | 目录列举 |
| 同上 · 实际开发痕迹 | 提交含「Audio: dsp: apr_elliptic: Update driver to support parameter v2」「drivers: halls: Update wakeup source **for 4.19**」「power: supply: qcom: idtp9220」等，作者 duckyduckg，2026-05 **[确]** | `list_commits` |
| `duckyduckG/android_kernel_qcom_sdm845_419` | 分支 `lineage-23.2`，4.19.325，**无 xiaomi 的 dts**（`arch/arm64/boot/dts/` 下无 `xiaomi` 目录）。它是**平台共享树** | 目录列举 |
| `android_device_oneplus_sdm845-common`（LineageOS 官方） | `BoardConfigCommon.mk`：`TARGET_KERNEL_CONFIG := vendor/sdm845-perf_defconfig vendor/enchilada.config`；`BOARD_KERNEL_SEPARATED_DTBO := true` **[确]** | 代码索引原文片段 |
| `android_device_xiaomi_sdm845-common`（LineageOS 官方） | `BoardConfigCommon.mk`：`TARGET_KERNEL_CONFIG := vendor/xiaomi/mi845_defconfig`，**未迁到 4.19 的 base+fragment 写法** **[确]** | 代码索引原文片段 |

#### 2.1.2b 「4.19 判据」更正——`vendor/` 子目录**不是** 4.19 专有

> **⚠️ 本条为 v5 更正。** 我 v4 及之前写过「`vendor/` 子目录 + 独立 DTBO 是 4.19 专有布局」。**这句是错的，现撤回。**
> 独立调研路（并行第二路）自查时发现，我随即亲自复核确认。

**实际枚举结果（均为我自己调 `get_file_contents` 所得）**：

| 树 | `arch/arm64/configs/vendor/` |
| --- | --- |
| 4.9 `LineageOS/android_kernel_xiaomi_sdm845@lineage-22.2` | msm8937/msm8953/qcs605/sdm670/**sdm845**(±perf) + **`xiaomi/` 子目录** |
| 4.9 `LineageOS/android_kernel_oneplus_sdm845@lineage-22.2` | 同上芯片集 + `debugfs.config`，**但没有任何 `enchilada*` 文件** |
| 4.19 `duckyduckG/android_kernel_qcom_sdm845_419` | CAF 原样 bengal/kona/lito/msm8937/sdm660 集 + **新增 `sdm845-perf_defconfig`** |
| 4.19 `meuira/…_419@lineage-23.2_xiaomi` | 同 duckyduckG，另有 `xiaomi/` 子目录 |

→ **`vendor/` 目录在 4.9 树里就存在，`vendor/xiaomi/` 子目录也在。** 拿它当 4.19 判据会误判。

**真正的 4.19 判据（可复现、二值）——基础 defconfig 换了文件**：

| 设备族 | 4.9 树 | 4.19 树 | 判据 |
| --- | --- | --- | --- |
| xiaomi（polaris/beryllium…） | 基础 = `vendor/xiaomi/mi845_defconfig`（**存在**） | 基础 = `vendor/sdm845-perf_defconfig`（**`mi845_defconfig` 不存在**） | `mi845_defconfig` 是否存在 |
| oneplus（enchilada） | `vendor/enchilada_defconfig`，**4.9 的 `vendor/` 里没有 `enchilada.config`** | `vendor/sdm845-perf_defconfig` + `vendor/enchilada.config` | `vendor/enchilada.config` 是否存在 |

**为什么这条重要**：LineageOS 官方 oneplus 设备树现在写的是
`vendor/sdm845-perf_defconfig vendor/enchilada.config`——**这个组合在 4.9 树里凑不齐**（缺 `enchilada.config`），
只在 4.19 fork（如 `EdwinMoq/android_kernel_oneplus_sdm845@lineage-24.0`）里齐备。
同理，polaris 要用 4.19，设备树的 `TARGET_KERNEL_CONFIG` 必须从 `vendor/xiaomi/mi845_defconfig`
改成 `vendor/sdm845-perf_defconfig`，否则 4.19 树的 base config 匹配不上。**这是 K3-01P P1 的第一步具体动作。**

> 另外纠正我另一处夸张：`vendor/sdm845-perf_defconfig` **单独存在不能证明 4.19**——4.9 的两棵树里都有这个文件。
> 必须与 per-device fragment 组合起来看。这条也是第二路自查时自己纠正的，我复核后确认。

#### 2.1.3 这条线索改变什么、不改变什么

**改变（推翻我初版结论）**：
- 4.19 不再是「无候选」。**存在一个把 Xiaomi sdm845（含 polaris）搬到 4.19.325 的真实社区树**，
  且带 techpack——这条与我原先「换内核即 HAL 全废」的推断冲突（§3.1 已改为「待 uapi 验证」）。
- LineageOS 官方 oneplus 设备树**已经改成 4.19 的 base+fragment 配置组合**（见 §2.1.2b 的正确判据），
  说明 4.19 迁移是社区既定方向，不是我的臆测。
- **社区 4.19 生态比 meuira 单个仓库健康得多**（第二路核实）：
  | 仓库 | 分支 | HEAD | 版本 | 状态 |
  | --- | --- | --- | --- | --- |
  | `duckyduckG/android_kernel_qcom_sdm845_419` | `lineage-23.2` | `59b19a4f84d5…` | 4.19.325 | 活跃，**平台共享树**（共同上游） |
  | `EdwinMoq/android_kernel_oneplus_sdm845` | `lineage-24.0` | `fd0476c96a3b…` | 4.19.325 | **活跃，LineageOS 官方 oneplus 设备树所需配置的实际来源** |
  | `meuira/android_kernel_xiaomi_sdm845_419` | `lineage-23.2_xiaomi` | `5cd18f086733…` | 4.19.325 | 半活跃，**唯一同时有 polaris+beryllium 的** |
  | `AlexFurina/kernel_samsung_sdm845-419` | `wip` | `0de636554f21…` | **4.19.113** | 非常活跃，三星 S9/S9+/Note9 |
- **4.19 在 SDM845 硬件上确实能 boot，有真机日志**：`AlexFurina` 仓库 commit `b24e86503d40…`（2026-10-25）
  的 commit message 贴了 `Linux version 4.19.113-gb758dc562b81-dirty ... clang version 9.0.9 ... #42 SMP PREEMPT`
  + `Machine model: Samsung STARQLTE CHN PROJECT Rev14`（STARQLTE = Galaxy S9，SDM845）。
  这证明的是**「4.19 能跑在 845 上」**这个平台级命题，**不是 polaris 能跑**。
- 迁移不是无关第三方魔改：`duckyduckG` 的提交出现在 `LineageOS/android_kernel_xiaomi_sdm845` 的 `lineage-22.2` HEAD 中，
  即**有 LineageOS 官方 committer 参与的在途迁移**。

**不改变（仍然成立的限制）**：
1. **polaris 是否能真启动，仍然没有任何证据。** 43 个 DTS 存在 ≠ 能编译 ≠ 能启动。这些 dts 是从 Xiaomi 4.9 源码搬进 4.19 的，
   4.9 的 DT binding 与 4.19 差异会导致编译失败或 probe 失败。
   **已验证的 4.19 启动日志是 Samsung STARQLTE，不是 polaris —— 不能外推。**
2. **LineageOS 官方的小米设备树没有迁移**（仍是 `vendor/xiaomi/mi845_defconfig`）。要用 4.19 必须自己改 `TARGET_KERNEL_CONFIG`
   （§2.1.2b 给了具体动作），且 4.19 走独立 DTBO 布局，而 polaris 的 `fstab.qcom` 里没有 dtbo 分区条目。
3. **meuira 仓库本身维护信号弱**：2026-09-28 一次推送的快照式仓库，0 star / 0 fork / 无 CI，
   HEAD commit 作者日期 2026-05-22，实质停滞约 5 个月。树上有已知未修缺陷（perseus UAF panic、display 删 doze/fod 破坏 dt2w）。
   缓解因素：它有三个更活跃的同源上游（duckyduckG / EdwinMoq 系）。
4. 仍然没有 blobs 侧的 4.19 适配证据（vendor blobs 来自 MIUI Android 10 / 4.9 期）。
   techpack 让**内核侧**驱动可用，但闭源 HAL 的 uapi 是否对得上，仍需 K2-03 + 实机验证。
5. **社区没有 5.4 / 5.10 的 Android 厂商式移植**（第二路未搜到），社区努力集中在 4.19。

**净判断**：4.19 从「**不可行**」上调为「**唯一值得做 PoC 的升级候选，平台级可行性已有他机证据、设备级仍未验证**」。
判据是「有没有人能把它点亮」，不是「仓库在不在」——所以建议用**独立 PoC** 验证，而不是直接并入交付线。

### 2.2 Linux 5.10+ / 主线——**[确] 真实存在，但不是 Android 路线**

| 项 | 实测值 | 证据 |
| --- | --- | --- |
| polaris 设备树在上游主线 | **存在** `arch/arm64/boot/dts/qcom/sdm845-xiaomi-polaris.dts` | GitHub 代码搜索命中 `repo:torvalds/linux`，唯一结果 |
| 引入提交 | `be497abe19bf`「arm64: dts: qcom: Add support for Xiaomi Mi Mix2s」 | 由后续多条 `Fixes:` 行反查确认 |
| 仍在维护 | 最近提交 `38458f12419f`（2026-09-15 作者日期，2026-09-28 合入），`Cc: stable@vger.kernel.org`，扩大 `xbl_mem` 区域 | `list_commits` 该文件历史 |
| 面板 | dts 有节点 `compatible = "jdi,fhd-nt35596s"`，但**主线无任何驱动认领**（详 §3.3.1） | dts 原文 + panel Kconfig/match 表穷尽核实：全树仅此一处出现该 compatible，`panel-jdi-fhd-nt35596s.c` 与 `panel-novatek-nt35596s.c` 均 404 |
| 触摸 | `syna,rmi4-i2c`（Synaptics RMI4，400 kHz I²C）；驱动在树里但**未进 arm64 defconfig** | dts 原文片段：`touchscreen@20 { compatible = "syna,rmi4-i2c"; reg = <0x20>; ...}`；`CONFIG_RMI4` 在 defconfig 零命中 |
| 社区内核树 | `https://gitlab.com/sdm845-mainline/linux`，默认分支 `sdm845/7.1-dev`，HEAD `85f1df2a`（2026-05-08），仓库活动至 2026-10-22 | GitLab API |
| 内核版本 | **Linux 7.1-rc1**（tag `sdm845-7.1-rc1-r0`）；tag 节奏 6.16.7→6.18.2→7.1-rc1，约 3–5 个月一次 | GitLab API + pmOS APKBUILD |
| 发行版打包 | Nura（原 postmarketOS）`linux-postmarketos-qcom-sdm845`，`pkgver=7.1_rc1` / `pkgrel=4` | `gitlab.postmarketos.org/postmarketOS/pmaports` main 分支 APKBUILD 原文 |
| **polaris 设备包状态** | **已归档**。提交 `5e6995c5`（2026-07-19）移入 `device/archived/`，APKBUILD 首行 `# Archived: Maintainer is inactive and has no pmOS GitLab account`，`maintainer=""` | 同上 |
| 新通用 UEFI/U-Boot 口 | `qualcomm-sdm845` **不含 polaris**（仅 enchilada/fajita/starqltechn/shift-axolotl/beryllium） | Nura wiki SoC 页 |

> **[确] 注意陷阱**：`gitlab.com/postmarketOS/pmaports` 是**过期镜像**（仍返回 200，但 `pkgver=1`、路径在 `device/testing/`），
> 权威仓库 2024-10 已迁至自建 `gitlab.postmarketos.org`（`pkgver=10`）。按旧地址查会得出「polaris 仍在 testing 维护中」的错误结论。
> postmarketOS 已于 2026-09-27 改名 **Nura**，`wiki.postmarketos.org` 302 跳 `wiki.nura.eco`。

### 2.3 Linux 5.4 / GKI——**[确] SDM845 在 GKI 支持矩阵之外（三条独立证据）**

> **证据来源声明（v7：证据已落盘进项目，可核）**
> 本节 AOSP 原文由并行第二路子代理抓取（本机 `web_fetch` 对该域名报 `SEC_E_NO_CREDENTIALS`）。
> **原始副本已从临时工作区移入项目仓**：
> `_reviews/_evidence/gki_research/`（`raw/` 41 个 txt + 7 个被引用页面的原始 HTML + 抓取脚本 + 报告），
> 完整清单与逐条核对见 `_reviews/_evidence/gki_research/MANIFEST.md`。
> 下列每条引文我都在落盘副本上重新 `grep`/`read` 过，行号与原文逐字比对无误，HTML 有 sha256 可验未被改动。

| 引文 | 文件 : 行号 | 原句（逐字） |
| --- | --- | --- |
| "Any 5.10 and higher ACK kernel (aarch64 only)" | `raw/kernel_overview.txt` : **469** | `Any 5.10 and higher ACK kernel(aarch64 only). The GKI kernel has these` |
| "vendor_dlkm and odm_dlkm ... located in the super partition" | `raw/vendor_odm_dlkm.txt` : **440** | `vendor_dlkm and odm_dlkm partitions are located in the super partition as` |
| "boot image header version 3" | `raw/vendor_boot.txt` : **425** | `11 devices can use boot image header version 3. In` |
| "For devices launching with Android 10, create a partition called super" | `raw/dynamic_partitions.txt` : **410-411**（折行，完整一句跨两行） | `For devices launching with Android 10, create` / `a partition called super. The super` |

> **关于 `super` 那句的澄清（回应 首席 质疑，必须写清）**：同一文件里**另有一处**含 "must not"，
> 与本节引用**不是同一句、不是同一主题**：
> - **410-411**：`For devices launching with Android 10, create a partition called super.` ← 本节引用，讲**创建 super**
> - **588-589**：`Devices launching with Android 10 must not use system-as-root.` ← 讲**禁止 system-as-root**，与 super 是否存在无关
> - **591-592**：`Devices with dynamic partitions (whether it launches with or retrofit dynamic partitions) must not use system-as-root.`
>
> **结论：引文逐字无误，无需降为推导。** 两处是不同段落、不同主语。
> 附带收获：第 591 行原文明确承认 **retrofit dynamic partitions** 存在，正面支持 §证据3 里我对自己的那条修正。

**证据 1（最干净）：GKI 的定义域就是 5.10+**
[`/docs/core/architecture/kernel`](https://source.android.com/docs/core/architecture/kernel) 术语表原文：
> "**Generic Kernel Image (GKI) kernel** — Any **5.10 and higher** ACK kernel (**aarch64 only**)."

→ SDM845 的 **4.9 不在 GKI 的定义域内**。这比「分区形态反推」直接得多。

**证据 2：支持矩阵没有 4.x，最低一行是 Android 12**
[`/docs/core/architecture/kernel/android-common#compatibility-matrix`](https://source.android.com/docs/core/architecture/kernel/android-common) 原文表格：

| Android platform release | Supported kernels |
| --- | --- |
| Android 14 (2023) | android14-6.1, android14-5.15, android13-5.15, android13-5.10, android12-5.10 |
| Android 13 (2022) | android13-5.15, android13-5.10, android12-5.10 |
| **Android 12 (2021)** | **android12-5.10（仅此一个）** |

矩阵**最低一行就是 Android 12**，**不存在任何 4.9 / 4.14 / 4.19 行**。

**证据 3：分区形态结构性不成立（v6 修正了一处我自己的内部矛盾，见下）**
- **vendor_boot 需 boot header v3+**：[`vendor-boot-partitions`](https://source.android.com/docs/core/architecture/partitions/vendor-boot-partitions) 原文
  "Android 11 devices can use **boot image header version 3**. In version 3, all vendor-specific information is ... relocated into a new **vendor_boot partition**"。
  而本项目的公共树是 **`BOARD_BOOT_HEADER_VERSION := 1`**（方案乙 K0 已核）—— 差两个大版本。**这条是硬证据。**
- **vendor_dlkm 必须在 super 内**：[`vendor-odm-dlkm-partition`](https://source.android.com/docs/core/architecture/partitions/vendor-odm-dlkm-partition) 原文
  "**vendor_dlkm and odm_dlkm partitions are located in the super partition** as another dynamic partition"。
  而 polaris 的 `init/fstab.qcom` 里**没有** `vendor_dlkm` / `odm_dlkm` 条目 **[确]**。**这条也是硬证据。**
- **⚠️ 修正我自己的错误**：上一版我接着写「super 是 Android 10 出厂才引入（原文："For devices launching with Android 10,
  create a partition called super"），SDM845 出厂 8.1，早两代」——**这条推论在本项目上不成立，现撤回。**
  原因：polaris 的 `init/fstab.qcom:6-10` 里 system/vendor/product/odm/system_ext **全部带 `logical,first_stage_mount`** **[确]**，
  **说明 polaris 构建时确实有 super 分区**（LineageOS 对老设备做了 dynamic partition **retrofit**，原文 `dynamic_partitions/implement`
  确实有一节 "Upgrading Android devices"）。所以「出厂没有 super」不等于「现在没有 super」。
  **正确的表述**：polaris **有** super（retrofit 来的），但**没有** `vendor_boot`（header v1）也**没有** `vendor_dlkm` / `odm_dlkm` 条目。
  GKI 需要的三个分区载体，polaris 缺两个、第三个（super）虽在但里面没有 `vendor_dlkm`。
  **结论不变，但论证链必须按这个写**——否则会和我 §1 的 fstab 证据自相矛盾。
- 另注：第二路说的「设备树无 `BOARD_SUPER_PARTITION_SIZE`」只对 **oneplus** 树核实过，**不能套到 xiaomi/polaris**。
  这也正是我上面这条要改的原因。

**证据 4（厂商供给）：CLO 的 KERNEL.PLATFORM 发布列从未覆盖 msm-4.9**
`clo/la/kernel` 组 46 个 project 各仓的 `KERNEL.PLATFORM.*` 分支数：
msm-4.9 = **0**、msm-5.4 = **0**、msm-5.10 = 3（`KERNEL.PLATFORM.1.0.c25/.c26/.c27`）、msm-5.15 = 1。
四仓 branch 名检索 `845` **全部 0 命中**。`clo/la/kernel_platform` 组存在但 `projects=0`（仅 9 个子组，GKI 构建树布局）。
→ 高通的 GKI 产物树与 845 **完全无交集**。

**结论**：4.9 → 5.4 GKI 既无厂商源码、也无社区移植（§2.1.3 限制 5），**是三个候选里最空的一档，判定不可行**。

> **⚠️ 引用纪律（第二路提醒，评审官写最终文档时务必遵守）**：
> 1. **「GKI 1.0 / GKI 2.0」不是 AOSP 官方术语**。对 30+ 个 AOSP 页面正则检索 `GKI (1\.0|2\.0)` **零命中**；
>    官方只说 "this project and its **phases**"。**不要把「GKI 1.0=Android11/5.4、GKI 2.0=Android12/5.10」当官方措辞引用**（那是社区约定）。
> 2. **不要引 CDD**。全文检索 Android 11/12/15 三份 CDD，`GKI` 与 `Generic Kernel Image` 命中次数**均为 0**；
>    CDD 只在安全上下文提内核。权威矩阵在 android-common 页。
> 3. **`android12-5.4` 与 `android12-5.10` 不是二选一**，两者都真实存在。区别在**矩阵归属**：android12-5.4 服务
>    「Android 11 出厂 + 5.4 → 升级到 Android 12」的场景，不进 Android 12 的出厂支持矩阵。
> 4. **不存在**任何单句 AOSP 原文说「Android 8.1 / 4.9 不适用 GKI」。该结论必须按**推导**表述（上面三条证据），
>    **不得声称有单句原文**。
> 5. **「高通从未为 SDM845 发布 GKI」是强推论而非穷尽证明**：CLO 全站搜索 API
>    `/api/v4/search?scope=projects&search=sdm845` 返回 **401**，无法做全站关键词检索；该结论基于仓库/分支结构。
> 6. **VSR（Vendor Software Requirements）原文未取得**（`/docs/compatibility/vsr`、`/docs/compatibility/15/vsr` 均 404）。
>    理论上它是最强制性的来源，**但没拿到就不能引**。

> **另一处口径更正**：SDM845 的 CAF 4.9 系列是 **`LA.UM.8.3.*` / `LA.UM.10.3.*`**，**没有 8.1 或 8.2**。
> msm-4.9 全部 LA.UM 系列为 7.3 / 7.6.2 / 8.3 / 8.6.2 / 8.8 / 9.6.2 / 9.8 / 10.3 / 10.6.2。
> （我文档里此前只用过 8.3，无误；此处记录以免他人写错。）

### 2.4 交叉调研（并行第二路，已并入）

独立调研了 CodeLinaro msm-4.19/msm-5.4 的 tag 与芯片对应关系、社区 SDM845 4.19 树、GKI 矩阵。**结果已并入 §2.1**：
- 「CAF 无 SDM845 4.19/5.4」由该路的 `arch/arm64/configs/vendor/` 目录列举证实（§2.1.1）。
- 「社区 4.19 移植真实存在」由该路最先发现，**我随后自行复核**了 `meuira` 树的版本号、DTS 数量、techpack 与
  LineageOS 官方两棵设备树的 `BoardConfigCommon.mk` 原文（§2.1.2），未直接采信。
- 该路还报告 `EdwinMoq/android_kernel_oneplus_sdm845` 的 `lineage-24.0` 为 4.19.325；
  我**未独立复核**该仓库，故不作为本文依据，仅记录线索。

---

## 3. K2-02：驱动覆盖差距

### 3.1 真正的约束：HAL ↔ 内核绑定（本地实证）

| 证据 | 值 | 含义 |
| --- | --- | --- |
| blobs 中 `.ko` 模块数 | **0** | 驱动**全部编进 4.9 内核本体**。换内核不是「补几个模块」，是整套驱动重写 |
| 指纹 HAL | `fingerprint.fpc.so` + `fingerprint.goodix.so`（双供应商，`FIX_SONAME`） | 两个指纹方案并存（量产换料）；`idc`/`keylayout` 也成对：`uinput-fpc.*` / `uinput-goodix.*`。闭源 HAL 绑下游 SPI/input 驱动 |
| 指纹类型 | `persist.vendor.fingerprint.type=rear` | 物理后置传感器 |
| 指纹扩展 HIDL | `vendor.goodix.hardware.fingerprintextension@1.0::IGoodixBiometricsFingerprint` | 本地 `manifest.xml:21-29`。厂商私有 HIDL，无开源对应实现 |
| 传感器 HAL | `sensors.ssc.so`、`sensors.elliptic.so` | **SSC = Snapdragon Sensor Core**，传感器跑在 ADSP/SLPI 上，经下游 QMI/SMD 通道暴露。主线用 **IIO** 模型，两者架构不同，HAL 不可复用 |
| 相机 | CamX/Chi-cdk：`com.qti.sensor.imx363/ov5675/s5k3m3`、`com.qti.stats.*`、ArcSoft/Morpho/小米私有节点 | 依赖下游 `camera-kernel`（CAMSS 的厂商版）。主线用开源 `qcom-camss` + libcamera，两套互不兼容 |
| NFC | `libpn553_fw.so` / `libpn553_rec.so` | NXP **PN553**。主线对应 `nxp-nci`，但 polaris dts 是否有该节点待 §3.3 核实 |
| 音频功放 | `tas2559_uCDSP.bin` + `tas2559_l/r.ftcfg` | TI **TAS2559** 智能功放，带 DSP 固件与左右声道标定 |
| DSP 卸载 | `vendor/lib/rfsa/adsp/*`（`libSuperSensor_skel.so`、`libarcsoft_dualcam_refocus_skel.so`） | 走 FastRPC 到 ADSP，依赖下游 `adsprpc` 驱动 |
| Keymaster | HIDL `android.hardware.keymaster@3.0` | 本地 `manifest.xml:2-10`。绑 QSEE/TrustZone，与内核 QSEECOM 接口耦合 |
| Secure Element | HIDL `android.hardware.secure_element@1.0`（`SIM1` + `eSE1`） | 本地 `manifest.xml:11-20` |
| 加密 | `fileencryption=ice` | 下游 ICE 驱动 + UFS 集成 |

> **[确] 关于「换内核即 HAL 全废」的修正（两次改正，最终口径）**
>
> **v1 的错误**：我据「263 个 blob 条目里 `.ko` 为 0」推断「换内核 = HAL 全废」。
> 这个推断对**主线**成立，对**下游 4.19** 不成立——因为下游树自带 `techpack/`（`display`、`camera-sdm845`、
> `audio`、`data`、`video`），厂商驱动以源码随内核树走，blobs 面对的内核接口依然存在。
>
> **v2 的过度纠正（复核官 指出，接受）**：我随后写成「techpack 齐全**直接推翻**了 HAL 全废」。**这句同样过头。**
> 理由：`techpack` 是**内核侧源码**，而 HAL 是 `vendor/lib64/hw/` 下的**闭源 `.so`**；
> 两者之间隔着 **uapi（ioctl 号、结构体布局、sysfs 节点名、枚举常量）**。
> techpack 存在只能保证「接口**大概率**还在」，不能保证「接口**语义一致**」。
>
> **最终口径（本版）**：4.19 的 HAL 风险等级从 **「必然全废」→「待 uapi 验证」**。
> 三个等级的准确含义：
>
> | 表述 | 含义 | 是否可用 |
> | --- | --- | --- |
> | 「必然全废」 | 无厂商内核侧源码，接口不存在 | ❌ v1 的错误 |
> | 「直接推翻/必然可用」 | 有 techpack 就等于 HAL 能跑 | ❌ v2 的错误 |
> | **「待 uapi 验证」** | 接口大概率存在，语义是否一致未验证，须逐项比对 | ✅ **本版口径** |
>
> **uapi 验证的责任划分**：方案乙 K2-03 负责比对 4.9 vs 4.19 的 uapi（`techpack/display` 的 `sde_drm`、
> `techpack/audio` 的 apr/slate、`techpack/camera` 的 ioctl、`drivers/power/supply/qcom` 的属性名）；
> 重心**不是「驱动文件在不在」，而是「HAL 引用的常量/结构体/节点名是否仍在且语义一致」**。
> K3-01P 的 P4–P6 负责实机验证。

### 3.1b polaris 的实际配置链（主机官纠错并入，2026-10-28 补）

> 本节因 主机官 指出我的复验命令有误而新增。他说的对，这里记清楚。

**polaris 构建实际用的内核配置是两段合并，不是通用 `arch/arm64/configs/defconfig`：**

| 段 | 文件 | 来源 |
| --- | --- | --- |
| 基础 | `arch/arm64/configs/vendor/xiaomi/mi845_defconfig` | 公共树 `BoardConfigCommon.mk` 的 `TARGET_KERNEL_CONFIG :=` |
| 追加 fragment | `arch/arm64/configs/vendor/xiaomi/polaris.config` | 本地 `BoardConfig.mk:19` 的 `TARGET_KERNEL_CONFIG +=` |

所以复验 **不能** 用 `make ARCH=arm64 defconfig`（那是通用 defconfig，与产品无关）；正确做法是
`make O=... ARCH=arm64 vendor/xiaomi/mi845_defconfig` 后用 `scripts/kconfig/merge_config.sh` 合并 `polaris.config`。
主机官 已把正确命令写进 `_reviews/HOST_SCRIPTS_AUDIT.md` §6.2 第 7 步（commit `03643e7`），**以后统一引用他的版本**。

**`vendor/xiaomi/polaris.config` 的实际内容（GitHub 代码索引原文片段）**：

```
CONFIG_MACH_XIAOMI_D5X=y
CONFIG_MACH_XIAOMI_SDM845=y
CONFIG_SECURE_TOUCH=y
CONFIG_TOUCHSCREEN_FT5X46=y
CONFIG_TOUCHSCREEN_FT5X46_I2C=y
CONFIG_TOUCHSCREEN_SYNAPTICS_DSX_CORE_FORCE=y
# CONFIG_FINGERPRINT_FPC_SCREEN_NOTIFY is not set
```

**由此得到三条对我先前判断的修正**（第 3 条为核对 复核官 计数时新发现）：

1. **[确] polaris 的 4.9 触屏是双供应商，不是单一 RMI4。**
   依据：`arch/arm64/boot/dts/qcom/polaris-p0.dtsi` 同一文件里**同时**有
   `ft5x46_i2c@38 { compatible = "ft,ft5x46_i2c"; }`（FocalTech，I²C **0x38**）
   与 `synaptics,irq-gpio = <&tlmm 125 0x2008>;` / `synaptics,reset-gpio-name = "dsx_reset";`（Synaptics）。
   两个驱动都编进内核（`FT5X46=y` + `SYNAPTICS_DSX_CORE_FORCE=y`），运行时谁探测到就用谁。
   这与指纹的 FPC/Goodix 双供应商是同一种量产换料模式。
2. **[确][重要] 主线 dts 只声明了 Synaptics 一颗（`syna,rmi4-i2c` @ **0x20**），
   而厂商 4.9 设备树的主触屏是 FocalTech `ft5x46` @ **0x38**——不同芯片、不同地址。**
   推论：**若用户那台机器装的是 FocalTech 触屏，主线 dts 的 touchscreen 节点根本不会绑定**
   （地址与 compatible 都不匹配），且主线没有 `ft,ft5x46_i2c` 这个 compatible。
   → 这条**加强**了主线不可行的判断（§5.1），并新增一条 Phase 0 待查项（§7.11）。
   注意：我不能反过来说「主线 dts 写错了」——它可能只覆盖了某一个硬件变体；但**「一台设备一个 dts」这个前提不成立**。
3. **[确][新发现] polaris 的面板也是双供应商，主线同样只覆盖一颗。**
   核对 复核官 的 DTS 计数时我列了 `arch/arm64/boot/dts/xiaomi/polaris/display/`，里面是**两个**面板 dtsi：
   - `dsi-panel-jdi-fhd-nt35596s-video.dtsi` ← JDI **NT35596S**
   - `dsi-panel-ebbg-fhd-ft8716-video.dtsi` ← EBBG **FT8716**
   而**主线 dts 只声明 `jdi,fhd-nt35596s` 一颗**。
   推论与触屏同构：**若实机是 EBBG FT8716 面板，主线路线连「有节点没驱动」都算不上——连节点都没有。**
   → polaris 目前已知是**三重换料机型**：指纹 FPC/Goodix、触屏 FocalTech FT5X46/Synaptics、面板 JDI NT35596S/EBBG FT8716。
   这是量产换料的常规做法，但它对**任何**「一台机器一个 dts」的移植路线都是结构性风险。
   **Phase 0 必须确认这三项实机各是哪一颗**（§7.11 已扩写）。

> 顺带确认 主机官 ① 的结论：他搜 `CONFIG_RMI4` 在 `path:arch/arm64` 得 0 命中**是对的**，
> 我也复核了 `path:arch/arm64/configs` 同样 0 命中。原因现在清楚了——polaris 根本不走 RMI4，
> 走的是 `CONFIG_TOUCHSCREEN_SYNAPTICS_DSX_CORE_FORCE`（厂商 DSX 驱动）+ FT5X46。
> 这不代表我 §3.3.5 的 RMI4 结论错（那节讨论的是**主线内核**的通用 defconfig，那里 rmi4 确实是 `syna,rmi4-i2c` 的驱动），
> 但**必须分清两个树、两个配置**，我此前混着说了，改正。

### 3.2 主线路线的实测硬件覆盖（Nura wiki，polaris 自身）

| 功能 | 状态（页面原文） | 备注 |
| --- | --- | --- |
| Flashing | Works | |
| USB Networking | Works | |
| 3D Acceleration | Works | freedreno/MSM |
| Bluetooth | Works | |
| SMS / Mobile data | Works | |
| FDE | Works | |
| **Screen** | **Partial** | 正文：面板驱动曾被 revert，6.2-rc3 rebase 后 commit 已不在树里，需 workaround |
| **Touchscreen** | **Partial** | 同上，与显示绑在一个 workaround 里 |
| **Battery** | **Partial** | 正文原文：`/sys/class/power_supply/` 是空的 —— 表格的 Partial 仍偏乐观 |
| **Audio** | **Partial** | 未分 speaker/mic/calls |
| **Wi-Fi** | **Partial** | 正文：5 GHz 下实测约 6 Mbps 且 `apk update` 会断网；2.4 GHz 约 1 Mbps |
| **Calls** | **Partial** | |
| **Camera** | **Broken** | |
| **USB OTG** | **Broken** | |
| GPS / NFC / 加速度计 / IR TX | **Untested** | 页面无数据，属未记录，**不等于不支持** |
| **指纹 / 内部存储 / 休眠唤醒 / Secure boot / 距离 / 光线 / 磁力计** | **页面上无此行** | 未记录。指纹按同平台参考机判断（下） |

同平台最成熟参考机（community 级，比 polaris 高一档）：

| 功能 | OnePlus 6（enchilada） | Poco F1（beryllium） |
| --- | --- | --- |
| 指纹 | **Broken** | **Broken**（仅 WIP issue/MR） |
| 相机 | Partial | Partial（需 megapixels 配置 + 手调快门 ISO + gmic 后处理） |
| NFC | Partial | 无硬件 |
| 通话/短信/移动数据 | Partial | Partial |
| 屏幕/触摸/音频/3D/存储/电池/传感器 | Works | 多数 Works（Screen/Battery Partial） |
| USB OTG | Broken | Broken |

> **[确] 没有任何 SDM845 设备进入 Nura 的 `main` 分类**，最高 community。
> **[确] 指纹在 SDM845 主线上整体不可用**（两台最成熟参考机都是 Broken）。
> **[确] Modem 有结构性缺陷**：s2idle 下内核无法区分来电/短信与信号强度变化，默认漏接来电；
> 需手动 `echo enabled > /sys/bus/rpmsg/.../IPCRTR.../power/wakeup`，代价是任何 modem 消息都唤醒设备。
> Poco F1 页面还记录「7.1.0-rc1-sdm845 下约 80% 的开机会卡住」，需反复重启。

### 3.3 主线 dts 节点逐项覆盖（第三路调研已并入）

方法：独立子代理用 `web_fetch` 取到 `git.kernel.org` cgit plain 与 `raw.githubusercontent.com` 两份**逐字节一致**的全文，
再逐项比对驱动 `of_match_table`、bindings 目录、`arm64 defconfig`。「不存在」结论由完整文件/目录列表 + 404 支撑，不依赖搜索零结果。

#### 3.3.1 三个决定性的「有节点但跑不起来」

| 发现 | 证据 | 后果 |
| --- | --- | --- |
| **面板在主线无任何驱动认领** | `compatible = "jdi,fhd-nt35596s"` 全树**仅出现这一次**。panel Kconfig 里提 35596 的只有 `DRM_PANEL_ASUS_Z00T_TM5P5_NT35596`，其 match 表是 `{ .compatible = "asus,z00t-tm5p5-n35596" }`（拼写 `n35596`，厂商 `asus`）；`panel-jdi-fhd-r63452.c` 是 `{ .compatible = "jdi,fhd-r63452" }`（同前缀、不同 DDIC）；`panel-jdi-fhd-nt35596s.c` 与 `panel-novatek-nt35596s.c` **均 404**；bindings 下只有 `jdi,lpm102a188a.yaml`、`jdi,lt070me05000.yaml`；`DRM_PANEL_TRULY_NT35597` 是 **35597** 另一颗 IC | **DSI 面板不会 probe，`make dtbs_check` 会直接报错。屏幕点不亮——不是「Partial」，是 0** |
| **polaris 没有声卡节点，且未使能 ADSP** | `sdm845.dtsi` 里是空壳 `sound: sound { };`，需板级填充；**beryllium 填了，polaris 没填**。polaris 虽配了 `&wcd9340` 与 `&q6afedai`/`&q6asmdai`，但 `q6afedai` 挂在 `"qcom,q6afe"` 下、`qcom,protection-domain = "avs/audio","msm/adsp/audio_pd"`，依赖 ADSP；而 polaris 保留了 `adsp_mem` 却**没有 `&adsp_pas` 覆写**（SoC 里确有 `adsp_pas: remoteproc-adsp` / `"qcom,sdm845-adsp-pas"`）。`&slpi_pas` 同样未使能 | **无音频回放路径，且传感器所在的 SLPI 也没起来** |
| **触屏：主线只覆盖了一颗，实机可能是另一颗** | 主线 defconfig `CONFIG_RMI4` **零命中**、`CONFIG_TOUCHSCREEN_SYNAPTICS*` **零命中**；驱动在树里（`rmi_i2c.c` + `rmi_f01.c` + `rmi_f12.c`）但默认不开。**更关键**：主线 dts 只声明 `syna,rmi4-i2c` @**0x20**，而厂商 4.9 设备树（`polaris-p0.dtsi`）的主触屏是 `ft,ft5x46_i2c` @**0x38**（详见 §3.1b） | 拆机变体决定：FocalTech 变体的搓屏在主线**无 compatible 可绑**；Synaptics 变体还需手动开 RMI4。**新增强阻塞项** |

#### 3.3.2 polaris dts 已启用的节点（全部有原文）

机型 `"xiaomi,polaris","qcom,sdm845"` / `qcom,board-id = <0x2a 0x0>`；reserved-memory 10 区（rmtfs `"qcom,rmtfs-mem"`，client-id 1，vmid MSS_MSA）；
gpio-keys 音量+（`<&pm8998_gpios 6 GPIO_ACTIVE_LOW>`，debounce 15）；`pm8998_resin` 音量−；
battery `"simple-battery"` 3400 mAh / 4.4 V；三组 RPMh regulator（pm8998 smps2/3/5/7 + ldo1~28 + lvs1/2、pmi8998 bob allow-bypass、pm8005 smps3）；
两个 `regulator-fixed`（`vreg_tp_vddio` 走 TLMM23、`vreg_s4a_1p8`）；
触摸屏 `"syna,rmi4-i2c"`@0x20 on i2c14，irq tlmm125，子节点 `rmi4-f01@1` / `rmi4-f12@12`（clip-x-high 0x438、clip-y-high 0x870 → 1080×2160）；i2c14 400 kHz（**唯一 I2C**）；
panel（见 3.3.1，无驱动）；mdss + mdss_dsi0 + mdss_dsi0_phy 全 okay，`data-lanes <0 1 2 3>`；背光 `pmi8998_wled`（num-strings 4、ovp 19600 mV、`qcom,cabc`）；
lab/ibb 4.6–6.0 V；gpu okay + `gpu_zap_shader` 固件 `a630_zap.mbn`；venus okay + `venus.mbn`；cdsp_pas okay + `cdsp.mbn`；
mss_pil okay + `mba.mbn`/`modem.mbn`；ipa okay + `ipa_fws.mbn`；
**wifi okay**（SoC 节点 `"qcom,wcn3990-wifi"` 默认 `status="disabled"`，polaris 翻开，5 路供电）；
**bluetooth** `"qcom,wcn3990-bt"` on uart6 + `firmware-name = "Xiaomi/polaris/crnv21.bin"` + max-speed 3200000；
ufs_mem_hc（reset tlmm150、vcc-max 800000 uA）+ ufs_mem_phy；
**USB 强制降到 2.0**（`qcom,select-utmi-as-pipe-clk`、`dr_mode="peripheral"`、`maximum-speed="high-speed"`、移除 USB3 phy）+ hsphy + qmpphy；
wcd9340 供电/4 路 micbias（reset tlmm64）；`q6afedai dai@22 QUATERNARY_MI2S_RX` sd-lines 0 + `q6asmdai` 三条 MultiMedia；
qupv3_id_0/1、gpi_dma0/1；tlmm（`gpio-reserved-ranges <0 4>,<81 4>`，触屏 int/reset + DSI active/suspend 四组 state）；gcc 5 个 protected-clocks；aliases serial0=uart9 / serial1=uart6。

#### 3.3.3 polaris dts 里**没有**的子系统（基于完整文件判定）

相机/CCI/IMX（**连总线都没开**）、NFC、指纹、振动马达、传感器（加速度/接近/陀螺，且 `slpi_pas` 未使能）、**声卡**、
ADSP remoteproc（未使能）、**充电器**（`pmi8998.dtsi` 里有 `pmi8998_charger: charger@1000` / `"qcom,pmi8998-charger"`，
polaris 包含该 dtsi 但**没使能**、也无 `monitored-battery` → battery 节点无消费者）、
**电量计**（全 qcom dts 树都搜不到 pmi8998 fuel-gauge，属**主线整体缺失**而非本机型特有）、LED/闪光灯（背光另算）、microSD/sdhc、SPI、chosen/framebuffer。

#### 3.3.4 与 beryllium（Poco F1）的差距

beryllium 现为 `-common.dtsi` + `-ebbg.dts` + `-tianma.dts`，Makefile 里只有这两个 dtb。

| 方向 | 清单 |
| --- | --- |
| **beryllium 有、polaris 没有** | 声卡（`"qcom,db845c-sndcard","qcom,sdm845-sndcard"`，model "Xiaomi Poco F1"，mm1/mm2/mm3 + SLIM 播放/录音 dai-link + audio-routing）；`&adsp_pas` okay；`&slpi_pas` okay；`&pmi8998_charger` okay + `monitored-battery=<&battery>`；`&pmi8998_lpg` led@5 白色 STATUS；`&pmi8998_flash` 两路；`&sdhc_2`；`&cci_i2c0` okay 但**只有注释 `/* IMX363 @ 10 */` 无传感器节点**；`&i2c5` okay 但**只有注释 `/* TAS2559 @ 4C */` 无 TAS 节点**；chosen/framebuffer `"simple-framebuffer"` 1080×2246 + `cont_splash_mem`；有驱动的屏/触屏（`ebbg,ft8719` + `focaltech,ft8719`；`tianma,fhd-video`/`novatek,nt36672a`） |
| **polaris 有、beryllium 没有** | pm8005 第三颗 PMIC；完整得多的 LDO 表（beryllium 只声明约 14 个）；pmi8998 bob；`vreg_tp_vddio` 触屏 IO 固定 regulator；gpi_dma0；serial0=uart9 别名；USB 降速 2.0 的三处覆写；蓝牙 `firmware-name`；Synaptics 触屏 |

> **判读**：连 beryllium 这个 community 级参考机，相机也只有「注释掉的 IMX363 占位」、TAS2559 也只有注释占位。
> polaris 连声卡和充电器都没填。**polaris 的 dts 是「能编译、能起一部分」的半成品，不是可用设备树。**

#### 3.3.5 主线 arm64 defconfig（1875 行）关键项

> **适用对象声明（因 主机官 纠错而补）**：本节讨论的是**上游主线内核**（torvalds/linux）的
> `arch/arm64/configs/defconfig`，用于评估「主线路线」的可行性。
> **不是** polaris 4.9 构建用的配置——后者是 `vendor/xiaomi/mi845_defconfig` + `polaris.config` 两段合并，见 §3.1b。
> 两棵树、两套配置，不可混用；我此前混着说了，已改正。

| 类别 | 命中 |
| --- | --- |
| 有 | `CONFIG_DRM_MSM=m`、`CONFIG_ATH10K_SNOC=m`、`CONFIG_SND_SOC_SDM845=m`、`CONFIG_SCSI_UFS_QCOM=m`、`CONFIG_VIDEO_QCOM_VENUS=m`、`CONFIG_BACKLIGHT_QCOM_WLED=m`、`CONFIG_INTERCONNECT_QCOM_SDM845=y`、`CONFIG_QCOM_Q6V5_PAS=m`/`Q6V5_MSS=m`/`Q6V5_ADSP=m`、`CONFIG_QCOM_IPA=m`、`CONFIG_QCOM_RMTFS_MEM=m`、`CONFIG_QCOM_APR=m`、`CONFIG_QCOM_RPMH=y`、`CONFIG_QCOM_RPMHPD=y`、`CONFIG_QCOM_IOMMU=y`、`CONFIG_BT_QCOMSMD=m`、`CONFIG_BT_HCIUART_QCA=y`、`CONFIG_PHY_QCOM_QUSB2=m`、`CONFIG_PHY_QCOM_QMP=m`、`CONFIG_REGULATOR_QCOM_RPMH=y`、`CONFIG_ARM_QCOM_CPUFREQ_HW=y`；`CONFIG_QCOM_` 前缀共 55 行 |
| **缺（与 polaris 直接相关）** | `CONFIG_RMI4` 及 `CONFIG_TOUCHSCREEN_SYNAPTICS*` → 主线要在 Synaptics 变体上跑触屏需手动开；NT35596/JDI 面板 → 与「无驱动」一致；`CONFIG_USB_DWC3_QCOM`（只有通用 `CONFIG_USB_DWC3=y`，实际由 `ARCH_QCOM` 带入）；`CONFIG_PINCTRL_SDM845`/`PINCTRL_MSM8998`（由 `CONFIG_ARCH_QCOM=y` 默认带入） |

> **复验命令（已按 主机官 的纠正更新）**：
> - 验**主线**：`make ARCH=arm64 defconfig` 后 `grep -iE 'CONFIG_RMI4|CONFIG_TOUCHSCREEN'` —— 这条命令只对主线成立。
> - 验**polaris 4.9 实配**：**不能**用 `make ARCH=arm64 defconfig`。正确做法
>   `make O=... ARCH=arm64 vendor/xiaomi/mi845_defconfig`，再用 `scripts/kconfig/merge_config.sh` 合并
>   `vendor/xiaomi/polaris.config`。主机官 已把完整命令写进 `_reviews/HOST_SCRIPTS_AUDIT.md` §6.2 第 7 步（commit `03643e7`）。
>
> 调研限制：主线 defconfig 那 1875 行是该路子代理把 `web_fetch` 结果转写到工作区后再 grep 的，
> 代表「收到的内容」而非独立校验的下载。`CONFIG_RMI4` 零命中这条已被 主机官 用
> `path:arch/arm64` 代码索引独立佐证（0 命中），我也复核了 `path:arch/arm64/configs`（0 命中），**可信**。


### 3.4 逐项差距汇总（按 复核官 返工判据「必须加『4.19 下游』列」重做）

> **前提声明**：本表「4.19 下游」列的状态全部是 **【待 uapi 验证】**，不是「已可用」也不是「已失效」。
> 依据只有两条：① `meuira` 4.19.325 树**有**对应源码/节点（→ 所以不是「必然全废」）；
> ② **尚无**任何 polaris 在 4.19 上的启动或 HAL 联调证据（→ 所以不能算「可用」）。
> 真正的判定要等 方案乙 的 K2-03（uapi 比对）与 K3-01P 的 P3。

#### 3.4a K2-03（uapi 比对）结果已并入——见 `_reviews/K2_03_ABI_G_6.md`

> 方案乙 已交付 K2-03（188 行）。我读过并在下面对齐口径，**不改他的结论，只记录它如何解掉本表的「待验证」**。

| 通道 | 5.10 主线 | 4.19 下游（meuira） | 对本表的含义 |
| --- | --- | --- | --- |
| FastRPC / ADSP | **失效**（`/dev/adsprpc-smd` vs `fastrpc-*`；ioctl 1–15 vs 1–8 同号不同义） | **保持**：16 条 `FASTRPC_IOCTL_*` 宏差集为空；`fastrpc_ioctl_control` 的 union 成员变了（去 `smmu`、加 `wakelock`/`pm`）但 **union 仍 8 B、结构体仍 12 B、ioctl 号不变**；`fastrpc_ctrl_latency` 仅 `level`→`latency` 改名同尺寸 | 4.19 列 **【已验·有利】**，精确措辞「编号+尺寸级保持，语义级仅 CONTROL 的 SMMU 请求处理不同」 |
| SSC 传感器（QMI/SMD） | **失效**（`smd_pkt`/`glink_pkt` 不在） | **保持**（`smdpkt` 同名） | 同上 |
| CamX 相机 | **失效**（`cam_*` uapi 目录 0 文件） | **宏级保持**：`msm_camera.h` 83 条 ioctl 宏差集为空；`cam_req_mgr` 34→36 | 结构体尺寸**未比**，仍是唯一开口 → 列入 PoC 待验 |
| QSEECOM | **失效**（`/dev/qseecom` 不在） | **保持**（同名） | 同上 |
| ICE | **失效**（`iceufs` 不在） | **保持**（同名） | 同上 |
| display | — | **条件失效**：`struct sde_drm_scaler_v2` 尾部 +8 个 `uint32`（+32 B）、`SDE_DRM_BLEND_OP_MAX` 4→5 | 上表「显示」行从【待验证】改为**【条件失效·取决于 HAL 是否用 scaler_v2】** |
| power_supply | — | **条件失效**：4.9 有 7 个属性 4.19 没有（`ALLOW_HVDCP3`/`MAX_PULSE_ALLOWED`/`IGNORE_FALSE_NEGATIVE_ISENSE`/`BATTERY_INFO`/`BATTERY_INFO_ID`/`ENABLE_JEITA_DETECTION`/`QG_VBMS_MODE`） | 上表「充电/电源」行从【待验证】改为**【条件失效·取决于 HAL 是否按名读这 7 个】** |

> **口径纪律（与 首席 定案一致，务必遵守）**：
> 1. **「5.10 主线 5/5 失效」只能用来排除 5.10，不能写成维持 4.9 的理由。** 它证明不了 4.9 正确。
> 2. 上面 4.19 的「保持」全部是 **uapi 静态比对**结论，**不等于**极性为「可用」——仍缺构建与实机启动证据。
> 3. 例外说明：**4.19 的 0 项确证失效不等于 0 风险**，还有 2 项条件失效 + CamX 结构体未比。

| 硬件 | 下游 4.9（现状） | **4.19 下游（meuira 树）** | 主线（6.x/7.x，已实测） |
| --- | --- | --- | --- |
| 显示 | 可用（SDE/MDSS + 闭源 HAL） | **【条件失效】** techpack `display/` 在、`mdss_dsi_panel.c` 有 `mdss_dsi_nt35596_read_status`、`dsi-panel-jdi-fhd-nt35596s-video.dtsi` 齐备；**但 `struct sde_drm_scaler_v2` 尾部 +8×uint32（+32 B）、`SDE_DRM_BLEND_OP_MAX` 4→5**——HAL 若用 scaler_v2 传旧尺寸属性会被拒（K2-03 §6.3） | **不可用**：主线 DRM panel 无驱动认领（`panel-jdi-fhd-nt35596s.c` 404），**E8 成立** |
| 触摸 | 可用（`FT5X46=y` + `SYNAPTICS_DSX_CORE_FORCE=y`，**双供应商**） | **【待验证·有利】** 4.19 树沿用 Xiaomi 厂商 dts（`ft5x46_i2c@38` + synaptics 属性并存）与厂商驱动 | 只声明 Synaptics `syna,rmi4-i2c`@0x20 且 defconfig 未开 RMI4；**FocalTech 变体无 compatible 可绑** |
| 充电/电源 | 可用 | **【待验证】** 树内有 `drivers/power/supply/qcom`（含 `idtp9220` 无线充提交）；`pmi8998_charger` 是否使能未核 | **不可用**：`pmi8998_charger` 未使能、全树无 pmi8998 电量计 |
| 电源管理/休眠 | 可用 | **【待验证·有风险】** 树上有未修复缺陷：`516e794d` halls revert（**perseus UAF kernel panic**）、`02cf2eb9` display 删 doze/fod（**break dt2w**） | **未记录**；参考机有 s2idle 唤醒缺陷 |
| Wi-Fi | 可用（ath10k snoc + 下游） | **【待验证】** 树内 wcn3990 相关源码在（未逐项核） | **Partial**：dts 有 `qcom,wcn3990-wifi`，`ATH10K_SNOC=m`；实测 1–6 Mbps |
| 蓝牙 | 可用 | **【待验证】** 同上 | **可用**：`qcom,wcn3990-bt` + `crnv21.bin`，`BT_QCOMSMD=m` |
| 音频 | 可用（WCD9340 + TAS2559 + ADSP） | **【待验证·有利】** techpack `audio/` 在 | **不可用**：无声卡节点（`sound {}` 空壳）、`&adsp_pas` 未使能 |
| 相机 | 可用（CamX + 4 颗 sensor blob） | **【待验证·有利】** techpack `camera-sdm845/` 在，`polaris-camera-sensor-mtp.dtsi` 在 | **不可用**：连 CCI/I²C 总线都没开，无 sensor 节点 |
| 指纹 | 可用（FPC/Goodix 双 HAL） | **【待验证·无 techpack 覆盖】** 属 uapi 问题，K2-03 重点 | **不可用**：dts 无节点；参考机均 Broken |
| NFC | 可用（PN553） | **【待验证·无 techpack 覆盖】** | **不可用**：dts 无节点 |
| GPS | 可用（下游 loc HAL） | **【待验证】** | polaris **Untested**，SoC 级 Works |
| 传感器 | 可用（SSC/ADSP，`sensors.ssc.so`） | **【待验证·无 techpack 覆盖】** SSC 走 QMI/SMD，K2-03 重点 | **不可用**：dts 无节点，`&slpi_pas` 未使能 |
| 振动 | 可用 | **【待验证】** 树上 `drivers: halls` 相关缺陷需注意 | dts 无节点 |
| USB/ADB | 可用 | **【待验证】** | USB networking Works；**强制 2.0**、**OTG Broken** |
| 存储 | 可用（UFS + 动态分区） | **【待验证】** | dts 有 ufs_mem_hc + phy，`SCSI_UFS_QCOM=m` |

> **两条面板路线互不否证（按 复核官 判据 ③ 明确写死）**：
> - **E8（主线）**：主线 DRM panel 层**没有** `jdi,fhd-nt35596s` 的驱动，`make dtbs_check` 会报，**屏点不亮**。已确证。
> - **E18（Android 下游）**：下游走的是 **fbdev/msm** 路径而非 DRM panel，`mdss_dsi_panel.c` 里有 `mdss_dsi_nt35596_read_status`，
>   `dsi-panel-jdi-fhd-nt35596s-video.dtsi` 齐备，**驱动是完整的**。也已确证。
> - 两者**不矛盾**：它们是两套不同的显示子系统。**不许用 E8 去否 4.19，也不许用 E18 去救主线。**

> **主线列的产品判断不变**：显示、充电、音频、相机、指纹、NFC、传感器、振动八项在主线缺实现或缺节点，
> 最小集（显示/触摸/充电/Wi-Fi/USB）里三项是硬缺，**主线 polaris 连「开机看到画面」都不成立**。

> **4.19 列的产品判断（新增）**：源码侧覆盖面最大，是**唯一值得做 PoC** 的方向；
> 但「有源码」不等于「HAL 能对上」，且树上有已知未修复缺陷（perseus panic、dt2w）。**必须走 §5.4 的 P1→P6 验证。**

---

## 4. 关键约束：Android 16 分支未强制内核升级

| 证据 | 值 |
| --- | --- |
| `LineageOS/android_kernel_sony_sdm845` | 存在 `lineage-23.0` 分支，sha `1a8fc01dce4296fc3d5437dc4f2a713ecec621e9` |
| 该分支内核版本 | 根 `Makefile`：`VERSION = 4` / `PATCHLEVEL = 9` / `SUBLEVEL = 337` / `NAME = Roaring Lionus` —— **Linux 4.9.337**[确] |
| 对照 | 与其 `lineage-22.2` 同 sha，即 22.2 → 23.0 内核**未做任何改动** |

> **[确] 结论（按 复核官 口径收窄）**：Sony SDM845 的 `lineage-23.0` 与其 `lineage-22.2` **同 commit、内核未做任何改动**
> ⇒ **Android 16 分支未强制内核升级**。
> 由此可以说：23.2 路线的真实阻塞是**设备树与 blobs 没有 23.2 分支**（`docs/00` 已证），不是内核版本；
> 内核升级对 Termux 终端机这个交付目标**不构成前置必要条件**。
>
> **不能说**「Android 16 根本不需要新内核」——本证据只覆盖一个厂商树的一次分支对照，
> 不足以支撑「不需要」这种全称判断。已按 复核官 意见改正。
>
> 另：我初版还曾说 `docs/09` 把两者并列为同等优先级是「定位错误」。**这条我撤回**——
> `docs/09:19-22` 原文立场是保守的（「公开仓库目前没有 4.19 内核分支」「**不能仅凭一条提交信息就宣称 4.19 可用**」），
> 它甚至明确要求「继续核查上游/维护者是否有公开或半公开的 4.19 内核树」。
> **我的 v2 恰好就是在执行 docs/09 交办的这个核查，而不是在纠正它。** 错误归因，向 复核官 致谢纠正。

> **[确] 另一条给 主机官 的事实**：OnePlus 那条 vanilla 4.19 的 `lineage-23.2` 分支虽然存在，但 `lineage.dependencies`
> 引用内核仓库时**无 `branch` 字段**，roomservice 按仓库默认分支（`lineage-22.2`）解析，所以该分支不会被 sync 取用。
> 这反过来说明我们 `local_manifests/terminalos.xml:41-49` 显式锁 `lineage-22.2` 的做法是对的——
> 但那三条 `revision` 是**分支名不是 commit pin**（方案乙 K0 已指出），构建时必须留 `repo manifest -r` 才可复现。

---

## 5. 候选裁决建议（交复核官）

### 5.1 三个候选的判定

| 候选 | 判定 | 一句话理由 |
| --- | --- | --- |
| **Linux 4.19（社区下游）** | **唯一值得做 PoC 的升级候选，成熟度未验证** | `meuira` 树 4.19.325 已含 43 个 polaris DTS + polaris.config + sdm845-perf_defconfig + 完整 techpack；LineageOS 官方 oneplus 设备树已改 4.19 布局。**但无线索证明 polaris 能在 4.19 启动**，官方小米设备树未迁移，仓库单点维护（§2.1） |
| Linux 5.4（下游/GKI） | **不可行** | CAF msm-5.4 的 vendor 目录无 sdm845；既无厂商源码也无社区树；SDM845 为 pre-GKI，无 `vendor_boot`/`vendor_dlkm` |
| Linux 5.10+（主线 6.x/7.x） | **不可行（产品层面已否证）** | 树在维护、polaris dts 在上游，但：① **面板在主线无任何驱动认领，屏点不亮**；② **充电器节点未使能、主线全树无 pmi8998 电量计**；③ 无声卡节点、ADSP/SLPI 未使能；④ 相机/NFC/指纹/传感器/振动在 dts 里根本没有；⑤ 设备包已归档无人维护；⑥ 必须放弃 Android HAL |

> **对第三行的加强（第三路调研后）**：我原先写「刚需项仅 Partial」，实测后要更严厉——
> **显示与充电不是 Partial，是「主线根本没有对应实现」**。`/sys/class/power_supply/` 为空的原因也找到了：
> polaris 没使能 `pmi8998_charger`，且主线整个 qcom dts 树里没有 pmi8998 电量计节点。
> 所以主线 polaris 连「能开机看到画面」这一步都过不去，不是「能用但不完美」。

### 5.2 建议：交付目标维持 4.9.337，同时开一个 4.19 PoC

**交付线（TerminalOS 本体）目标版本 = 维持 4.9.337。** 理由：

1. **配套完整**：4.9.337 @ `aa8adfe9` 与现有 blobs（MIUI V12.0.3.0 / Android 10 期）、设备树、LineageOS 官方支持三者齐全。
2. **必要性**：Android 16 不需要更新内核（§4 实证）。升级不解决任何已知阻塞。
3. **风险**：4.19 树虽然有 techpack，但**没有 polaris 启动证据**，且官方小米设备树未迁移。
   把交付压在未验证的树上，等于拿「已可用的整机」赌一个没点亮过的东西。

**但同时必须开一个独立的 4.19 PoC**（不是取消，这是我上一版判错的地方）。理由：
4.19 是**唯一真实存在、且技术上绕得开 HAL 问题**的升级方向。不验它就是纯粹因为偷懒放弃，
而验它的代价远小于主线路线。**PoC 判据见 §5.4。**

### 5.3 主线路线（5.10+）——产品层面不可行，除非换产品

若用户坚持走主线，必须明确四件事，这是**产品决策不是技术选择**：

1. **放弃 Android**。主线内核跑不了 polaris 的闭源 HAL，等于放弃 LineageOS，改做 Linux 发行版（Nura/Mobian 口）。
   那样 Termux 也不再需要——直接就是原生 Linux shell。**产品形态完全改变。**
2. **接手无人维护的设备口**。polaris 设备包 2026-07-19 已归档、maintainer 为空，新通用 UEFI 口不含 polaris。
   我们要自己当维护者，持续跟 7.x rebase。
3. **先补三块从零开始的实现**（第三路实测后修正，比原先判断更重）——
   不是「修一下 workaround」，而是**上游根本没这些代码**：
   - **面板驱动**：`jdi,fhd-nt35596s` 在主线无驱动，`panel-jdi-fhd-nt35596s.c` 不存在，要从零写并提交上游；
   - **充电器 + 电量计**：polaris 没使能 `pmi8998_charger`，且**主线整个 qcom dts 树都没有 pmi8998 电量计节点**，
     后者是平台级缺口，不是本机型能单独补的；
   - **声卡**：polaris 的 `sound {}` 是空壳，需按 beryllium 的 sndcard/dai-link 结构填，并先使能 `&adsp_pas`。
   这三项任一未解决，设备就「点不亮 / 充不进 / 没声音」，最小集直接不成立。先做 PoC 验这三项，再谈后面。
4. **Wi-Fi 性能不达标**：实测 1–6 Mbps（5 GHz 约 6 Mbps 且 `apk update` 会断网），对终端机不可用，需单独排查。

### 5.4 4.19 PoC 的验收判据（建议新增任务，交复核官裁定是否立项）

判据按「能不能点亮」排序，**任何一条失败即 PoC 失败、K2 闭环为「不升级」**：

| 步骤 | 判据 | 通过标准 | 谁做 |
| --- | --- | --- | --- |
| P1 编译 | `meuira` 4.19.325 树能否为 polaris 编出 `Image.gz-dtb` | 有 `.config` 展开、有构建日志、有产物 sha256 | 主机官（Linux 构建机） |
| P2 DTB | 43 个 DTS 里哪些能编译通过 | 至少 mp/p3 主变体产出 dtb，`dtbs_check` 允许有 warning | 主机官 |
| **P3 点亮** | **刷入后能否进入 bootloader splash / kernel boot 日志** | 有串口或 pstore/last_kmsg 启动日志 | **首席（唯一可操作真机）** |
| P4 显示 | techpack display 是否 probe 成功 | `dmesg` 有面板驱动 probe，屏幕有画面 | 首席 |
| P5 充电 | power_supply 是否出现 | `/sys/class/power_supply/` 非空、能充 | 首席 |
| P6 关键外设 | 触摸 / Wi-Fi / USB-ADB | 三项基本可用 | 首席 |

> **注**：P3 之后必须遵守项目铁律——**Phase 0 未完成前禁止任何刷写**。PoC 的 P1/P2 可以现在做（纯编译，不碰设备），
> P3 起排队等 Phase 0。
>
> **回退方案必须先写好**：4.19 换内核会改变 boot 镜像结构（4.19 用独立 DTBO 分区布局，见 oneplus 的
> `BOARD_KERNEL_SEPARATED_DTBO := true`），而 polaris 当前 `fstab.qcom` 里**没有 dtbo 分区条目**。
> 刷入前必须确认分区表里有可用的 dtbo 分区，否则「刷进去起不来也刷不回去」。这条是 PoC 的**前置阻塞**。

### 5.5 建议的 K2/K3 任务改写

| 原任务 | 建议改为 |
| --- | --- |
| K2-04 候选裁决 | 裁决：**交付目标维持 4.9.337**；**4.19 列为唯一升级 PoC 候选**（按 §5.4 判据）；**5.3 主线判不可行**；5.10+/6.x 判不可行 |
| K3-01 内核分支创建与编译脚本 | **拆成两条**：<br>(a) 交付线：固定 `lineage-22.2` 的 commit pin，补 `repo manifest -r` 留档要求（不做内核分支）；<br>(b) PoC 线：新建 4.19 PoC 分支，先只做 §5.5 的 P1/P2（编译 + DTB），**不碰设备** |
| K3-02 逐项硬件验收 | 保留，作为 **22.2 基线**的硬件验收（P1-06 的一部），不是内核升级验收 |
| K4-01 最终版本裁定 | 按说明书 §K4 口径记 **「平台移植目标，内核维持 4.9.337，未做升级」**；若 4.19 PoC 点亮成功，再单独出升级结论，不得提前宣称 |
| 新增 K2-05（建议） | 4.19 PoC：P1 编译 / P2 DTB / P3 点亮 / P4 显示 / P5 充电 / P6 外设，判据见 §5.4。P3 起需 Phase 0 完成 |
| 新增前置（建议） | 由 首席 在 Phase 0 一并确认 **polaris 分区表有无 dtbo 分区**——这是 4.19 PoC 的刷机前置 |

---

## 6. 与 方案乙 K0 审计的交叉核对

| 项 | 方案乙 K0 结论 | 我的核对 |
| --- | --- | --- |
| `TARGET_KERNEL_CONFIG := vendor/xiaomi/mi845_defconfig` | 公共树定基础 defconfig，polaris.config 为追加片段 | **一致，采信**。修正了 `docs/09:13` 只提 polaris.config 的不完整表述 |
| `local_manifests` 三条 revision 是**分支名不是 commit pin** | 已否证「已锁到固定 commit」的表述 | **一致，采信**。我在 §4 补了一条支持证据：OnePlus 的 roomservice 按默认分支解析，所以分支级锁定确实是必要的，但不充分 |
| `BOARD_BOOT_HEADER_VERSION := 1`、`Image.gz-dtb` | 是构建变量，不等于实际产物 | **一致**。补一条判据：header v1 + DTB 附加意味着**无 `vendor_boot` 分区**，这正是 SDM845 不在 GKI 矩阵内的结构性证据（§2.3） |
| 内核版本 4.9 来自 wiki，属待证 | 标为待证，不能用源码 defconfig 代替 `/proc/config.gz` | **我已把它升级为已确证**：源码根 `Makefile` 实测 4.9.337（§1）。但方案乙的保留意见仍然成立——**源码版本 ≠ 设备当前运行版本**，后者只能由 首席 在 Phase 0 采集 |
| **无分歧项** | — | 两份报告在事实层面未发现冲突 |

---

## 7. 本次未能确证（不得当成已确认）

1. ~~高通官方是否完全没有 SDM845 的 msm-4.19/msm-5.4 发布~~ ——**已闭**：已确证 CAF msm-4.19/5.4 的
   `arch/arm64/configs/vendor/` 下都没有 sdm845 的 defconfig，CAF msm-4.9 才有（§2.1.1）。
2. ~~`sdm845-xiaomi-polaris.dts` 的完整节点清单~~ ——**已闭**。第三路调研用 `web_fetch` 取到 `git.kernel.org` cgit plain
   与 `raw.githubusercontent.com` 两份逐字节一致的全文，结论见 §3.3。原记录的取文件障碍（GitHub 原文件接口只返回
   「embedded resource unsupported」、`raw.githubusercontent.com` / `github.com/.../raw/` / jsdelivr 直连均失败、
   `web_search` 参数校验失败）仍属实，规避办法是走 `web_fetch` + `api.github.com/contents`（返回 base64，可解码）。
3. **【最关键】polaris 能否在 4.19.325 上启动，完全没有证据。**
   `meuira` 树的 43 个 polaris DTS 是从 Xiaomi 4.9 源码搬进 4.19 的；4.9 的 DT binding 与 4.19 有差异，
   能列出文件 ≠ 能编译 ≠ 能 probe ≠ 能启动。**我没有找到任何 polaris + 4.19 的启动日志或 CI 记录。**
   唯一找到的真实 4.19 启动日志是 Samsung STARQLTE（`AlexFurina/kernel_samsung_sdm845-419`），不是 polaris，不能外推。
   → 这正是 §5.4 PoC 要回答的第一个问题。
4. `meuira` 树的谱系与维护状态未查清：2026-09-28 单次推送的快照式仓库（0 star / 0 fork / 无 CI），
   与 `duckyduckG` 平台树（有持续提交）的关系没有确认（怀疑是「把 Xiaomi dts/techpack 搬进 duckyduckG 系 4.19 基线」，
   但**未验证**）。
5. 4.19 下 vendor blobs 的实际兼容性（闭源 HAL 能否在 4.19 的 techpack 接口上正常工作）。techpack 解决的是**内核侧**驱动，
   HAL 侧仍需实机验证；指纹（FPC/Goodix 私有 HIDL）、传感器（SSC on ADSP）、Keymaster/QSEE、ICE 加密这几项 techpack 不覆盖。
6. **polaris 分区表里有没有可用的 dtbo 分区**。4.19 用 `BOARD_KERNEL_SEPARATED_DTBO := true` 的独立 DTBO 布局，
   而本地 `fstab.qcom` 里没有 dtbo 条目。这条是 PoC 刷机的**前置阻塞**，只能由 首席 在 Phase 0 确认。
7. 设备**当前实际运行的**系统与内核版本。说明书称跑 iOS16 移植系统，本次未核实，`adb` 不在线。
   只由 首席 在 Phase 0 采集，不得用源码版本替代。
8. 主线路线下 TAS2559 智能功放、ICE 加密、Keymaster/QSEE 的替代方案是否存在。
   **收紧**：polaris 主线 dts 连声卡节点都没有，这个问题目前**还轮不到讨论**。
9. Nura 权威仓库 `device/archived/device-xiaomi-polaris/deviceinfo` 全文（只读到过期镜像版）。
10. ~~`CONFIG_RMI4` 在 arm64 defconfig 零命中——未经独立校验~~ ——**已闭**。
    主机官 用 `path:arch/arm64` 代码索引独立佐证 0 命中（commit `03643e7`），我也复核了 `path:arch/arm64/configs` 同样 0 命中。
    **且原因已查清**：polaris 的 4.9 实配根本不走 RMI4，走 `CONFIG_TOUCHSCREEN_SYNAPTICS_DSX_CORE_FORCE` + `FT5X46`（§3.1b）。
    §3.3.5 的 RMI4 结论只对**主线**的通用 defconfig 成立。
11. **【三重换料，全部未知】用户那台机器的实际硬件变体是哪一个——触屏 / 面板 / 指纹三项都没法从源码确定。**
    polaris 三个部件都是双供应商（§3.1b）：
    | 部件 | 变体 A | 变体 B | 主线 dts 覆盖 |
    | --- | --- | --- | --- |
    | 触屏 | FocalTech FT5X46 @0x38 | Synaptics @0x20 | **只覆盖 B** |
    | 面板 | JDI NT35596S | EBBG FT8716 | **只覆盖 A**（且无驱动） |
    | 指纹 | FPC | Goodix | 不适用（主线无指纹） |
    这直接决定**任何**移植路线对这台机器的起点，也会影响 4.19 路线的验证重点。
    **只能由 首席 在 Phase 0 采集**，建议命令（Android 侧，非 Android 则记为不可用）：
    ```sh
    dmesg | grep -i -e ft5x46 -e rmi4 -e nt35596 -e ft8716 -e fpc -e goodix
    ls /sys/bus/i2c/devices/*/name 2>/dev/null
    getprop | grep -i -e touch -e panel -e fingerprint
    ```
    **建议加进 Phase 0 清单**（与 主机官 已加的 dtbo 分区确认并列）。

---

## 8. 复现命令（供复核官与 评审官 验证）

```powershell
# 1. 内核版本（4.9.337）— GitHub 代码索引，固定 commit aa8adfe9
#    repo:LineageOS/android_kernel_xiaomi_sdm845 filename:Makefile PATCHLEVEL
#    → Makefile: VERSION = 4 / PATCHLEVEL = 9 / SUBLEVEL = 337

# 2. 4.19 分支 = vanilla tag 的决定性验证
#    list_branches(LineageOS/android_kernel_oneplus_sdm845) → lineage-23.2 = 84df9525b0c27f3ebc2ebb1864fa62a97fdedb7d
#    get_tag(torvalds/linux, v4.19)                         → object.sha = 84df9525b0c27f3ebc2ebb1864fa62a97fdedb7d
#    两者相同 ⇒ 该分支无任何厂商代码

# 3. Android 16 跑 4.9 的实证
#    list_branches(LineageOS/android_kernel_sony_sdm845) → lineage-23.0 = 1a8fc01dce4296fc3d5437dc4f2a713ecec621e9
#    repo:LineageOS/android_kernel_sony_sdm845 filename:Makefile SUBLEVEL → 4 / 9 / 337 / Roaring Lionus

# 3b. 【4.19 真实存在的决定性验证】
#    repo:meuira/android_kernel_xiaomi_sdm845_419，分支 lineage-23.2_xiaomi，HEAD 5cd18f0867338fb22a497bd8e8c881b13a7d857e
#    取 Makefile（api.github.com/contents 返回 base64，解码后头几行）：
#      VERSION = 4 / PATCHLEVEL = 19 / SUBLEVEL = 325 / NAME = "People's Front"   → Linux 4.19.325
#    目录列举 arch/arm64/boot/dts/xiaomi/polaris/  → 43 个 polaris DTS
#            arch/arm64/configs/vendor/xiaomi/     → polaris.config 等 8 个
#            arch/arm64/configs/vendor/            → sdm845-perf_defconfig + CAF 原有的 bengal/kona/lito/msm8937/sdm660
#            techpack/                             → display / camera-sdm845 / camera / audio / data / video / stub
#    注意：get_file_contents 对本环境返回「embedded resource unsupported」，
#          改用 web_fetch + https://api.github.com/repos/<owner>/<repo>/contents/<path>?ref=<branch> 可拿到 base64 内容。

# 3c. 官方设备树的 4.19 迁移状态（原文片段）
#    repo:LineageOS/android_device_oneplus_sdm845-common filename:BoardConfigCommon.mk TARGET_KERNEL_CONFIG
#      → TARGET_KERNEL_CONFIG := vendor/sdm845-perf_defconfig vendor/enchilada.config
#        BOARD_KERNEL_SEPARATED_DTBO := true        ← 4.19 布局，已迁移
#    repo:LineageOS/android_device_xiaomi_sdm845-common filename:BoardConfigCommon.mk TARGET_KERNEL_CONFIG
#      → TARGET_KERNEL_CONFIG := vendor/xiaomi/mi845_defconfig   ← 4.9 扁平布局，未迁移

# 4. 本地 blobs 与 HAL 绑定（在 C:\AiWork\Polaris-TerminalOS-repos\android_device_xiaomi_polaris）
$f = 'proprietary-files.txt'
(Get-Content $f | Where-Object { $_ -and $_ -notmatch '^#' }).Count        # 263
(Get-Content $f | Select-String -Pattern '\.ko$').Count                    # 0
Get-Content $f | Select-String -Pattern 'goodix|fpc|pn553|tas2559|ssc'
Get-Content $f | Select-Object -First 1                                    # MIUI V12.0.3.0.QDGMIXM
Get-Content init\fstab.qcom | Select-String -Pattern 'logical|ice|emmc'
Get-Content manifest.xml                                                   # keymaster@3.0 / secure_element@1.0 / goodix ext
```

验证说明：本报告所有 **[确]** 项均来自上述可复现查询或本地文件原文；
未执行 adb、未 boot、未刷写、未构建、未修改任何实现代码。
本文件是本次唯一写入产物（`_reviews/K2_CANDIDATES_C_O5.md`），在方案甲声明的写入范围内。

**修订记录**：
- v1（首次落盘）：判定 4.19「已否证可用」。
- v2（同日）：**撤回 v1 对 4.19 的否证**。错因：只检索 LineageOS 官方组织的仓库，未检索社区 fork，
  犯了「官方没有 = 不存在」的推断错误。现已并入社区 4.19.325 证据（§2.1.2），并把 4.19 上调为唯一升级 PoC 候选。
  同时修正 §3.1「换内核即 HAL 全废」的过强论证（techpack 覆盖 display/camera/audio，该论证只对主线成立）。
- v3（同日，按 复核官 返工意见）：① 撤回对 `docs/09` 的「乐观解读」错误归因——原文立场本就保守，
  且明确要求「继续核查是否有公开或半公开的 4.19 内核树」，我的 v2 是在执行它交办的事项；
  ② §5.1 裁决理由剔除 CAF 那条间接证据（原标 [疑]），并给 §2.1.1 加证据分级说明；
  ③ §4「Android 16 根本不需要新内核」收窄为「Sony SDM845 的 23.0 与 22.2 同 commit、内核未改动 ⇒ 未强制内核升级」。
- v4（同日，按 复核官 A1–A6 返工判据）：
  - **A「techpack 推翻 HAL 全废」说过头，已两次改正**：§3.1 改为三级表述表，最终口径为
    **「必然全废」→「待 uapi 验证」**（techpack 是内核侧源码，HAL 是闭源 `.so`，中间隔 uapi）。
  - **B §3.4 加「4.19 下游」列**：全列标注 **【待 uapi 验证】**，不写「可用」也不写「失效」。
  - **C 两条面板路线互不否证**：§3.4 末尾明确 E8（主线 DRM panel 404）与 E18（下游 fbdev `mdss_dsi_nt35596_read_status` 齐备）
    各自成立、互不推翻，禁止交叉引用否证。
  - **D DTS 计数口径对齐**：43 = 根 38 + `battery/` 3 + `display/` 2；复核官 的 41 是根目录少计 2。
  - **E 新发现（复核 官 D 项计数时发现）**：面板亦双供应商 —— `dsi-panel-ebbg-fhd-ft8716-video.dtsi`（EBBG **FT8716**）
    + `dsi-panel-jdi-fhd-nt35596s-video.dtsi`（JDI NT35596S），主线只声明后者。polaris 是**三重换料**机型，
    §7.11 已扩写为触屏/面板/指纹三张表并给出 Phase 0 采集命令。
  - **F §2.1 反转的可复现性**：URL、分支、HEAD commit、版本号、目录清单齐全（§2.1.2 + §8 第 3b 节）。
- v5（同日，并入并行第二路完整报告 + 本人复核）：
  - **撤回 v4 的错误判据**：我写过「`vendor/` 子目录是 4.19 专有布局」——**错**。4.9 两棵树都有 `vendor/`，
    4.9 xiaomi 树还有完整 `vendor/xiaomi/` 子目录。新增 §2.1.2b 给出**正确判据**：
    xiaomi 看 `vendor/xiaomi/mi845_defconfig` 是否存在（4.9 有、4.19 无）；oneplus 看 `vendor/enchilada.config`（4.9 无）。
    并写明这对 K3-01P P1 的具体动作要求。
  - **CAF 证据从「间接一手」升为 [确]**：第二路拿到 defconfig 目录原文并给出 project id + ref
    （msm-4.19 id 13110 @ `kernel.lnx.4.19.r37-rel`；msm-5.4 id 22241；msm-4.9 id 12600），可用 GitLab API 复现；
    阳性对照成立。仍按 复核官 意见，§5.1 裁决不依赖此条。
  - **补一条支持维持 4.9 的事实**：SDM845 的 CAF 4.9 线仍在收安全补丁，最新 tag `LA.UM.8.3.c25-13000-sdm845.0`
    target commit 日期 **2026-08-24** —— 高通把 845 的维护留在 4.9，未迁移。
  - **4.19 生态与启动证据补全**（§2.1.3）：列出 4 个活跃同源树（duckyduckG/EdwinMoq/meuira/AlexFurina），
    `EdwinMoq@lineage-24.0` 是 LineageOS 官方 oneplus 设备树所需配置的实际来源；
    `AlexFurina` commit `b24e86503d40…` 贴出 `Linux version 4.19.113 … Machine model: Samsung STARQLTE`
    真机启动日志 —— 证明**平台级能 boot**，但**不是 polaris**，不得外推。
  - **社区无 5.4/5.10 的 Android 厂商式移植**（第二路未搜到），补入 §2.1.3 限制第 5 条。
- v6（同日，并入第二路补遗）：
  - **§2.3 重写为「GKI 三条独立证据」**：① GKI 定义域 = **任何 5.10+ ACK（aarch64 only）**；
    ② 支持矩阵**最低一行是 Android 12**，无 4.9/4.14/4.19；③ 分区形态（vendor_boot 需 boot header v3+，
    而本项目是 v1；vendor_dlkm 必在 super 内，super 自 Android 10 才引入；本地 `fstab.qcom` 无这三个分区）；
    ④ CLO `KERNEL.PLATFORM.*` 分支在 msm-4.9 = 0、msm-5.4 = 0，四仓搜 `845` 全 0 命中。
  - **新增「引用纪律」6 条**（防评审官写错）：GKI 1.0/2.0 非官方术语；不要引 CDD；android12-5.4 与 5.10 非二选一；
    不存在「4.9 不适用 GKI」的单句原文（只能按推导表述）；「高通从未为 845 发 GKI」是强推论（CLO 全站搜索 API 401）；
    VSR 原文未取得（404），不得引用。
  - **证据来源如实标注（v6 时的状态，v7 已升级）**：§2.3 的 AOSP 原文由第二路子代理抓取（本机 `web_fetch` 对
    `source.android.com` 报 `SEC_E_NO_CREDENTIALS`），v6 时标为「二手·有 URL 可复核」。
    **v7 已改为：原始副本落盘进项目 + 逐条文件:行号:原句核对**，不再是二手。
  - **CAF 845 系列口径**：`LA.UM.8.3.*` / `LA.UM.10.3.*`，**无 8.1/8.2**（我文档此前只用过 8.3，无误）。
- v7（同日，按 首席 三条验收标准）：
  - **① 引文带「文件 : 行号 : 原句」**：§2.3 顶部改为四行核对表，每条给落盘路径 + 行号 + 逐字原句。
  - **② 二手证据落盘进项目**：`gki_research/` 已从临时工作区
    `C:\Users\Ely\.dsh\bot\workspace\gki_research` **移入** `_reviews/_evidence/gki_research/`
    （`raw/` 41 个 txt + 7 个被引用页面的**原始 HTML** 共 4.73 MB，含 `fetch.py` / `targets.json` / `REPORT.md`），
    新建 `MANIFEST.md` 记 URL↔文件映射、逐条引文核对、两个「零命中」断言的可复现命令、HTML 的 sha256、以及未核实项。
    终稿不再出现「二手·有 URL」这种表述。
  - **③ `super` 那句的质疑已澄清**：原文 410-411 确为 `For devices launching with Android 10, create a partition called super.`
    （折行跨两行）；首席担心的 "must not" 是**同文件 588-589 的另一个话题**（system-as-root），不是同一句。
    **引文无需降级。** 另发现 591 行原文承认 "retrofit dynamic partitions"，正面支持我 v6 的自我修正。
  - **④ 结论方向不动**：交付维持 4.9.337、4.19 只做 PoC、5.4/GKI 与主线不可行。
