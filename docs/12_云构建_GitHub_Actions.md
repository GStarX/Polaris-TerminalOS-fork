# 12 · 云构建（GitHub Actions）

> 目标：**不在本地构建**，把编译放到云端 runner；先跑 `lineage-22.2`（官方支持基线），再迭代修改。
> 当前状态：workflow 已提交；`sync-check` 可在 GitHub 托管 runner 上真实运行（只同步终端相关项目，不整包构建）；
> **整包 `build-rom` 尚未在真实的大磁盘 runner 上执行过**，第一次运行结果以 Actions 页面为准。

## 1. 为什么必须区分两类 runner

| 能力 | GitHub 托管标准 runner | 整包 ROM 构建所需 |
| --- | --- | --- |
| 磁盘 | ~14 GB 可用 | ≥ **350–400 GB**（源码 + out + ccache） |
| 内存 | 16 GB | 官方 lineage-21+ 建议 **64 GB**（32 GB 勉强） |
| CPU | 4 核 | ≥ 8 核，16 核以上更实际 |
| 结论 | 只能跑校验/小同步 | 必须 self-hosted 或 GitHub larger runner |

LineageOS 官方构建文档（`wiki.lineageos.org/devices/polaris/build/`）写的是 lineage-21 起建议 64 GB RAM、400 GB 存储。
所以本项目的策略是：

- `validate.yml`：任何 push/PR，托管 runner，秒级，静态校验；
- `sync-check.yml`：托管 runner，同步终端相关项目（数 GB）+ 结构契约校验 + Termux sha256 校验；
- `build-rom.yml`：**只在够大的 runner 上跑**，preflight 会先查磁盘，不足立即失败并说明原因。

## 2. runner 从哪来（三选一）

### 方案 A：云服务器注册 self-hosted runner（推荐，成本可控）

在任意云厂商开一台 x86-64 机器（建议 ≥8 核 / 32–64 GB RAM / ≥500 GB SSD，Ubuntu LTS），
在仓库 `Settings → Actions → Runners → New self-hosted runner` 得到注册命令，然后：

```bash
# 示意（token 由 GitHub 页面生成，不要提交到仓库）
mkdir -p ~/actions-runner && cd ~/actions-runner
curl -fsSL -o runner.tar.gz <页面给出的下载地址>
tar xzf runner.tar.gz
./config.sh --url https://github.com/GStarX/Polaris-TerminalOS --token <页面给出的 token> \
            --labels self-hosted,linux,x64,lineage-builder
sudo ./svc.sh install && sudo ./svc.sh start
```

运行 build workflow 时 runner 参数填：`["self-hosted","linux","x64","lineage-builder"]`。

### 方案 B：GitHub larger runner

需要组织/企业 + 付费。可用规格最高约 64 核 / 256 GB RAM / 2040 GB SSD。
在账号/组织 Settings 里创建 larger runner 后，`runner` 参数填其 label（如 `"ubuntu-24.04-64core"`）。
个人账号通常没有此能力。

### 方案 C：继续本机/群晖

不符合本项目"不在本地构建"的要求；群晖 DS218+ 双核 VM 只适合做镜像缓存/文档，不能承担主构建。
（如实在要用，见 `docs/02`，但不要期望能跑完 Android 整包。）

## 3. 三个 workflow

### 3.1 `validate.yml`（自动）

- 触发：任何 push / PR
- 内容：local manifest XML + revision 白名单、所有 shell 脚本 `bash -n`、禁止刷机命令、
  必备文档存在性、**跨仓库分支存在性**（`git ls-remote` 三个自有仓库的 22.2/23.2 分支）

### 3.2 `sync-check.yml`（手动或 push `ci/**`）

- 运行环境：`ubuntu-24.04`（托管即可）
- 内容：
  1. `repo init -b <lineage-22.2|lineage-23.2>` + 只同步终端相关项目（设备树、vendor/terminalos、
     TerminalHome、内核、两个 blobs 仓库，约数 GB）
  2. 下载 Termux APK 并校验 sha256（`vendor/terminalos/scripts/fetch-termux.sh`）
  3. `verify-wiring.sh` 校验产品配置/预置契约/overlay 分支差异/禁止刷机命令
- 触发方式：
  - Actions 页面手动 `Run workflow`（可选 22.2 / 23.2）
  - 或 push 一个 `ci/**` 分支（分支名含 `23.2` 则跑 23.2，否则跑 22.2）
- 产物：`sync-check-<branch>` artifact（报告 `out/ci/wiring-report.txt`）

### 3.3 `build-rom.yml`（手动，必须大 runner）

输入：

| 输入 | 说明 | 默认 |
| --- | --- | --- |
| `lineage_branch` | `lineage-22.2`（先跑）/ `lineage-23.2`（实验） | `lineage-22.2` |
| `build_target` | `terminalos`（带产品）/ `baseline`（未修改基线，仅 22.2） | `terminalos` |
| `runner` | `runs-on` 的 JSON：`"ubuntu-24.04"` 或 `["self-hosted","linux","x64"]` | `"ubuntu-24.04"` |
| `ccache` | 启用 ccache（self-hosted 二次构建显著加速） | `true` |
| `release_tag` | 留空则只上传 artifact；填写则创建/更新 GitHub Release | 空 |

流程：preflight（磁盘/内存）→ 装依赖 → repo init → local manifest → 全量 sync → 后置依赖检查 →
Termux 校验（terminalos）→ `lunch <product>-userdebug` → `brunch <product>`（失败回退 `mka bacon`，记录在 docs/11 D-07）
→ 产物 + `sha256sums.txt` + `build-info.txt` → artifact 上传（7 天）→ 可选 Release → 写回 `ci-status`。

## 4. 第一次跑 22.2 的建议顺序

1. 推一个 `ci/22.2-sync` 分支（或手动 dispatch `sync-check` 选 `lineage-22.2`）→ 看结构校验是否全绿；
2. 有够大的 runner 后，手动 dispatch `build-rom`（runner 参数填 `["self-hosted","linux","x64","lineage-builder"]`，
   完整步骤与失败分诊见 [`docs/14_整包构建运行手册.md`](14_整包构建运行手册.md)）：
   - 先 `build_target=baseline`（未修改基线，验证构建链与设备树/内核/blobs 组合能编过）；
   - 再 `build_target=terminalos`（带 TerminalOS 产品：Termux 预置 + TerminalHome + overlay）。
3. 每次构建都会在 `ci-status` 分支留下 `runs/<时间戳>-<kind>.json`（状态、分支、run 链接），
   便于没有 Actions UI 的场合核对；`ci-status` 分支只由 CI 写入。

## 5. 产物与版本

- ROM 包命名沿 LineageOS 规则：`lineage-22.2-<日期>-UNOFFICIAL-polaris.zip`（即使产品名是 terminalos_polaris，
  安装包文件名仍由 LineageOS 构建规则决定，实际以 build 输出为准）。
- 每个构建必须记录：branch、product、commit、产物 sha256、build.log；已自动写入 artifact 的 `build-info.txt`。
- 发布：`release_tag` 输入非空时，CI 用 `gh release create/upload` 发布；release 资产同时带 `sha256sums.txt`。

## 6. 成本与限制

- 托管 runner 上：`validate` / `sync-check` 基本免费（公共仓库）；`build-rom` 不可行（磁盘不足，preflight fail）。
- self-hosted：成本 = 云主机费用；ccache 50 GB 可显著降低二次构建时间（首次仍是最慢的）。
- **时间上限口径（已修正）**：GitHub **托管** runner 的单 job 有 **6 小时硬上限**；
  **self-hosted 不受 6 小时限制**，只受 workflow 的 `timeout-minutes`（本仓库 `build-rom` 设 900 分钟）
  与机器资源约束。首次整包在 8 核 / 32 GB 上耗时可能超过 6 小时，建议 ≥16 核、64 GB 内存；
  实际时间预算、失败分诊与产物验收见 [`docs/14_整包构建运行手册.md`](14_整包构建运行手册.md)。
- runner label 约定（与 docs/14 保持一致）：`["self-hosted","linux","x64","lineage-builder"]`。
- **未验证声明**：本 workflow 未在真实的大 runner 上跑完过一次整包；第一次失败是正常的，按日志迭代。

## 7. 安全

- `build-rom` / `sync-check` 的 `permissions: contents: write` 只用于：写 `ci-status` 分支、创建 Release。
- 不接收、不打印任何私钥/签名密钥；ROM 使用 AOSP test-key 签名（仅测试用途，不用于对外发布）。
- 仓库脚本禁止出现 `fastboot flash/erase/update`（`validate.yml` 会检查）；真机刷写只由首席执行。
