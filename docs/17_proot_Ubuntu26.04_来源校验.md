# 17 · proot Ubuntu 26.04 来源校验（评估输入证据）

> 只读校验，未安装、未动设备。记录时间 2026-10-29（UTC 10-28 17:0x）。
> 用途：D-28（安装 proot Ubuntu 26.04）评估阶段的镜像来源与校验基线。任何安装前必须复核本文的 sha256。

## 1. 官方清单（直接取自 Ubuntu 发布站）

- `https://cdimage.ubuntu.com/ubuntu-base/releases/26.04/release/SHA256SUMS`
- `https://cloud-images.ubuntu.com/releases/26.04/release/SHA256SUMS`

| 文件 | 官方 sha256 | 首席引用值 | 一致 |
| --- | --- | --- | --- |
| `ubuntu-base-26.04-base-arm64.tar.gz` | `b2b46a37324ea1954e93f293fe6d7c2241daf2fc298c4022e6e4caceeed74cab` | `b2b46a37…74cab` | ✅ |
| `ubuntu-base-26.04.1-base-arm64.tar.gz` | `5a1906794ced63a71a8119c3f211ef5f0bbe0a243001b4bbd41fdf80c5b219fd` | `5a190679…219fd` | ✅ |
| `ubuntu-26.04-server-cloudimg-arm64-root.tar.xz` | `482791c2480b396ca8f879b4bba0f49a1414086f1a5d318ccdf4e33d7d364134` | `482791c2…64134` | ✅ |

## 2. 本地实测（下载本体并对哈希）

- 文件：`ubuntu-base-26.04-base-arm64.tar.gz`，**35,094,845 B**
- 下载源：`https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/26.04/release/ubuntu-base-26.04-base-arm64.tar.gz`（清华镜像，与官方 cdimage 同路径同文件）
- 本地 `sha256` = `b2b46a37324ea1954e93f293fe6d7c2241daf2fc298c4022e6e4caceeed74cab`，**与官方清单逐位一致**
- 说明：镜像站的字节仍需以官方清单校验，不能只信镜像站自报；本次已按此执行。

## 3. proot-distro 版本

- `termux/proot-distro` 最新 release：`v5.10.3`，发布 `2026-10-25T15:31:13Z`，`prerelease=false`（GitHub API 实测）。
- v5 起安装走 OCI/Docker 镜像；走 OCI 路线时锁的是 digest，不是本文的 tarball sha256，两种路线的校验对象不同，评估时必须分开写。

## 4. 尚未做（不写成已完成）

- 26.04.1 与 cloudimg root 只核了官方清单值，**未下载本体**。
- 任何安装、解压、apt 操作均未执行；设备未触碰。

## 5. 复验命令

```bash
# 官方清单
curl -fsSL https://cdimage.ubuntu.com/ubuntu-base/releases/26.04/release/SHA256SUMS | grep arm64
# 本地校验
sha256sum ubuntu-base-26.04-base-arm64.tar.gz
# proot-distro 版本
curl -fsSL https://api.github.com/repos/termux/proot-distro/releases/latest | grep -m1 tag_name
```