# K2 结果评审终稿（D3 · 已定稿并入仓）

- 评审官：评审官（历史代号 P_GC）
- 定稿时间：2026-10-28 01:20（Asia/Shanghai）
- 状态：**定稿 D3**。对齐主仓 HEAD `42a0aa2`；首席已签收 K2-04，本文件为验收账所记的评审结论。
- 范围：K2-01 / K2-02 / K2-03 交付与 K2-04 结案的证据链复核。**不评价** ROM 功能与构建可跑性，不触碰设备。
- 方法：只读。本地 Git、GitHub 只读 API、项目内证据副本逐行比对。**未执行 adb / fastboot / boot / 构建 / 刷写。**

## 0. 与被审对象的关系（先声明）

本文件是**评审结论**，不是交付物本身。评审对象为：`_reviews/K2_CANDIDATES_C_O5.md`（方案甲）、`_reviews/K2_03_ABI_G_6.md`（方案乙）、`_reviews/K2_04_VERDICT_GC.md` 与 `_reviews/K2_04_CLOSURE_GC.md`（复核官）、`_reviews/_evidence/gki_research/`（证据包）。争议以交付物为准，本文件只记录「我核到了什么、边界在哪」。

## 1. 快照（全部按字节数 + SHA256，不用行数）

| 对象 | 字节 | SHA256 | 入仓 |
| --- | --- | --- | --- |
| `K2_CANDIDATES_C_O5.md`（v7） | 80726 | `4beede73063366bbe30640fe74ec69d41401dbb0b6995c95447a1b80c2a84846` | 已提交 |
| `K2_03_ABI_G_6.md` | 23605 | `23f4a7991c3f85c07992bd51a3f1530e910af4349e6a44d5af049983f97b5829` | **未入仓** |
| `K2_04_VERDICT_GC.md` | 30903 | `c16223a41fe167a3102b04be3503bca91bd93e0a8474f3ea66616930874b459b` | 已提交 |
| `K2_04_CLOSURE_GC.md` | 12263 | `5479f10052cf9fea895621caf6890eeb438f56fdd7bc7ca0239080f7e10accc4` | 已提交（`42a0aa2`） |
| `_evidence/gki_research/MANIFEST.md` | 7090 | `65a3a3b3735a20b4af375ae1ee2198b0bd64647a6a116774fb9ec0fc75ff1c82` | 已提交 |
| `_evidence/gki_research/INDEX.md` | 9387 | `7ed49468b04f9b70943ca9eb391c69b95290b9b5a66a9f6f05475765d83bff3e` | 已提交 |
| 证据树 | 56 文件 / 4,980,301 B | 逐文件 sha256 见 MANIFEST | 56/56 受版本控制 |

**行数不作为证据（自身更正）**：D2 曾记 v7「520 行」，实测该文件为 **844 个 LF（845 行）**；`Get-Content` 在本环境给出 520 是读数伪影。同类伪影也解释了群里出现过的 105/111/122/127、54/55/56 等分歧——**测量时点 + 统计工具**两个变量叠加所致，均非编造。**自本稿起，文档证据一律用「字节 + sha256 + commit」，行数只用于定位引文且须注明工具。**

## 2. 结论

1. **K2-04 已由首席签收**：交付线 Linux 4.9.337（`aa8adfe9`）、无同路线 fallback、4.19 不否定不背书、5.4/GKI 与 5.10 不可行；K2-01/02/03 按分层口径**可验收**。
2. **本评审认可该签收**：三条结案理由均有证据支撑，红线（不得以「5.10 5/5 失效」证明 4.9）执行到位。
3. **K2 的结论强度上限是「源码与文档级」**：不含编译、不含启动、不含实机。任何下游引用不得越过这条线。

## 3. 我独立复验通过的事实

| # | 命题 | 方式 | 结果 |
| --- | --- | --- | --- |
| V1 | 内核仓无 23.x | `list_branches(LineageOS/android_kernel_xiaomi_sdm845)` 全 18 分支 | 最高 `lineage-22.2 = aa8adfe9` |
| V2 | TheMuppets polaris 无 23.2 | `list_branches` | 最高 `lineage-22.2 = 9e970795` |
| V3 | device 两 `terminalos/*` 内容完全相同 | `git rev-parse <sha>^{tree}` | **tree 均为 `6dd41ccaaa0992bca9c21c9cd9886b0ef5d024c9`**；两者父提交同为 `1b46255` |
| V4 | 三 fork 远端分支 | `list_branches` | device：23.2=`d124800`、22.2=`a7f8017`；vendor：23.2=`9a5d532`、22.2=`d4559c3`；home：三支同 `ccedcc4` |
| V5 | 四条 AOSP 引文在项目内副本逐行命中 | 按行号取原文 | `kernel_overview.txt:469`、`vendor_odm_dlkm.txt:440`、`vendor_boot.txt:425`、`dynamic_partitions.txt:410-411` 全部一致 |
| V6 | `super` 误引风险排除 | 读 `dynamic_partitions.txt:588-592` | 588-589 为 system-as-root 的 "must not"；591-592 有 "retrofits"，支撑 polaris 有 super |
| V7 | 证据包字节保真 | 7 个 HTML 实算 SHA256 ↔ MANIFEST §5 | 抽样 5/5 逐位一致（另 2 个由主机官/复核官独立验过） |
| V8 | `-text` 局部覆盖生效 | 读 `_reviews/_evidence/.gitattributes` | `* -text` 存在；`check-attr text → unset` 与主机官结论一致 |
| V9 | INDEX 分类与覆盖 | 读 `INDEX.md` | A 被引用 21 txt + 7 html、B 仅存档 20 txt，21+20=41 与 `raw/` 一致；`[日志]` 仅 5 条，其余自述为推断 |
| V10 | `android12-5.4` 存在有原文自证 | `gki_versioning.txt:485` | 命中，引用纪律第 3 条成立 |
| V11 | R3「单点维护」 | `get_commit(meuira, 5cd18f08)` | HEAD 作者日期 **2026-05-22T10:47:23Z** |
| V12 | R3「自带 UAF panic」 | `get_commit(meuira, 516e794d)` | 正文含 `kernel panic on perseus with UAF error` |
| V13 | R3「零 CI」措辞边界 | `get_file_contents(meuira, .github/workflows)` | 仅命中嵌套 `fs/exfat/.github/workflows/`；应写「**仓库根**零 CI」 |
| V14 | 首席要求的两处更正已落地 | 读 `K2_04_CLOSURE_GC.md` | dtbo 硬性前置已撤回（降为 P2 检查）；P1/P2 已改为「**不占设备、卡在构建机**」，原文「现在就能做」已明确标注为不准确 |
| V15 | 证据包入仓完整 | `git ls-files _reviews/_evidence` | 56/56 受控；四个相关 commit：`923d2ed`、`247405e`、`f01e501`、`833df31` |

## 4. 三条结案理由的核对

| 理由 | 结论 | 依据 |
| --- | --- | --- |
| R1 无构建、无实机启动证据 | 成立（文档级） | `docs/03:18` P0-08 `todo`；`docs/05` §7 构建记录 0；`docs/02` §11 全未勾。`adb devices` 为空系首席现场陈述，记为采信 |
| R2 23.2 配套缺失 | 成立，措辞已按本评审纠正 | 内核（V1）与 blobs（V2）无 23.2 分支；设备树 23.2 分支**存在**但 tree 与 22.2 完全相同（V3）→ 缺「内核 + blobs + Android 16 适配」三件，不是「没有设备树文件」 |
| R3 单点维护、零 CI | 大部分已核 | V11/V12/V13 已核；「0 fork / 4 star / 单分支」未逐项核，不单独支撑结论但方向成立 |

## 5. 逐项判定

| 项 | 判定 | 边界 |
| --- | --- | --- |
| K2-01 候选来源 | 可验收（源码级） | 4.9.337 有 commit 证据；4.19 有社区树；5.4/GKI/主线不可行有多重理由。未验证编译与启动 |
| K2-02 驱动覆盖 | 可验收（清单级） | 12 类硬件逐项结论；三重换料（触屏/面板/指纹）为结构性风险，已进 Phase 0 采集建议 |
| K2-03 ABI | 可验收（源码级，分层） | 4.19：0 项确证失效 + 2 项条件失效；5.10：5/5 失效。分层口径（1 结构体级 + 3 节点/宏级 + 1 未闭合 + 2 条件失效）为准。残留 CamX |
| K2-04 裁决 | 已签收 | 三条理由；「5/10 5/5」只用于排除 5.10；4.19 只做 PoC |
| 引用纪律 6 条 | 遵守 | 不引 CDD 作 GKI 依据、不把「GKI 1.0/2.0」当官方措辞、不声称单句原文、CLO 401 属强推论、VSR 404 不引 |

## 6. 未闭口与责任

| # | 项 | 状态 | 归属 / 解除条件 |
| --- | --- | --- | --- |
| 1 | CamX `cam_*` 结构体尺寸未逐字段比对 | 未闭 | 方案乙/复核官已挂 K3-01P；若押 4.19 则升级为「必须先补」 |
| 2 | AOSP 原文仅「副本已核」，非「一手直连」 | **不闭合，属环境事实** | 本机 `SEC_E_NO_CREDENTIALS`；终稿不得写成「已一手核实」 |
| 3 | `K2_03_ABI_G_6.md` 仍未入仓 | 未闭 | **方案乙**：`git add` + commit，报 hash |
| 4 | manifest 仍 pin `terminalos/lineage-23.2`，三个工作仓在 `terminalos/lineage-22.2`；vendor/home 本地无 origin | 未闭，**构建前必改** | **主机官**：改 revision 为 22.2 + 补远端 + 构建前 sha 校验 |
| 5 | 1×/3 条件失效转 PoC 待验清单 | 已交 | 复核官 §5 已列 P5–P7 |

## 7. 签字建议

**可确认**
- K2-01 / K2-02 / K2-03 按分层口径可验收（源码与文档级）。
- K2-04 方向与三条理由成立；4.19 仅独立 PoC，且 P1/P2 **不占设备、卡在 P0-08 构建机**。
- 验收标准 ①②：引文可按「路径 + 行号 + 原句」核；证据包在项目内、56 文件受控、sha256 可校验。

**暂不签收**
- 「AOSP 原文已一手核实」（现为副本已核；21 条被引用页的 URL 属推断档）。
- 「4.19 可编译 / 可启动」「构建可复现」「CamX 兼容」。
- 以 `d124800` 为交付基线的任何构建结论（工作区在 22.2 分支）。

**给 K4-01 的口径**：按 `docs/03:59` 记「平台移植目标，内核维持 4.9.337，**未做升级**」；4.19 PoC 点亮后另出升级结论。

- 评审官：D3 定稿，随本文件提交入仓。
- 首席：K2-04 已签收；本条为验收账所引的评审结论。

## 附录 A · 定稿后即时关闭的两项（2026-10-28 01:25 复核）

| 原未闭口 | 关闭证据 | 判定 |
| --- | --- | --- |
| #3 `K2_03_ABI_G_6.md` 未入仓 | `git ls-files _reviews` 命中；23605 B / `23f4a7991c3f85c07992bd51a3f1530e910af4349e6a44d5af049983f97b5829` | **已关闭** |
| #4 manifest 路线与结案口径矛盾 | `aa046fb` 新增 `local_manifests/terminalos-22.2.xml`（自有三仓 pin `terminalos/lineage-22.2`）与 `local_manifests/pins-22.2.txt`（6 条 commit），并加只读校验 `scripts/verify-pins.sh`；23.2 版 `terminalos.xml` 保留给实验路线 | **已关闭（构建输入层）** |

`pins-22.2.txt` 的 6 个 sha 与我在 V1/V3/V4 独立核到的值**逐一吻合**：
`a7f8017` / `d4559c3` / `ccedcc4` / `aa8adfe9` / `9e970795` / `b971b2cc`。
即：交付线构建输入现在有「manifest 分支 + commit pin + 只读校验脚本」三层，可作为 K3 的可复现性前置。

**仍余一项（不阻塞验收账）**：`vendor/`、`packages/` 两个本地仓当时仍未配置 `origin`。commit pin 已能保证「构建输入的 sha 可校验」，但「本地内容 = 远端内容」在本地仍无法自证，只能靠 GitHub API 对齐 HEAD。归 **主机官**，建议在 K3-01P 开工前一并补上。
→ **该条已于 2026-10-28 01:33 关闭，见附录 C。**

## 附录 B · 定稿边界（不再变动）

1. 本评审只覆盖**源码与文档级**证据；4.9 交付线**不含任何构建、启动、实机结论**。
2. AOSP 原文为「项目内副本已核」，**不是**一手直连抓取；21 条被引用页的 URL 属推断档。
3. CamX `cam_*` 结构体尺寸未闭合，押 4.19 前必须先补。
4. 后续若 `K2_04_CLOSURE_GC.md`、`K2_03_ABI_G_6.md` 再有修订，以其新哈希为准并另行复核；本附录不对未来版本背书。

## 附录 C · 附录 A 遗留项的关闭（2026-10-28 01:33 复核）

| 项 | 关闭证据 | 判定 |
| --- | --- | --- |
| vendor / home 本地无 `origin` | `git remote -v` 实读：`android_vendor_terminalos => origin https://github.com/GStarX/android_vendor_terminalos.git (fetch)`；`android_packages_apps_TerminalHome => origin https://github.com/GStarX/android_packages_apps_TerminalHome.git (fetch)` | **已关闭**：两个仓库均已配置远端，「本地 = 远端」具备核对前提 |
| K2-03 入仓（附录 A 已记） | `de78335 docs(reviews): 方案乙交付入仓 — K0 内核现状审计 + K2-03 模块ABI/vendor uapi 评估` | 与附录 A 一致，确认落点 |

**另一处不算缺口、但需写明**：`local_manifests/terminalos.xml` 仍 pin 三个自有仓库 `terminalos/lineage-23.2`，这是**有意保留**——该文件属 23.2 实验路线；交付线（22.2）改用 `terminalos-22.2.xml` + `pins-22.2.txt`（附录 A）。二者并存不构成矛盾，但**任何构建必须明确声明走哪条路线**，不得默认取 `terminalos.xml`。

**版本取代关系**：本版 D3.1 取代此前 `05b6613`（D3）。D3 与 D3.1 的差异仅为附录 A 一句状态更正 + 本附录 C，**第 1–7 节结论、哈希表（除本文件外）与签字建议均未变**。验收账应引用本版，不引用 `05b6613`。
