# 15 · 新 fork 仓与推送通道（唯一写入口）

> 生效时间：2026-10-28。本文是"仓库写入口"的口径来源，取代此前"只能走 GitHub API 提交"的做法。

## 1. 仓库角色

| 仓库 | 角色 | 规则 |
| --- | --- | --- |
| `GStarX/Polaris-TerminalOS-fork` | **唯一写入口**：文档、CI、验收、评审、本地 manifest | 只在这里提交 |
| `GStarX/Polaris-TerminalOS` | 旧项目仓（云端 `main` = `93900546`） | **冻结只读**，不再接受提交 |
| `GStarX/android_device_xiaomi_polaris` | 设备树（LineageOS fork） | 只读引用，构建时按 manifest 拉取 |
| `GStarX/android_vendor_terminalos` | vendor（Termux 预置） | 只读引用 |
| `GStarX/android_packages_apps_TerminalHome` | TerminalHome 应用 | 只读引用 |

`terminalos.xml` 仍指 23.2 实验路线，交付线走 `terminalos-22.2.xml` + `pins-22.2.txt`；任何构建必须声明走哪条路线。

## 2. 内容来源（导入基线）

新仓 `main` 首个提交 `3a97015`（109 文件）：

- **基线** = 云端 `Polaris-TerminalOS` `main` @ `93900546` 的 35 个文件（云构建实际跑的就是这棵树）。
- **叠加** = 本地工作区中从未上云的 75 个文件：`_reviews/`（68，含 `_evidence/`）、`acceptance/_evidence/*`、`acceptance/EXEC_MATRIX.md`、`acceptance/static_checks.py`、`local_manifests/pins-22.2.txt`、`scripts/verify-pins.sh`。
- 两边都有的文件**取云端版本**（本地 clone 与云端是零共同 commit 的两条历史，本地历史不作权威）。

因为历史分叉，旧仓里的 commit sha（`923d2ed`/`42a0aa2`/`de78335`/`560d54b`/`aa046fb` …）不适用于新仓。迁移后的记账方式是：**新仓 commit + 文件内容 sha256**，两者都给。

## 3. 推送通道（本机实测）

- `github.com:443`：本机不通（21 秒超时）。
- `ssh.github.com:443`：可用；新仓已挂只写 deploy key（title `dsh-bot-push`，私钥 `%USERPROFILE%\.ssh\id_ed25519_dsh`）。
- 因此**可以正常 `git push`**，不需要再逐个文件走 API。

```bash
export GIT_SSH_COMMAND="ssh -i $HOME/.ssh/id_ed25519_dsh -p 443"
git clone ssh://git@ssh.github.com:443/GStarX/Polaris-TerminalOS-fork.git
# 已有目录：
git remote add fork ssh://git@ssh.github.com:443/GStarX/Polaris-TerminalOS-fork.git
git push fork main
```

注意：deploy key 只对**新 fork 仓**有写权限；旧仓没有可用的写通道，这正好符合"旧仓冻结"。

## 4. 流程

1. 本地改（自己的目录）。
2. 用户确认。
3. `git add` 自己的文件 → `commit`（写明证据）→ `git push fork main`。
4. 云端 CI 自动跑 `validate`；需要结构校验时推 `ci/22.2-sync` 或手动 dispatch `sync-check`；整包用 `build-rom`（需 ≥350 GB 磁盘的 self-hosted runner）。

## 5. 已验证的云端运行

- `validate`：新仓首次 push 触发，`success`（2026-10-28T14:15:25Z）。
- `sync-check` / `build-rom`：workflow 已在仓库中且为 active；`build-rom` 从未真正跑过整包。