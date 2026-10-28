# GKI / AOSP 官方文档证据包 · 清单与引文核对

- 用途：为 `_reviews/K2_CANDIDATES_C_O5.md` §2.3 的 GKI 判定提供**可核验的原文副本**。
- 抓取时间：2026-10-28（Asia/Shanghai）
- 抓取方式：并行第二路子代理用本地代理 + Python OpenSSL 抓取 `source.android.com`（HTTP 200）。
  本机 `web_fetch` 对该域名报 `SEC_E_NO_CREDENTIALS`，`curl` exit 35，故由子代理代抓。
- **本清单由 方案甲 于 2026-10-28 逐条复核对齐**：下列每条引文我都在 `raw/*.txt` 上重新 `grep`/`read` 过，
  行号与原文逐字比对无误。sha256 见文末，可验证副本未被改动。

## 1. 落盘路径

| 内容 | 路径 |
| --- | --- |
| 引用的页面原始 HTML（7 个） | `_reviews/_evidence/gki_research/raw/*.html` |
| 全部页面正文抽取（41 个 txt） | `_reviews/_evidence/gki_research/raw/*.txt` |
| 子代理完整报告 | `_reviews/_evidence/gki_research/REPORT.md` |
| 抓取脚本 / URL 清单 / 抓取日志 | `fetch.py` / `targets.json` / `fetch_log.json` |

> **说明**：`fetch_log.json` 只记录了最后一批 5 个 URL（子代理分批抓取的遗留缺口）。
> 本清单用**页面标题**独立完成了「文件名 → URL」的对应，不依赖该日志。

## 2. 关键引文逐条核对（文件 : 行号 : 原句）

### 引文 1 —— GKI 的定义域是 5.10+
- 页面：`https://source.android.com/docs/core/architecture/kernel`（页面标题 "Kernel overview"）
- 文件：`raw/kernel_overview.txt`
- 行号：**469**
- 原句（逐字）：
  > `Any 5.10 and higher ACK kernel(aarch64 only). The GKI kernel has these`
- 同页补充（行 458-459）：
  > `Kernel with versions of 5.10 and higher are also referred to as`
  > `Generic Kernel Image (GKI) kernels.`

### 引文 2 —— vendor_dlkm / odm_dlkm 必须位于 super
- 页面：`https://source.android.com/docs/core/architecture/partitions/vendor-odm-dlkm-partition`（标题 "Vendor and ODM DLKM partitions"）
- 文件：`raw/vendor_odm_dlkm.txt`
- 行号：**440**
- 原句：
  > `vendor_dlkm and odm_dlkm partitions are located in the super partition as`

### 引文 3 —— vendor_boot 需要 boot image header v3
- 页面：`https://source.android.com/docs/core/architecture/partitions/vendor-boot-partitions`（标题 "Vendor boot partitions"）
- 文件：`raw/vendor_boot.txt`
- 行号：**425**
- 原句：
  > `11 devices can use boot image header version 3. In`
  （上下文："Android 11 devices can use boot image header version 3."，`11` 前一词因折行在上一行）

### 引文 4 —— super 是 Android 10 出厂引入（**首席要求重点核对的那句**）
- 页面：`https://source.android.com/docs/core/ota/dynamic_partitions/implement`（标题 "Implement dynamic partitions"）
- 文件：`raw/dynamic_partitions.txt`
- 行号：**410-411**（印刷为折行，完整一句跨两行）
- 原句（逐字，两行拼接）：
  > `For devices launching with Android 10, create`
  > `a partition called super. The super`
  → 完整句：**"For devices launching with Android 10, create a partition called super."**

#### 关于「must not」的澄清（回答 首席 的质疑）
同一文件里**另有一处**含 "must not"，与引文 4 **不是同一句、不是同一主题**：

| 行号 | 原句 | 主题 |
| --- | --- | --- |
| **410-411** | `For devices launching with Android 10, create a partition called super.` | **创建 super 分区**（引文 4，我方引用） |
| 588-589 | `Devices launching with Android 10 must not use system-as-root.` | 禁止 system-as-root（与 super 是否存无关） |
| 591-592 | `Devices with dynamic partitions (whether it launches with or retrofit dynamic partitions) must not use system-as-root.` | 同上 |

**结论：引文 4 逐字无误，无需降级为推导。** 首席担心的「语义改变」不成立——
两处是不同段落、不同主语，不存在把 "must not" 误读成 "create" 的情况。

#### 附带收获：第 591 行正面支持 v6 的自我修正
> `Devices with dynamic partitions (whether it launches with or **retrofit** dynamic partitions) ...`

原文明确承认 **retrofit dynamic partitions** 这种形态存在。这支持「polaris 出厂无 super，但构建后经 retrofit 有 super」的表述，
也解释了我 v5→v6 撤回的那条错误推论。

### 引文 5 —— 支持矩阵（最低一行 Android 12，无 4.x）
- 页面：`https://source.android.com/docs/core/architecture/kernel/android-common`（标题 "Android common kernels"）
- 文件：`raw/android_common.txt`
- 位置：章节 `#compatibility-matrix`
- 原句（矩阵行）：`Android 12 (2021)` 对应 `android12-5.10`

## 3. 两个「零命中」断言的复核方法（可自行复现）

```powershell
$raw = '_reviews\_evidence\gki_research\raw'
# 断言 A：「GKI 1.0 / GKI 2.0」非 AOSP 官方术语
Get-ChildItem $raw -Filter *.txt | ForEach-Object { Select-String -Path $_.FullName -Pattern 'GKI (1\.0|2\.0)' -AllMatches } | Measure-Object
# 预期 Count = 0

# 断言 B：CDD 中没有 GKI 支持矩阵
Get-ChildItem $raw -Filter *cdd* | ForEach-Object { (Select-String -Path $_.FullName -Pattern 'Generic Kernel Image|\bGKI\b' -AllMatches).Count }
# 预期全部为 0
```

方案甲 实测结果（2026-10-28）：断言 A 在 82 个原始副本中 **0 命中**；
断言 B 在 6 份 CDD 中 **0 命中**。

## 4. 未能核实（不得当作已确认）

1. **VSR（Vendor Software Requirements）原文未取得**：`/docs/compatibility/vsr`、`/docs/compatibility/15/vsr` 均 **404**。
2. **不存在**任何单句 AOSP 原文说「Android 8.1 / 4.9 不适用 GKI」。该结论必须按推导表述（引文 1+2+3+5 推论）。
3. **「高通从未为 SDM845 发布 GKI」是强推论而非穷尽证明**：CLO 全站搜索 API
   `/api/v4/search?scope=projects&search=sdm845` 返回 **401 Unauthorized**，无法做全站关键词检索；
   该结论基于仓库/分支结构（`KERNEL.PLATFORM.*` 分支数与 branch 名检索）。

## 5. 原始 HTML 的 sha256（验证副本未改动）

```
kernel_overview.html      301CC934F4784DF4F6CA177511B07DB264D4D286607171B4B6CD63B172473615
android_common.html       A6062EC1AB7C410BA8E16018E1C39B7C8BF95826B1145A52EBC3511F39530BA7
vendor_boot.html          7BDA7149E26FA44C6A1D8458D9B39AD4212923C100AF26F2A837D3A5F81D1330
vendor_odm_dlkm.html      7A0591CF691ED5819A6EB2BD56C2B303F69BFD8F72E4FEF30682304366D1B361
dynamic_partitions.html   DFFDB4E5315D870FBEDE4528003D85BC208CB08C2DF5B50373FB2E30FEC5B888
gki_partitions.html       A1F23802A96A67DCA5513CFFF1D7DE4493F95C5EADF722EE67C52872335F40D1
gki_versioning.html       772130B3E486255AF440721DD77A0B8C6237D17393EAB9BCB9B331E33E44FBD7
```

复验命令：
```powershell
Get-FileHash _reviews\_evidence\gki_research\raw\dynamic_partitions.html -Algorithm SHA256
```

## 6. 若需重新抓取

`fetch.py` + `targets.json` 保留在包内。注意本机直连 `source.android.com` 会失败（TLS 层），
需在具备可用 HTTPS 出口的环境执行，或走代理。
