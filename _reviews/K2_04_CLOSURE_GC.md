# K2-04 正式结案（复核官 · 交首席签字）

- 时间：2026-10-28
- 状态：**结案**。依据输入：`K2_CANDIDATES_C_O5.md` v6（方案甲，75621 B）、`K2_03_ABI_G_6.md`（方案乙，188 行）、首席 K2-04 定案口径、`_reviews/_evidence/gki_research/`（证据包）。
- 本文件取代 `K2_04_VERDICT_GC.md` §0/§6 的过程状态；过程与自更正记录仍保留在 `K2_04_VERDICT_GC.md`。
- 未执行 adb / boot / 刷写 / 构建。写入范围：仅本文件。

---

## 1. 结案结论

| 项 | 结论 |
| --- | --- |
| **交付线内核版本** | **Linux 4.9.337**，`LineageOS/android_kernel_xiaomi_sdm845` @ `lineage-22.2` = `aa8adfe9bf212c6e93238a86980b4024da4f819a` |
| **fallback** | **无同路线 fallback**（4.19 未获任何构建/启动证据，不作为 fallback） |
| **4.19** | **不否定、不背书**；保留独立 PoC（K3-01P），不阻塞交付 |
| **5.4 / GKI** | 不可行（官方定义域外 + 分区载体缺失） |
| **5.10+ 主线** | 不可行（换产品形态） |
| **K2-01 / K2-02 / K2-03** | 全部 **可验收** |

---

## 2. 结案理由（按首席口径，只写三条）

> **纪律**：以下三条是唯一的结案理由。「5.10 主线 5/5 失效」**不得**写进维持 4.9 的理由——它只能排除 5.10，不能证明 4.9 正确。

| # | 理由 | 证据 |
| --- | --- | --- |
| **1** | **无构建、无实机启动证据** | P0-08 构建机未落地（本机 Windows 23.7 GB，需 Linux ≥64 GB / ≥400 GB）；Phase 0 未做，设备 `adb devices` 为空。4.19 树与 4.9 交付线均**无任何本项目自己的构建产物或启动日志** |
| **2** | **23.2 路线缺的是 Android 16 适配，不是「没有设备树文件」**（措辞经评审官纠正后逐字核过） | ① **内核与 blobs 无 23.2 分支**（内核仓最高 `lineage-22.2`=`aa8adfe9`；TheMuppets polaris blobs 最高 `lineage-22.2`=`9e970795`）。② **设备树**：上游 `lineage-23.2` 分支**存在**，但 sha 与 `lineage-22.2` **完全相同**（均 `1b46255cfa29026819b9177f1c7f73ee72388e76`）——即零 Android 16 适配提交。③ 我方两个 `terminalos/*` 分支只是在该基线上各加 1 个产品配置提交（`d124800` 与 `a7f8017`，**改动完全相同：3 文件 / +74 −1**）；`d124800` 的 commit message 自己写着「upstream lineage-23.2 device tree is currently identical to lineage-22.2 and **has no Android 16 adaptation commits**, kernel/vendor blob 23.2 branches are missing」。→ 真阻塞是「内核 + blobs + Android 16 适配」三缺，**换内核只补其中一件** |
| **3** | **单点维护、零 CI** | 4.19 候选 `meuira/android_kernel_xiaomi_sdm845_419`：个人账户、单分支、0 fork、4 star；HEAD `5cd18f08` 作者日期 **2026-05-22**（停滞约 5 个月）；无 CI、无构建产物、无实机验证记录。树上自带未修复缺陷：`516e794d`（perseus UAF kernel panic revert）、`02cf2eb9`（display doze/fod 破坏 dt2w） |

---

## 3. 4.19 的定性（既不许当交付依据，也不许当已否证）

- **成立的事实**：`meuira/android_kernel_xiaomi_sdm845_419` 是真实 4.19.325 下游移植，polaris DTS 进 Makefile（6 个 dtb 目标），techpack 齐全，面板驱动完整（`mdss_dsi_nt35596_read_status`）。**我原「4.19 无候选」的结论已撤回**（记录见 `K2_04_VERDICT_GC.md` §9）。
- **不成立的说法**：方案甲 v2/v6 曾以「4.19 必须独立 DTBO、polaris 没 dtbo 分区、所以 PoC 不能做」为由设阻塞——**该推论被否**。meuira `sdm845-perf_defconfig` 含 `CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE=y`，可走 appended 路径，不需 dtbo 分区。**dtbo 分区因此不再是 P3 的前置门槛，降为 P2 的一项检查**（首席已确认撤回该硬性前置）。
- **P1/P2 的开工条件（首席 2026-10-28 定稿要求，原表述已改）**：P1/P2 **不占设备**，但**仍需要 Linux 构建机**——P0-08 未落地、用户四个选项未回。所以现状是「**不占设备、卡在构建机**」，**不是「现在就能做」**。原文「P1/P2 现在就能做」不准确，已按此更正。
- **PoC 的定位**：研究项。**它不改变交付线，交付线也不因它停摆。**

---

## 4. K2-03 复核结论（我独立读过全文，分层如下）

方案乙交付的 5/10 结论我认可，但**「0 项确证失效」不得被读成「4.19 兼容性已验证」**。证据强度必须分层：

| 层级 | 项数 | 对象 | 可否作为「可交付」依据 |
| --- | --- | --- | --- |
| 结构体字段级保持 | 1 | FastRPC / ADSP——**方案乙已收窄为「ioctl 编号 + 结构体尺寸级保持」**：16 条 `FASTRPC_IOCTL_*` 宏差集为空；`fastrpc_ioctl_control` 的 union 成员变了（去 `smmu`、加 `wakelock`/`pm`）但 union 仍 8 B、结构体仍 12 B、ioctl 号不变；`fastrpc_ctrl_latency` 仅 `level`→`latency` 改名。**语义级差异仅 CONTROL 的 SMMU 请求处理** | 可（但不得写成「完全一致」） |
| **节点名/宏名级保持，数值未验** | **3** | SSC（`smdpkt`）、QSEECOM（`/dev/qseecom` + ioctl 名）、ICE（`iceufs`/`icesdcc`） | **否**——ioctl 数值/结构体未比对 |
| **有差异、风险未排除** | **1** | CamX（`msm_camera.h` 83 条宏全等，但 `cam_isp`/`cam_sensor` 结构体未逐字段比对） | **否** |
| **条件失效** | **2** | ① `sde_drm_scaler_v2` 尾部 +8×`uint32_t`（**+32 B**），`SDE_DRM_BLEND_OP_MAX` 4→5；② `POWER_SUPPLY_PROP_*` 4.9 有 7 个在 4.19 被删（`ALLOW_HVDCP3`、`MAX_PULSE_ALLOWED`、`IGNORE_FALSE_NEGATIVE_ISENSE`、`BATTERY_INFO`、`BATTERY_INFO_ID`、`ENABLE_JEITA_DETECTION`、`QG_VBMS_MODE`） | **否**——取决于 HAL 是否真用 |
| 确证失效（4.19） | 0 | — | — |

> 方案乙自己写明「K2-03 不能用来否 4.19 路线」，我确认这句成立，也确认他 §4.1 第 5 条（不拿 0 个 `.ko` 当免检）执行到位：他把「0 个模块」转成「无模块 ABI 可谈，ABI 面只剩字符设备/ioctl」，这是正确用法。

---

## 5. K3-01P（4.19 PoC）待验清单——押 4.19 前必须补的牌

| # | 项 | 判据 | 谁来 |
| --- | --- | --- | --- |
| P1 | 编译 | 用 polaris 配置链（`vendor/xiaomi/mi845_defconfig` + `polaris.config` 合并）对 meuira 树编译，产出 `Image.gz-dtb`；日志留档 | 主机官。**卡：P0-08 Linux 构建机**（不占设备） |
| P2 | DTB 产物 | `unpack_bootimg`/`abootimg` 确认 polaris dtb 真 appended 且正确；**dtbo 检查降为本题内的一项**（仅当确认必须独立 DTBO 时才停），不得盲刷 | 主机官。**卡：P0-08**（不占设备） |
| P3 | 点亮 | 实机 boot 到 UI，`uname -a` 显示 4.19.325 | **首席**（Phase 0 后） |
| P4 | 显示/触摸 | 屏幕亮、触摸可用；**注意** polaris 触屏可能是双供应商（FocalTech `ft5x46` @0x38 与 Synaptics），需确认实际机型对应 | 首席 |
| P5 | 充电/电量 | power_supply 7 属性缺失项是否被 HAL 引用 | 首席 + 方案乙 |
| P6 | CamX 结构体 | `cam_isp`/`cam_sensor` 逐字段比对（唯一的 K2-03 未闭合项） | 方案乙 |
| P7 | `sde_drm` scaler_v2 | blobs 反汇编确认 Composer 是否用 scaler_v2（+32 B 风险） | 方案乙 |

**任一 P1–P3 失败 ⇒ 4.19 闭环为「不可行」，不再投入。**

---

## 6. 方案甲证据包验收（首席验收标准 ① ②）

**① 引文（文件名 + 行号 + 原句）——我逐条独立核对，全部命中**

> **级别限定（与评审官口径一致，不得被终稿抹成「一手」）**：以下核对的对象是**项目内证据副本**（`_evidence/gki_research/raw/*.txt`，由 `fetch.py` 抓取落盘），属「**副本已核**」，**不等于「一手直连核对」**。本机对 `source.android.com` 报 `SEC_E_NO_CREDENTIALS`，是环境限制，我不冒充能补。终稿应写「副本已核 + URL 可复查」，不写「已一手核实」。：

| 引文 | 位置 | 我读到的原句 |
| --- | --- | --- |
| GKI 定义域 | `_evidence/gki_research/raw/kernel_overview.txt:469` | `Any 5.10 and higher ACK kernel(aarch64 only). The GKI kernel has these` |
| dlkm 在 super 内 | `raw/vendor_odm_dlkm.txt:440` | `vendor_dlkm and odm_dlkm partitions are located in the super partition as` |
| vendor_boot header v3 | `raw/vendor_boot.txt:425` | `11 devices can use boot image header version 3. In` |
| super 由 Android 10 引入 | `raw/dynamic_partitions.txt:410-411`（折行） | `For devices launching with Android 10, create` / `a partition called super. The super` |
| 首席指出的 588 行偏差 | `raw/dynamic_partitions.txt:588-589` | `Devices launching with Android 10 must not` / `use system-as-root.`——**确属 system-as-root，与 super 无关**，方案甲的澄清成立 |
| **v6 修正的正向依据** | `raw/dynamic_partitions.txt:591-592` | `Devices with dynamic partitions (whether it launches with or retrofits dynamic partitions) must not use system-as-root.`——**retrofit 有原文支持**，polaris 有 super 的论证成立 |

**② 落盘路径——已入项目 git，可审计（我实测复核，commit 见下）**：

| 项 | 实测 |
| --- | --- |
| 路径 | `C:\AiWork\Polaris-TerminalOS\_reviews\_evidence\gki_research\` |
| 落盘 commit | **`923d2ed`**（证据包）+ **`247405e`**（INDEX.md 补全 41 个 txt 全量映射） |
| 内容 | `raw/` **41 txt + 7 html**；目录内 **55 文件 / 4,978,459 字节**（≈4.74 MiB）；`git ls-files` = **55，全部受版本控制** |
| 字节保真 | `_reviews/_evidence/.gitattributes` 含 `* -text`；实测 `git check-attr text -- …dynamic_partitions.html` → **`text: unset`**。⇒ 该目录内 **sha256 可当证据**，MANIFEST 的校验在 checkout 后仍成立 |
| 旧位置 | `C:\Users\Ely\.dsh\bot\workspace\gki_research\`（87 文件 / 12.16 MB，41 txt + **41 html**）为子代理临时抓取区，**已非权威**；差集是 34 个未被引用的 HTML |

> **结论**：不是谁编错数，是**量的对象不同**——项目内是「41 txt 全量 + 仅被引用的 7 个 HTML」，源目录是全量 41 HTML。**引文可复核性不受影响**（41 个 txt 全在、被引用页 HTML 全在）。`fetch_log.json` 只覆盖 5 个 URL 的缺口，已由 `247405e` 的 INDEX.md **补齐**。

---

## 7. K2 交付状态表（交首席）

| 交付 | 负责人 | 状态 |
| --- | --- | --- |
| K2-01 候选源码调研 | 方案甲 | **可验收**（v6；4.19 反转已改，A7/A8 已按我口径修订） |
| K2-02 驱动覆盖评估 | 方案甲 | **可验收**（v6 已补 4.19 下游列） |
| K2-03 模块 ABI 与 vendor 接口评估 | 方案乙 | **可验收**（分层见 §4，残余项转 PoC 待验） |
| K2-04 候选裁决 | 复核官 | **结案**（本文件） |
| K3-01P 4.19 PoC | 待指派 | **卡在 P0-08 Linux 构建机**：P1/P2 不占设备，但必须在构建机上跑；P3 起还需 Phase 0 + 首席 |
| **manifest 基线一致性（新增，需立刻处理）** | **主机官** | **不一致**：`local_manifests/terminalos.xml` 仍 pin `lineage-23.2`，而本结案定的是 **22.2 基线**；且三个工作仓已切到 `terminalos/lineage-22.2`（device `a7f8017`），vendor/home 本地仓还未配 `origin`。**若不改，构建输入与结案口径自相矛盾**。改法：manifest 的 `revision` 全部改 22.2，并在构建前按 §5.1 做 sha 校验；同时给 vendor/home 补 `origin` 远端。**这属于 主机官 范围，我不代改。** |
| K4-01 最终版本裁定 | 复核官 | 口径已定：**「平台移植目标，内核维持 4.9.337，未做升级」**，不得宣称内核已升级 |

---

## 8. 我未能确证、不得当成已确认

1. 设备当前实际运行系统与内核——`adb` 离线，只由首席在 Phase 0 采集，源码版本不能替代。
2. `sde_drm`/`power_supply` 两项条件失效**是否真的发生**——取决于 polaris 的 HAL 是否引用，需 blobs 反汇编。
3. CamX 结构体尺寸（K2-03 唯一未闭合项）。
4. 4.19 树能否为 polaris 编出并点亮——**零证据**，这正是 PoC 要回答的。

---

本文件为复核官对 K2-04 的最终结案。未越范围、未代改他人实现、未碰设备。
