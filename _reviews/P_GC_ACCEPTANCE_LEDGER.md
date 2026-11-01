# 验收账状态（评审官 · P_GC）

- 时点：2026-11-01 11:10（Asia/Shanghai）
- 性质：**只读评审结论**，不是交付物本身；不修改实现、不操作设备、不写云端仓库（写入一律交 GITHUB）。
- 基准：**fork `GStarX/Polaris-TerminalOS-fork` `main` = `7bcc97955058c1ffb82e3ff26a248a796e50dbf3`**；旧仓 `GStarX/Polaris-TerminalOS` `main` = `15eb676fc139d1b680bc9e2d6c3e50f2e5c30a5a`（只读参照）。

## 1. 基线状态更正（影响记账口径）

群公告的「冻结基线以 `93900546` 为准」**已失效**。只读 API 实测：旧仓 `93900546` 之后还有 **5 个提交**，全部在 2026-10-28 15:04–16:24Z：

| commit | 时间(UTC) | 主题 |
| --- | --- | --- |
| `7f61e633` | 15:04 | ci: 固件中转 workflow |
| `f50933f1` | 15:43 | ci: 免 runner 构建 TerminalHome/navbar-overlay/Termux APK |
| `3c3bc43b` | 15:44 | fix(ci): aapt2 link 参数修正 |
| `b1a50ad2` | 16:03 | docs: 真机零构建验收记账（T01–T04/T09–T11/T18 PASS 等） |
| `15eb676f` | 16:24 | docs: verify-pins 现状与合成树测试 |

→ 记账应改用双基准：**fork `main`（可写、权威）+ 旧仓 `15eb676`（只读参照）**。旧的 `93900546` 只可作为历史节点引用。
（此前我口头报过「6 个提交」，实为 **5 个**，以此表为准。）

## 2. 已在 blob 级核实

| 对象 | blob | 字节 | 结论 |
| --- | --- | --- | --- |
| `_reviews/P_GC_K2_FINAL_REVIEW.md` | `32a83140` | 11,927 | 与本地已提交字节一致；内容 sha256 `13d37715…` 在新仓仍可验 |
| `_reviews/P_GC_AE_REVIEW.md` | `d873ca14` | 9,418 | 一致 |
| `_reviews/TERMINALHOME_REVIEW.md` | `530114ca` | 21,932 | 一致 |
| `_evidence/.gitattributes` | `06bcd9be` | 281 | `* -text` 随迁，HTML 字节保真成立 |
| `raw/dynamic_partitions.html` | `f8c0a120` | 240,031 | 存储字节 sha256 = `dffdb4e5…` = MANIFEST 记录值 |
| `evidence/2026-10-28/`（6 文件） | — | 194,082 / 183,588 / 191,552 / 165 / 97 / 6,949 | **已在 fork**，与旧仓同尺寸 |
| `evidence/2026-10-29/`（3 文件） | — | 3,358 / 2,940 / 3,024 | **已在 fork** |
| `local_manifests/terminalos-22.2.xml` | `3e60e27c` | 3,568 | 与主机官交接 blob 一致（**含缺陷，见 §3**） |
| `local_manifests/pins-22.2.txt` | `cc6d3d55` | 1,658 | 7 项，与两个 fork 分支 sha 对得上 |

上次我提出的「唯一可写仓没有真机证据」**已关闭**：两批证据均已在 fork。

## 3. 未修缺陷与未验证项

| # | 项 | 状态 | 归属 |
| --- | --- | --- | --- |
| 1 | `terminalos-22.2.xml` 中 `android_vendor_terminalos` 的 remote 解析到**旧仓**，`terminalos.mk` 改动会「改了不生效」 | **未修**：fork 上该文件 blob 仍为 `3e60e27c` | 主机官出新 blob → GITHUB 提交 |
| 2 | `repo init/sync`、`verify-pins.sh` 从未在真源码树运行 | 未验证 | 主机官/构建机就绪后 |
| 3 | 整包构建 `build-rom` 0 次运行 | 未验证 | 需 ≥350GB Linux runner |
| 4 | CamX `cam_*` 结构体尺寸未比对 | 未验证（押 4.19 前必须先补） | 方案乙 |
| 5 | AOSP 原文仅「项目内副本已核」，非一手直连 | 边界不闭合（环境所限） | 不得写成已一手核实 |
| 6 | 设备层「删 76 项 / 禁 4 项 / RAM 1.83GB」无独立可复核清单文件 | 未验证 | 首席；证据目录仅有状态与 OTA 分析文本 |
| 7 | T09 音量键、T11 休眠唤醒、T18 DO 持久性无各自专属证据文件 | 证据粒度不足 | 首席确认项↔证据映射 |
| 8 | `_reviews/FRAMEWORK_TRIM_FEASIBILITY_C_O5.md`（`fa0c69ab`/6,274 B）未入仓 | 未入仓 | 方案甲→GITHUB 代写 |

## 4. 签字建议

**可确认（证据支持，且已在新仓可复核）**
- K2-01/02/03 为**源码与文档级**结论；K2-04 方向三条理由成立；4.19 仅独立 PoC。
- 证据包字节保真（`.gitattributes` + HTML sha256 双证）。
- 设备层「零构建点亮」**存在**记录与截图证据文件；但见 §3 #6/#7，**只记「有记录」，不记「证据充分」**。

**暂不签收**
- 任何整包构建 / 可复现构建结论（`build-rom` 0 次）。
- T05 / T07 / T08 / T13 的通过（旧仓记账自述为 FAIL/PARTIAL，缺 ROM 侧修复）。
- 「AOSP 原文已一手核实」。
- 设备层 76 项删除的逐条对账（无清单，只有总数）。

## 5. 交接

1. **GITHUB**：把本文件写入 fork `main` 的 `_reviews/P_GC_ACCEPTANCE_LEDGER.md`，报 commit + blob；顺带写入方案甲的 `FRAMEWORK_TRIM_FEASIBILITY_C_O5.md`（blob 应为 `fa0c69ab`）。
2. **主机官**：给出 `terminalos-22.2.xml` 修正后的新 blob（`name` 改 `android_vendor_terminalos-fork`，`path` 不变），GITHUB 收到即提交报 sha。
3. **首席**：确认 §3 #6/#7 的项↔证据映射；若能补 `dumpsys meminfo -c` 与包名清单，设备层可从「有记录」升为「可签收」。
4. **评审官（我）**：本文件交付后不再改；上述 1–3 落地后我出一次补充评审（只核新增 blob，不重写结论）。
