# 15 · 新 fork 仓与推送通道（唯一写入口）

> 生效时间：2026-10-28。本文是"仓库写入口"的口径来源，取代此前"只能走 GitHub API 提交"的做法。
> 修订：2026-10-28 第 2 版，修正文件计数、补"取云端版本"的副作用与待迁清单关闭状态、修正推送命令前提。

## 0. 推送纪律（2026-10-29 首席决定，全员生效，置顶）

1. **MCP 写操作只允许 `@GITHUB` 执行**（`create_or_update_file` / `push_files` 等）；其他成员一律只读，需要改文件就把"内容 + 目标路径"交给 GITHUB 代写，或走 PR。
2. **写前自检 + 报备（缺一不做）**：先 `git remote -v` 确认目标仓库与分支；在群里报 `repo + branch + path`（MCP 调用必须写全 `owner/repo`）；旧仓 `GStarX/Polaris-TerminalOS` 出现即停（连 revert 也不行）。
3. **写后报 sha 并读回校验**：报 commit sha；用 API / `git ls-remote` 读回目标仓与文件 blob，确认落点在 fork `main`（或经确认的交付分支）。
4. 写目标只允许 `GStarX/Polaris-TerminalOS-fork`；旧仓冻结基线 `93900546`，已发生的偏移按 §6/§7（E1/E2）记录、不重写历史；真机证据只进 fork。
5. 违反本条（尤其写到非 fork 仓库）按冻结例外 **E3** 记录，停写通道并上报首席/用户。

## 1. 仓库角色

| 仓库 | 角色 | 规则 |
| --- | --- | --- |
| `GStarX/Polaris-TerminalOS-fork` | **唯一写入口**：文档、CI、验收、评审、本地 manifest | 只在这里提交 |
| `GStarX/Polaris-TerminalOS` | 旧项目仓（冻结基线 = `93900546`；当前 `main` 已偏移到 `15eb676`，见 §6/§7） | **冻结只读**，不再接受提交 |
| `GStarX/android_device_xiaomi_polaris` | 设备树（LineageOS fork） | 只读引用，构建时按 manifest 拉取 |
| `GStarX/android_vendor_terminalos` | vendor（Termux 预置） | 只读引用 |
| `GStarX/android_packages_apps_TerminalHome` | TerminalHome 应用 | 只读引用 |

旧仓冻结的实测依据（2026-10-27 当时）：4 个仓的 `pushed_at` 都停在 2026-10-27，旧仓 `main` 仍是 `93900546`。之后旧仓又偏移到 `15eb676`（E2，见 §7），当前 `main` 以 §7 为准，冻结基线仍锁 `93900546`。
本机 deploy key 只挂在新 fork 仓上；**但共享 GitHub MCP token 对旧仓也有 admin**（E2 即由此而来），所以旧仓禁写靠 §0 纪律 + MCP 写权限收口，不能只靠 SSH key。

`terminalos.xml` 仍指 23.2 实验路线，交付线走 `terminalos-22.2.xml` + `pins-22.2.txt`；任何构建必须声明走哪条路线。

## 2. 内容来源（导入基线）

新仓 `main` 首个提交 `3a97015` = **109 个文件** = 云端 `Polaris-TerminalOS` `main` @ `93900546` 的 35 个文件 + 本地从未上云的 **74** 个：

- **基线** 35：云构建实际跑的就是这棵树。
- **叠加** 74：`_reviews/` **67**（含 `_evidence/` 56）+ `acceptance/` 5 + `local_manifests/pins-22.2.txt` + `scripts/verify-pins.sh`。
- 之后 `79123a4` 增加 `docs/15` 与 `_reviews/P_GC_AE_VERIFY.log`（该日志被 `.gitignore` 的 `*.log` 命中，是刻意 `git add -f` 入库的），共 **+2 = 111** 个文件；计数按 `79123a4` 之后为 111。
- `_reviews` 在 fork 上是 **68** 个（导入时 67 + 上述日志 1）。

**两边都有的文件取云端版本**，这是刻意选择（本地 clone 与云端是零共同 commit 的两条历史，本地历史不作权威）。副作用是首批导入时漏掉了本地较新的 4 个文件，已在 `c12e1f1` 补齐，**该差异项已关闭**：

| 文件 | 导入时（云端旧值） | 补齐后 = 本地 blob |
| --- | --- | --- |
| `docs/02_构建环境与依赖.md` | `d7bb967b` | `032b329c` |
| `docs/06_Phase0_设备核验清单.md` | `4807574c` | `7ad86182` |
| `local_manifests/terminalos.xml` | `59a7627b` | `dcd73450` |
| `local_manifests/terminalos-22.2.xml` | `60942b03` | `01564621` |

因为历史分叉，旧仓里的 commit sha（`923d2ed`/`42a0aa2`/`de78335`/`560d54b`/`aa046fb` …）不适用于新仓。记账口径：**新仓 commit + 文件入库 blob sha**，两者都给。

**判等只认入库 blob**：用 `git ls-files -s` / `git rev-parse HEAD:<path>` / `git cat-file blob`，不要用 `git hash-object -- <path>`——后者会按 `.gitattributes`（本仓 `_reviews/_evidence/.gitattributes` 为 `* -text`）和 `core.autocrlf` 做转换，量到的不是入库字节，跨仓比对会误报差异。

验收要同时记 **mode**：blob 相等不代表可执行位正确。本次导入曾把 10 个脚本丢成 `100644`（旧仓 9 个 `100755` + `verify-pins.sh`），纯 blob 对账完全看不出来，是 `7acb84e` 单独修回来的。记账双键之外再加一项：**blob + mode**。

## 3. 推送通道（本机实测）

- `github.com:443`：本机不通（21 秒超时）。
- `ssh.github.com:443`：可用；新仓已挂只写 deploy key（title `dsh-bot-push`，私钥 `%USERPROFILE%\.ssh\id_ed25519_dsh`）。
- 公钥指纹：`SHA256:IeX5gn7rB+9yrogMUHd147NugsdG7mf67IaP7GaI1uo`（ED25519，`dsh-bot@local`），可用 `ssh-keygen -lf id_ed25519_dsh.pub` 复核。
- 端到端证据：`3a97015`、`79123a4`、`c12e1f1` 三次提交都是经这条 SSH 通道落到云端的。

**前提（容易踩）**：fork 的首提交 `3a97015` 是**根提交、无父**，而本地旧 clone 的 `master` 根是另一条历史（`560d54b` 一族），两者零共同 commit。**在现有旧 clone 里直接 `git push fork main` 会被拒**，除非 `--force`——那等于把 fork 历史换成旧本地历史，不要做。

```bash
export GIT_SSH_COMMAND="ssh -i $HOME/.ssh/id_ed25519_dsh -p 443"

# 推荐：新 clone（fork 是唯一写入口）
git clone ssh://git@ssh.github.com:443/GStarX/Polaris-TerminalOS-fork.git

# 或者：在旧 clone 里只取内容、不推送历史
git fetch ssh://git@ssh.github.com:443/GStarX/Polaris-TerminalOS-fork.git main
git switch -c fork-work FETCH_HEAD     # 需要 git ≥2.23；旧版本用 git checkout -b fork-work FETCH_HEAD
# 把自己的文件复制进来 → commit → push
git push fork fork-work:main
```

## 4. 流程

1. 本地改（自己的目录）。
2. 用户确认。
3. `git add` 自己的文件 → `commit`（写明证据）→ 推 `main`。
4. 云端 CI 自动跑 `validate`；需要结构校验时推 `ci/22.2-sync` 或手动 dispatch `sync-check`；整包用 `build-rom`（需 ≥350 GB 磁盘的 self-hosted runner）。

## 5. 已验证的云端运行

- `validate`：`79123a4` push 后两次运行均 `success`（2026-10-28T14:15:25Z、14:16:28Z）。
- 端到端推送证据（不是通道探测）：`3a97015`、`79123a4`、`433c1e4`（本文档修订）均在本机用 `git push` 经上述 SSH 通道推上云端，推送回显分别为 `[new branch] main -> main`、`79123a4..c12e1f1`、`7acb84e..433c1e4`；本地 `C:\AiWork\tmp\fork-seed` 的 reflog 可查。
- 复验命令（任何人可跑）：`ssh -p 443 -i ~/.ssh/id_ed25519_dsh -T git@ssh.github.com`，应返回 `Hi GStarX/Polaris-TerminalOS-fork!`（deploy key 作用域只此一仓，旧仓会拒）。
- `sync-check` / `build-rom`：workflow 已在仓库中且为 active；**`build-rom` 从未真正跑过整包**，云端目前只有 validate / sync-check 的绿，没有整包产物。
## 6. 冻结后例外 E1（记录于 2026-10-29）

**事实**：旧仓 `GStarX/Polaris-TerminalOS` 在冻结后（基线 `93900546`）仍收到 4 个提交，`main` 由 `93900546` 前进到 `b1a50ad2`，时间 2026-10-28T15:04Z–16:03Z，共 17 个文件变更。

**处置（首席 2026-10-29 决定）**：保留，不重写历史（reset/force 会让公开引用失效、他人 clone 冲突、失去回退）。**冻结基线仍锁定 `93900546`**；`b1a50ad2` 只是偏移，今后任何核对一律对 `93900546`，不得拿 `b1a50ad2` 当基线。

**内容已全部回收**：fork `910ca75` 收录 17 个文件，blob 与旧仓 `b1a50ad2` 逐一相同（含 3 张 PNG，字节保真），旧仓没有 fork 里不存在的内容。

**失守路径（2026-10-29 复核修正）**：那 4 个提交的 author/committer 是 `86114489+GStarX@users.noreply.github.com`。**签名不能单独区分通道**：本机 clone 的 `git config user.name/email` 就是该身份，经 deploy key 的 SSH push 与 MCP/API 写仓产出的签名相同（主机官 2026-10-29 实测确认）。因此原记录"本机 git 凭据推的"**降为未定论**；E1 的事实部分（4 个提交、17 个文件、内容已回收）不变。对策（主机官执行）：本机旧 clone 的 `origin` 改指 fork、旧仓挂只读 remote `legacy`，并执行 §0 的写前/写后纪律。

**4 个提交**

| commit | 时间（UTC） | 主题 |
| --- | --- | --- |
| `7f61e63` | 2026-10-28T15:04:14Z | ci: add temporary fetch-firmware relay workflow |
| `f50933f` | 2026-10-28T15:43:10Z | ci: build standalone TerminalHome/navbar-overlay/Termux APKs on a free runner |
| `3c3bc43` | 2026-10-28T15:44:34Z | fix(ci): pass app resources positionally to aapt2 link |
| `b1a50ad` | 2026-10-28T16:03:34Z | docs: record the real-device zero-build validation |

**17 个文件（fork blob = 旧仓 blob）**

| 文件 | blob |
| --- | --- |
| `.github/scripts/build-rro-overlay-apk.sh` | `22c5dd1b` |
| `.github/scripts/build-terminalhome-apk.sh` | `229d1e37` |
| `.github/workflows/build-apk.yml` | `555311e3` |
| `.github/workflows/fetch-firmware.yml` | `90a01f86` |
| `README.md` | `5a88b820` |
| `acceptance/验收测试矩阵.md` | `c850b919` |
| `apk-overlays/navbar/AndroidManifest.xml` | `a447a56f` |
| `apk-overlays/navbar/res/values/config.xml` | `54a5f0cd` |
| `docs/03_任务清单_Phase0_基线_内核.md` | `ceba111c` |
| `docs/11_决策记录.md` | `bb7cdec1` |
| `docs/15_真机零构建验证记录.md` | `646644b6` |
| `evidence/2026-10-28/01_termux_running.png` | `e641f536` |
| `evidence/2026-10-28/02_notification_shade_no_qs.png` | `952caeea` |
| `evidence/2026-10-28/03_after_reboot_termux.png` | `7c09fe95` |
| `evidence/2026-10-28/device_owner.txt` | `202baaf0` |
| `evidence/2026-10-28/locktask_state.txt` | `06a4b9d7` |
| `evidence/2026-10-28/terminalhome_logcat.txt` | `8d989069` |

对应提交：fork `910ca75`（本记录为其文档化）。

## 7. 冻结后例外 E2（记录于 2026-10-29）

**事实**：E1 处置后，旧仓 `GStarX/Polaris-TerminalOS` 又收到 1 个提交 `15eb676`（2026-10-28T16:24:16Z，父提交 `b1a50ad2`，仅改 `docs/14_整包构建运行手册.md`，+62/-0，blob `243e3acd`，10086 字节）。旧仓 `main` 现为 `15eb676`；fork 当时仍是 `fd445b3`。

**来源判定（已核实）**：
- **辅助证据**：commit author/committer 均为 `GStarX <86114489+GStarX@users.noreply.github.com>`、`verification: unsigned`——但本机 clone 配置同身份，SSH push 与 API 写仓签名相同，**签名不能单独区分通道**；
- `C:\AiWork` 下全部 clone（旧 clone、fork clone、tmp 下各 clone）都**没有**该 commit 对象；旧 clone 的 `legacy` push URL 仍是 `DISABLED` → 不是从这些 clone 经 SSH / legacy remote 推的；
- 当前 token（用户 `GStarX`）对旧仓与 fork 都有 `admin`/`push` 权限（GitHub API `permissions` 实测），即 **API/MCP token 也能写旧仓**。
- **通道已确认（主机官 2026-10-29）**：走团队共用的 GitHub MCP 写文件接口（`create_or_update_file` / `push_files`，即 contents API），token 用户 `GStarX`；不是 SSH、不是本地 clone、不是临时 clone + https。该通道向旧仓共写 3 个提交：`591ef1d`、`8d44fb7`（两者都是冻结基线 `93900546` 的祖先，属基线内历史，不构成新例外）和 `15eb676`（E2 本项）。**范围核验**：`93900546...15eb676` ahead_by=5 = E1 的 4 个 + E2 的 1 个，无额外缺口。

**处置（首席 2026-10-29 决定）**：照 E1 口径，旧仓保留历史、不重写；内容回收 `fce6c31` 认可；冻结基线仍锁 `93900546`，`15eb676` 只是偏移，不得当基线。

**防再发（首席选 ①+②；③不单独使用）**：
1. **归档旧仓**（GitHub Archive，owner 操作、可逆）→ 所有人只读；
2. **bot 凭据换 fork-scoped fine-grained PAT**（当前 token 对旧仓有 admin，是真实可写通道）；
3. 推送纪律见 §0；口头限定不单独使用。
- 归档与 token 轮换涉及用户 GitHub 账号，**待用户点头**后执行。

**执行步骤（用户点头后由 GITHUB 执行，首席复核）**：
1. **归档旧仓**：`PATCH /repos/GStarX/Polaris-TerminalOS` body `{"archived": true}` → 校验 `archived=true`；归档后旧仓对 API/网页/SSH 全部只读，写请求应返回 403；归档可逆（`archived=false`）。
2. **新建 fork-scoped token**（用户操作）：fine-grained PAT，Repository access 只选 `Polaris-TerminalOS-fork`，权限 Contents=Read and write、Metadata=Read；先不删除旧 token，便于回滚。
3. **切换凭据**：新 PAT 存为 DSH secret，更新 github MCP server 的 env 引用；用新 token 验证：`GET /user/repos` 只应列出 fork（无旧仓），旧仓写入应 403。
4. **留痕**：docs/16 记执行时间、新 token 名称/范围、旧 token 作废时间；结果交首席复核。

**执行记录（2026-10-29）**：
- 用户已授权（2026-10-29 约 00:50 +08）。GITHUB 已执行归档：`PATCH /repos/GStarX/Polaris-TerminalOS {"archived":true}` → `archived=true`；写探针返回 `403 Repository was archived so is read-only`；旧仓 `main` 保持 `15eb676`，可逆（`archived=false`）。
- token 轮换：**待用户操作**。当前 `github` MCP server 不是「共享 capability」（`list_capabilities` 为空），token 在 DSH 的 MCP/secret 配置里；需用户新建 fine-grained PAT（只授权 `Polaris-TerminalOS-fork`，Contents=Read/Write + Metadata=Read）并在 DSH 设置里替换，替换后由 GITHUB 验证：`GET /user/repos` 只剩 fork、旧仓写 403。

### E2 关闭（2026-10-29）

- **关闭条件已满足**：主机官已按首席要求在群里发出「【E2 通道说明 · 主机官，按首席要求提交】」——通道=团队共用 GitHub MCP contents API（`create_or_update_file`/`push_files`，token 用户 `GStarX`）；时间线=`591ef1d` 2026-10-27T17:00:12Z、`8d44fb7` 17:00:26Z、`93900546` 17:01:37Z（前两者为基线祖先）、`15eb676` 2026-10-28T16:24:16Z（唯一 E2 偏移）。
- **GITHUB 只读核对**：旧仓 `main=15eb676`，父 `b1a50ad2`，唯一增量 `docs/14` +62/−0；`591ef1d...93900546` `ahead_by=2`；`93900546...15eb676` `ahead_by=5`；与群内说明一致；旧仓自 `15eb676` 后无新提交。
- **结论：E2 关闭**。冻结基线仍锁 `93900546`；`15eb676` 只记偏移。E1/E2 均不重写历史。

## 8. 共享 MCP token 写仓盘点（2026-10-29，首席交办）

**范围**：token 用户 `GStarX`；`GET /user/repos` 可访问 **8 个仓库**（均为 public，均 `push=true`）：
`Polaris-TerminalOS-fork`、`Polaris-TerminalOS`、`android_device_xiaomi_polaris`、`android_vendor_terminalos`、`android_packages_apps_TerminalHome`、`ios16_on_polaris_mix2s`、`MIX2S_LineageOS_17.1`、`Action-Build`。

**近 7 天（2026-10-22 起）有推送活动的仓库**（`repo events` + `commits?since` 只读实测）：

| 仓库 | 近 7 天活动 | 判定 |
| --- | --- | --- |
| `Polaris-TerminalOS-fork` | 本项目正常提交（E2 回收、D-25/D-27、evidence 等） | 正常写入口 |
| `Polaris-TerminalOS` | 10-27 基线期推送；`93900546` 后偏移 `b1a50ad2`（E1）、`15eb676`（E2） | 已按 E1/E2 处置，禁写 |
| `android_vendor_terminalos` | 10-27 初始化提交（author GStarX） | 项目正常初始化 |
| `android_packages_apps_TerminalHome` | 10-27 初始化提交（author GStarX） | 项目正常初始化 |
| `android_device_xiaomi_polaris` | 10-27 有分支推送记录；默认分支按 `commits?since=10-22` 未见新提交 | 项目正常初始化 |
| `ios16_on_polaris_mix2s` | 10-24/25 推送；commit 作者为 `luuu20309`（非 token 用户） | 用户旧 iOS 项目，非本 token 误写 |
| `MIX2S_LineageOS_17.1`、`Action-Build` | 无近 7 天活动 | — |

**结论**：除 fork 与旧仓外，**没有第三个项目仓库被误写**；其余活动均为项目初始化或用户旧项目。

**口径限制**：GitHub 对用户级账号不提供按 token 的审计日志；本盘点用「可访问仓库集合 + 仓库 push events + commit author」推断。API（MCP）提交与本地推送的 author 都可能显示 `GStarX`，无法逐条区分通道；要精确审计只能先做 ②（fork-scoped token）再观察。
## 9. 2026-10-29 validate 回归与修复

D-27 引入 `local_manifests/terminalos-22.2-sha.xml` 后，`validate` 的 manifest 白名单**只认分支名**（`terminalos/lineage-22.2` 等），40 位 commit SHA 被拒，导致 16:45–16:52Z 连续 3 次 `failure`（run `40729024820`/`40729154832`/`40730206305`，失败步骤均为「校验 local manifest（XML 结构 + revision 白名单）」）。

修复口径：白名单**按文件名分流**——`*-sha.xml` 的 `revision` 必须是 40 位小写 hex，且必须在 `pins-22.2.txt` 里出现（不一致即失败）；其余 manifest 仍只允许分支名。这样 D-27 的 SHA 锁定既不被旧规则否掉，也不会让任何 manifest 绕过校验。
## 10. 基线锚点与例外口径（2026-10-29 首席定案）

旧仓已 archived，但它的历史**不是**停在 `9390054`。任何「旧仓未动」「停在 9390054」的表述必须同时带 E1、E2 两条例外，否则就是假陈述。

| 锚点 | 值 | 说明 |
| --- | --- | --- |
| 导入点（fork 种子） | `93900546`（`9390054`） | 2026-10-27T17:01:37Z，fork 首个提交 `3a97015` 的基线 |
| E1 | 4 条：`7f61e63` / `f50933f` / `3c3bc43` / `b1a50ad2` | 15:04–16:03Z，含真机零构建证据与 APK CI |
| E2 | 1 条：`15eb676` | 16:24:16Z，`docs/14` +62/−0 |
| 封存 head | `15eb676` | 旧仓 `archived=true`，`pushed_at=16:24:17Z`，之后无新提交 |
| fork 回收点（E1） | `910ca75` | 17 个文件按原 blob 从旧仓只读 fetch 后搬运 |
| fork 回收点（E2） | `fce6c31` | `docs/14` 在该提交为 `243e3acd`（= 旧仓 `15eb676` 的值）；之后 fork 侧又修订到 `571ca663`，属正常演进 |

比对口径：
- 与「基线」比对 → 用 `93900546`；
- 核对 E1/E2 是否回收 → 用 `15eb676` 与上表回收点；
- 其余任何引用旧仓 head 的场合，必须写成「封存 head `15eb676`（含 E1/E2）」。