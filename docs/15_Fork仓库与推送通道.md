# 15 · 新 fork 仓与推送通道（唯一写入口）

> 生效时间：2026-10-28。本文是"仓库写入口"的口径来源，取代此前"只能走 GitHub API 提交"的做法。
> 修订：2026-10-28 第 2 版，修正文件计数、补"取云端版本"的副作用与待迁清单关闭状态、修正推送命令前提。

## 1. 仓库角色

| 仓库 | 角色 | 规则 |
| --- | --- | --- |
| `GStarX/Polaris-TerminalOS-fork` | **唯一写入口**：文档、CI、验收、评审、本地 manifest | 只在这里提交 |
| `GStarX/Polaris-TerminalOS` | 旧项目仓（云端 `main` = `93900546`） | **冻结只读**，不再接受提交 |
| `GStarX/android_device_xiaomi_polaris` | 设备树（LineageOS fork） | 只读引用，构建时按 manifest 拉取 |
| `GStarX/android_vendor_terminalos` | vendor（Termux 预置） | 只读引用 |
| `GStarX/android_packages_apps_TerminalHome` | TerminalHome 应用 | 只读引用 |

旧仓冻结的实测依据：4 个仓的 `pushed_at` 都停在 2026-10-27，旧仓 `main` 仍是 `93900546`。
本机唯一的写通道（deploy key）只挂在新 fork 仓上，旧仓没有可写通道。

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
- `sync-check` / `build-rom`：workflow 已在仓库中且为 active；**`build-rom` 从未真正跑过整包**，云端目前只有 validate / sync-check 的绿，没有整包产物。