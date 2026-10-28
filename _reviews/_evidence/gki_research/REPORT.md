# Android GKI 与 Qualcomm SDM845 支持范围 — 证据报告

> 所有引文均来自本会话实际 fetch 成功（HTTP 200、TLS 证书校验通过）的页面。
> 环境限制见文末「取证环境与局限」。

---

## 1. kernel/common 仓库与分支真实性 —— 「CONFIRMED」

数据源：`https://android.googlesource.com/kernel/common/+refs` (HTTP 200，解析出 470 个唯一 `refs/heads/`)

问题中列举的 6 个分支**全部真实存在**，另外还确认了更多：

| 分支 | 存在 |
|---|---|
| android11-5.4 / android11-5.4-lts | ✓ |
| **android12-5.4 / android12-5.4-lts** | ✓ |
| **android12-5.10 / android12-5.10-lts** | ✓ |
| android13-5.10 / android13-5.15 | ✓ |
| android14-5.15 / android14-6.1 | ✓ |
| android15-6.6 | ✓ |
| android16-6.12 / android17-6.18 / android18-7.3 | ✓ |

**关键纠正**：问题假设「android12-5.4 vs android12-5.10 哪个真实存在」是二选一 —— 实际上**两者都存在**。
二者的区别不在于 git 分支是否存在，而在于**是否出现在 GKI 支持矩阵里**（见第 3 节：Android 12 行只列 android12-5.10）。

镜像交叉验证：`https://api.github.com/repos/aosp-mirror/kernel_common/branches?per_page=100`（返回 100 条，含 `android12-5.4`、`android12-5.4-lts`、`android12-5.10`）。

### 4.9（SDM845 出厂内核）在 kernel/common 中的状态
- 现存 heads 中**没有** `android-4.9-*` 形式的 ACK 分支；仅剩 `android-trusty-4.9`、`upstream-linux-4.9.y`、`upstream-f2fs-stable-linux-4.9.y`。
- 但 tag 中保留了该世代谱系（共 5742 个 tag），例如：
  `ASB-2017-11-06_4.9-o-mr1`、`ASB-2018-01-05_4.9-o-mr1`、`ASB-2018-04-05_4.9`
  → `-o-mr1` = Oreo MR1 = **Android 8.1**。说明 4.9 ACK 属于**按 Android 版本代号命名的 pre-GKI 世代**，而非后来的 `androidXX-K.K` KMI 命名体系。

---

## 2. GKI 适用范围的原文规则 —— 「CONFIRMED」

### 2.1 GKI 的强制适用条件
`https://source.android.com/docs/core/architecture/kernel/generic-kernel-image`

> "Beginning with Android 12, devices shipping with kernel version 5.10 or higher **must** ship with the GKI kernel."

> "The GKI kernel doesn't contain SoC-specific or board-specific code."

> "The GKI kernel is a single-kernel binary plus associated loadable modules per architecture, per LTS release."

### 2.2 GKI 的定义性边界：5.10+ 且仅 aarch64
`https://source.android.com/docs/core/architecture/kernel`

> "ACKs that are **5.10 and higher** are also known as generic kernel images (GKI) kernels."

术语表原文：

> "**Generic Kernel Image (GKI) kernel** — Any **5.10 and higher** ACK kernel (**aarch64 only**)."

> "Kernel with versions of 5.10 and higher are also referred to as Generic Kernel Image (GKI) kernels."

**这是把 4.9（SDM845 出厂内核）排除在 GKI 之外的最直接定义性证据**：GKI ≡ 5.10+ ACK，4.9 根本不在该定义域内。

同页另有一句直接针对「老设备升级」场景：

> "Android 12 features can't be backported to 4.19 kernels; the feature set would be similar to a device that **launched with 4.19 on Android 11 and upgraded to** Android 12."

### 2.3 「GKI 1.0 / GKI 2.0」术语 —— 「UNVERIFIED」
对本次抓取的全部 30+ 个 AOSP 页面做正则 `GKI (1\.0|2\.0)` 检索，**零命中**。

- GKI 项目页只提到 "this project and its **phases**"，但**未**使用 "1.0"/"2.0" 标签。
- 结论：**「GKI 1.0 = Android 11/5.4，GKI 2.0 = Android 12/5.10」是社区/生态约定俗成的说法，不是我能在 source.android.com 上引到的官方措辞。**请勿把它当成可引用的官方术语。

### 2.4 但 android12-5.4 确实是真实的 GKI KMI —— 「CONFIRMED」
`https://source.android.com/docs/core/architecture/kernel/gki-versioning`

该页**自身的示例**就使用 5.4：

> Kernel release 示例：`5.4.42-android12-0-foo`
> KMI version 示例：`5.4-android12-0`
> Kernel branch 示例：`android12-5.4`

> "KernelRelease := Version.PatchLevel.SubLevel-AndroidRelease-KmiGeneration-suffix"

→ 即 `android12-5.4` 是一个真实存在、有正式 KMI 版本号的 GKI 内核分支（服务于「Android 11 出厂 + 5.4，升级到 Android 12」的设备），只是**不在 Android 12 的出厂支持矩阵中**。

---

## 3. 内核版本 / 发布版本支持矩阵 —— 「CONFIRMED」

数据源：`https://source.android.com/docs/core/architecture/kernel/android-common`
（锚点 `#compatibility-matrix`）

### 3.1 Compatibility matrix（原文表格，完整转录）

> "This table shows the kernel versions supported and tested with each Android platform release."

| Android platform release | Supported kernels |
|---|---|
| Android 17 (2026) | android17-6.18, android16-6.12, android15-6.6, android14-6.1, android14-5.15, android13-5.15, android13-5.10 *(not supported in Android 17 QPR1 or higher)*, android12-5.10 *(not supported in Android 17 QPR1 or higher)* |
| Android 16 (2025) | android16-6.12, android15-6.6, android14-6.1, android14-5.15, android13-5.15, android13-5.10, android12-5.10 |
| Android 15 (2024) | android15-6.6, android14-6.1, android14-5.15, android13-5.15, android13-5.10, android12-5.10 |
| Android 14 (2023) | android14-6.1, android14-5.15, android13-5.15, android13-5.10, android12-5.10 |
| Android 13 (2022) | android13-5.15, android13-5.10, android12-5.10 |
| **Android 12 (2021)** | **android12-5.10（仅此一个）** |

**三个load-bearing的结构性事实：**
1. 矩阵**最低一行就是 Android 12**。Android 11 及更早**完全没有行** → Android 8.1 不在矩阵内。
2. 矩阵中**不存在任何 4.9 / 4.14 / 4.19 内核**。
3. Android 12 行**只有 android12-5.10**，`android12-5.4` 不在其中（印证第 2.4 节：5.4 走的是升级路径，不是出厂路径）。

### 3.2 ACK 生命周期表（同一 URL）

| ACK branch | Launch date | Support lifetime (years) | EOL |
|---|---|---|---|
| android12-5.10 | 2020-12-13 | 6 | 2027-07-01 |
| android13-5.10 | 2020-12-13 | 6 | 2027-07-01 |
| android13-5.15 | 2021-10-31 | 6 | 2028-07-01 |
| android14-5.15 | 2021-10-31 | 6 | 2028-07-01 |
| android14-6.1 | 2022-12-11 | 6 | 2029-07-01 |
| android15-6.6 | 2023-10-29 | 4 | 2028-07-01 |
| android16-6.12 | 2024-11-17 | 4 | 2029-07-01 |
| android17-6.18 | 2025-11-30 | 4 | 2030-07-01 |

> "Beginning with kernel 6.6, the support lifetime for the stable kernels is 4 years."

→ **android11-5.4 与 android12-5.4 均未出现在受支持 ACK 列表中**（已 EOL / 不再维护）。
> "When kernels are EOLed, they are no longer supported by Google and devices running them are considered to be vulnerable."

### 3.3 launch vs upgrade 的官方规则（同一 URL）

> "GKI kernels are supported for their **initial and subsequent releases only**. They **aren't supported for older releases**. So an android15-6.6 kernel is not supported for devices running Android 14 (2023)."

> "GKI kernels maintain backward compatibility with all Android platform releases that supported the kernel version. Additionally, the Android platform releases are backward-compatible with GKI kernels from previous releases. So you can safely use the android14-6.1 kernel developed for Android 14 (2023) on devices running Android 15 (2024)."

> "KMI compatibility isn't maintained between different GKI kernels. So, for example, an android14-6.1 kernel cannot be replaced with an android15-6.6 kernel without rebuilding all modules."

> "For the lifetime of the GKI kernel, backward compatibility with userspace is maintained so that the kernel can safely be used for the Android platform release **the device was launched with**."

### 3.4 CDD 并非 GKI 矩阵的来源 —— 「DISPROVED」
抓取并全文检索了三份 CDD：
- `https://source.android.com/docs/compatibility/11/android-11-cdd`
- `https://source.android.com/docs/compatibility/12/android-12-cdd`
- `https://source.android.com/docs/compatibility/15/android-15-cdd`

**三份 CDD 中字符串 "GKI" 与 "Generic Kernel Image" 命中次数均为 0。**
CDD 只在安全上下文里提到内核（seccomp-BPF/TSYNC、`CONFIG_CC_STACKPROTECTOR_STRONG`、`CONFIG_INIT_ON_ALLOC_DEFAULT_ON`、SELinux、fscrypt / dm-default-key 等），**没有**按 launch level 规定内核版本的表格。

→ 原任务假设「CDD 里有 launch-level 内核矩阵」**不成立**。权威矩阵在第 3.1 节的 android-common 页面上。

### 3.5 「Android 8.1 + 4.9 明确不在 GKI 范围内」 —— 「CONFIRMED（推导）／无单句原文」
我**没有**找到一句点名 "Android 8.1" 或 "4.9" 说「不适用 GKI」的原文。该结论由三条已确证事实**合成**，每条都有原文：
1. GKI ≡ **5.10 及以上** ACK（仅 aarch64）—— 2.2 节；4.9 不在定义域。
2. 支持矩阵**下限为 Android 12** —— 3.1 节；Android 8.1 无对应行。
3. GKI 测试义务绑定于 "launching with Android 11 on the 5.4 Linux kernel" —— 4.1 节；Android 8.1 出厂设备不承担该义务，也不具备相应分区形态。

请按「推导结论 + 三条直接证据」表述，不要声称有单句原文。

---

## 4. vendor_boot / vendor_dlkm / system_dlkm 的引入与强制时点 —— 「CONFIRMED」

### 4.1 vendor_boot 与 boot image header 版本
`https://source.android.com/docs/core/architecture/partitions/vendor-boot-partitions`

> "Android 11 introduced the concept of the Generic Kernel Image (GKI). To enable booting an arbitrary device with the GKI, Android 11 devices can use **boot image header version 3**. In version 3, all vendor-specific information is factored out of the boot partition and relocated into a new **vendor_boot partition**. An ARM64 device **launching with Android 11 on the 5.4 Linux kernel must support the vendor_boot partition** and the updated boot partition format **to pass testing with the GKI**."

> "Android 12 devices can use **boot image header version 4**, which supports including multiple vendor ramdisks in the vendor_boot partition."

> "The vendor boot partition is A/B-ed with virtual A/B and protected by Android Verified Boot."

**与你已确证的 `BOARD_BOOT_HEADER_VERSION := 1` 直接咬合**：vendor_boot 机制自 header **v3** 起才存在；SDM845 设备树是 **v1**，即比 vendor_boot 的引入早两个版本 —— 结构上不存在 vendor_boot 分区。

### 4.2 vendor_dlkm / odm_dlkm
`https://source.android.com/docs/core/architecture/partitions/vendor-odm-dlkm-partition`

> "**Android 11 introduces** the concept of the Generic Kernel Image and the vendor boot partition. The vendor boot partition stores kernel modules compatible with GKI, and is loaded by first stage init. Kernel Modules **prior to Android 11's release** are also stored in vendor and ODM partitions, and are loaded by vendor processes."

> "**For Android 11 or higher**, the kernel and all kernel modules can be updated independently from the rest of the partitions. To enable updates for kernel modules stored in the vendor partition (without a vendor partition update), move all vendor partition modules to a new partition called **Vendor DLKM** (dynamically loadable kernel module)."

> "**vendor_dlkm and odm_dlkm partitions are located in the super partition as another dynamic partition.**"

**这是 SDM845 不可能有官方 vendor_dlkm 的决定性结构证据**：vendor_dlkm 必须位于 `super` 动态分区内；你已确证 SDM845 设备无 super / dynamic partition。

### 4.3 system_dlkm（Android 13+ 强制）
`https://source.android.com/docs/core/architecture/partitions/gki-partitions`

> "**Note: Any device launching with Android 13 and higher must include a system_dlkm partition.**"

> "GKI and GKI modules can be updated independently from the rest of the partition because GKI modules reside on a separate **dynamic partition in the super image called system_dlkm**."

> "The system_dlkm partition is **located in the super partition as another dynamic partition**."

> "For modules to load successfully at runtime, GKI and GKI modules must be built together."

### 4.4 super / dynamic partitions 本身是 Android 10+ 的出厂特性
`https://source.android.com/docs/core/ota/dynamic_partitions/implement`

> "This section details how to implement dynamic partitions on new devices **launching with Android 10 and higher**."

> "For devices **launching with Android 10**, create a partition called **super**."

> "Devices **launching with Android 12 or later must use** bootconfig to pass `androidboot.force_normal_boot=1`."

> "Devices **launching with Android 12 or later must use** bootconfig to pass `androidboot.boot_devices` to init."

→ SDM845 于 **Android 8.1** 出厂，比 dynamic partition 的引入（Android 10）还早两代，因此 GKI 所依赖的整条分区基础设施（super → vendor_dlkm / system_dlkm）在其出厂形态上均不存在。

---

## 5. Qualcomm / CLO 是否为 SDM845 发布过 GKI 版本 —— 「强证据支持『否』，但非穷尽证明」

### 5.1 clo/la/kernel 仓库清单 —— 「CONFIRMED」
`https://git.codelinaro.org/api/v4/groups/clo%2Fla%2Fkernel/projects?per_page=100&order_by=name&sort=asc`（HTTP 200，46 个 project）

内核仓库谱系：`msm-3.10`、`msm-3.14`、`msm-3.18`、`msm-4.4`、**`msm-4.9`**、`msm-4.14`、`msm-4.19`、`msm-5.4`、`msm-5.10`、`msm-5.15`，另有 `common`、`ark-5.14`、`ark-6`、`ark-6.9`、`gs`、`exynos`、`build`、`configs`、`manifest`、`superproject` 等。

### 5.2 KERNEL.PLATFORM 发布列只存在于 5.10/5.15 —— 「CONFIRMED」
逐仓库拉取 branch 列表并统计 `KERNEL.PLATFORM` 前缀：

| 仓库 | KERNEL.PLATFORM.* 分支数 | 实例 |
|---|---|---|
| `clo/la/kernel/msm-4.9` | **0** | —（仅 LA.UM.* 列） |
| `clo/la/kernel/msm-5.4` | **0** | —（仅 LA.UM.* 列） |
| `clo/la/kernel/msm-5.10` | 3 | `KERNEL.PLATFORM.1.0.c25/.c26/.c27` |
| `clo/la/kernel/msm-5.15` | 1 | `KERNEL.PLATFORM.2.0.c25` |

URL：
- `https://git.codelinaro.org/api/v4/projects/clo%2Fla%2Fkernel%2Fmsm-4.9/repository/branches?per_page=100`（及 `&page=2`）
- `https://git.codelinaro.org/api/v4/projects/clo%2Fla%2Fkernel%2Fmsm-5.4/repository/branches?per_page=100`
- `https://git.codelinaro.org/api/v4/projects/clo%2Fla%2Fkernel%2Fmsm-5.10/repository/branches?per_page=100`
- `https://git.codelinaro.org/api/v4/projects/clo%2Fla%2Fkernel%2Fmsm-5.15/repository/branches?per_page=100`

→ GKI 时代的 `KERNEL.PLATFORM`（kernel-platform）发布体系**从未出现在 msm-4.9 / msm-5.4 上**。

`msm-4.9`（SDM845 世代）的发布列全部是旧式 `LA.UM.*`：
`LA.UM.7.3.c25`、`LA.UM.7.6.2.c25–c27`、`LA.UM.8.3.c25–c26`、`LA.UM.8.6.2.c25–c31`、`LA.UM.8.8.c25`、`LA.UM.8.8.1.c25`、`LA.UM.8.8.2.c25`、`LA.UM.9.6.2.c25–c28`、`LA.UM.9.8.c25–c27`、`LA.UM.10.3.c25`、`LA.UM.10.6.2.c25–c26`，另含 `msm-5.10` 上的 `aosp-new/android12-5.10/android-4.14-q` 等桥接分支。

### 5.3 芯片名检索 —— 「CONFIRMED（阴性）」
在上述四个仓库的全部 branch 名中检索 `845`：**全部为 0 命中**（与你侧 msm-5.10/5.15 搜 sdm845 为空的结论一致）。
注：CLO branch 采用 `LA.UM.x.y` / `KERNEL.PLATFORM.x.y` 发布列命名，不直接带芯片名，故此项为支持性而非决定性证据。

### 5.4 kernel_platform 组存在但无直属 project —— 「CONFIRMED」
- `https://git.codelinaro.org/api/v4/groups/clo%2Fla%2Fkernel_platform` → `projects` 数组为空（`projects=0`）
- `https://git.codelinaro.org/api/v4/groups/clo%2Fla%2Fkernel_platform/subgroups?per_page=100` → 9 个子组：
  `bootable`、`build`、`external`、`kernel`、`prebuilts`、`system`、`test`、`toolchain`、`tools`
  （即 GKI 构建树布局，对应 GKI 时代的 kernel-platform 结构）

### 5.5 局限 —— 「UNVERIFIED」
- `https://git.codelinaro.org/api/v4/search?scope=projects&search=sdm845` → **HTTP 401 Unauthorized**
- `https://git.codelinaro.org/api/v4/search?scope=projects&search=kernel-platform` → **HTTP 401 Unauthorized**

CLO 全站关键词搜索需要鉴权，我无法执行。因此「Qualcomm 从未为 SDM845 发布 GKI / kernel-platform 版本」是依据**仓库与分支结构**得出的强推论，**不是穷尽式证明**。

---

## 结论汇总

| # | 命题 | 判定 |
|---|---|---|
| 1 | kernel/common 存在；6 个被问分支全部真实 | 「CONFIRMED」 |
| 1b | android12-5.4 与 android12-5.10 **都**存在（非二选一） | 「CONFIRMED」 |
| 2 | GKI ≡ 5.10+ ACK（aarch64 only）；Android 12 起 5.10+ 设备**必须**用 GKI | 「CONFIRMED」 |
| 2b | 「GKI 1.0 / GKI 2.0」为官方术语 | 「UNVERIFIED」（AOSP 页面零命中，属社区说法） |
| 3 | 支持矩阵下限 = Android 12；无任何 4.9/4.14/4.19 内核 | 「CONFIRMED」 |
| 3b | CDD 含 launch-level 内核矩阵 | 「DISPROVED」（三份 CDD "GKI" 零命中） |
| 3c | Android 8.1 + 4.9 不在 GKI 范围 | 「CONFIRMED（由 3 条原文推导，无单句原文）」 |
| 4 | vendor_boot 自 boot header **v3** / Android 11 引入；v4 起 Android 12 | 「CONFIRMED」 |
| 4b | vendor_dlkm / system_dlkm **必须**位于 super 动态分区 | 「CONFIRMED」 |
| 4c | super/dynamic partition 是 Android 10+ 出厂特性 | 「CONFIRMED」 |
| 5 | Qualcomm 无 SDM845 的 GKI/kernel-platform 发布 | 「强证据支持，非穷尽」（CLO 搜索 API 401） |

**综合判定：SDM845 处于 GKI 支持矩阵之外。** 三条相互独立的结构性理由，每条都有原文支撑：
1. **内核版本**：GKI 定义为 5.10+ ACK；SDM845 出厂 4.9，升级链最高也只到 4.9/4.14 世代，从未进入 5.10。
2. **分区形态**：GKI 依赖 vendor_boot（boot header v3+）与 super 内的 vendor_dlkm/system_dlkm；SDM845 为 boot header v1 且无 super。
3. **厂商供给**：CLO 的 GKI 时代 `KERNEL.PLATFORM` 发布列只存在于 msm-5.10/msm-5.15，msm-4.9 从未有过。

---

## 最 load-bearing 的 URL

1. `https://source.android.com/docs/core/architecture/kernel/android-common` —— 支持矩阵 + ACK 生命周期 + launch/upgrade 规则（第 3 节全部引文）
2. `https://source.android.com/docs/core/architecture/kernel` —— GKI 定义："Any 5.10 and higher ACK kernel (aarch64 only)"
3. `https://source.android.com/docs/core/architecture/kernel/generic-kernel-image` —— "Beginning with Android 12, devices shipping with kernel version 5.10 or higher must ship with the GKI kernel."
4. `https://source.android.com/docs/core/architecture/partitions/vendor-boot-partitions` —— boot header v3/v4 与 vendor_boot 的 GKI 测试义务
5. `https://source.android.com/docs/core/architecture/partitions/vendor-odm-dlkm-partition` —— "vendor_dlkm and odm_dlkm partitions are located in the super partition as another dynamic partition."
6. `https://source.android.com/docs/core/architecture/partitions/gki-partitions` —— "Any device launching with Android 13 and higher must include a system_dlkm partition."
7. `https://source.android.com/docs/core/ota/dynamic_partitions/implement` —— super 为 Android 10+ 出厂特性
8. `https://android.googlesource.com/kernel/common/+refs` —— 分支与 tag 的权威清单
9. `https://git.codelinaro.org/api/v4/projects/clo%2Fla%2Fkernel%2Fmsm-4.9/repository/branches?per_page=100` —— msm-4.9 零 KERNEL.PLATFORM
10. `https://source.android.com/docs/core/architecture/kernel/gki-versioning` —— KMI 版本格式，且以 `android12-5.4` / `5.4-android12-0` 为示例

---

## 取证环境与局限

- `web_search` 工具在本会话无法使用（参数序列化失败，`queries` 始终为空）。改用 DuckDuckGo HTML 端点经本地代理检索。
- `web_fetch` 工具与 Windows schannel 均无法建立 HTTPS：直连报 `SEC_E_NO_CREDENTIALS (0x8009030e)`。
  最终路径：**本地代理 `127.0.0.1:7897` + Python(OpenSSL) urllib**。
- **本报告引用的每一个页面都是 TLS 证书校验通过（`verified_tls: true`）后取得的**。
  （两次首轮抓取曾降级为未校验：`partitions_overview` 与 `msm-5.15` branches；其中 msm-5.15 已以校验通过方式重取并以重取结果为准，`partitions_overview` 未被引用。）
- 404 未取得：`/docs/compatibility/vsr`、`/docs/compatibility/15/vsr`、`/docs/core/tests/vts/kernel`、`/docs/core/architecture/kernel/kernel-release-notes`。故 **VSR（Vendor Software Requirements）原文未取得 —— 「UNVERIFIED」**。
- CLO 搜索 API 需鉴权（401），无法做全站关键词检索。
