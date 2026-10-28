# 18 · proot Ubuntu 26.04 镜像、校验与国内源（2026-10-29）

> 用途：D-28「Termux + proot Ubuntu 26.04、不装 1Panel」评估的输入材料。
> 相关：`docs/17`（方案甲）已记录 tarball 的 3 个官方 sha256 与 TUNA 下载实测；本文补充 **OCI digest、国内源可达性、两条安装路径**，不重复其结论。
> 只记录**实测事实与官方来源**；不含"已安装/已启动"的结论（实机安装由首席执行）。
> 采集时间：2026-10-29 00:50–00:58 +08；采集机：Windows 主机（与手机同一局域网，**无代理**；手机侧未实测网络）。

## 1. 结论

- Ubuntu **26.04 LTS（Resolute Raccoon）** 已发布：Cloud Images 构建 `20261016`（2026-10-20 更新）；arm64 有官方 base 与 cloud rootfs。
- Termux 软件源当前 `proot-distro` = **5.10.3**（与 GitHub 最新 release `v5.10.3`，2026-10-25 一致）；v5 起改为从 **Docker Hub / OCI registry 拉镜像**，所以支持 `proot-distro install ubuntu:26.04`，并支持 `@sha256:` 锁定（v5.10.3 README「Pinned by digest」一节）。
- Docker Hub 官方 `ubuntu:26.04` 存在：index digest `sha256:0e73b714…db0dd`；arm64 manifest digest `sha256:86eb1bc1…7f85`。
- 国内直连：官方 `cdimage.ubuntu.com` / `cloud-images.ubuntu.com` 本机能直连（HEAD 200，约 4 s 建立）；TUNA / USTC / 阿里云的 `ubuntu-cdimage` 镜像有同名 26.04 文件且很快（100–330 ms），TUNA 实测下载并校验通过。Docker Hub registry 本机可直连；daocloud / 1ms.run 镜像可作 OCI 备选（digest 已核对与 Docker Hub 一致）。
- 推荐主路径：`proot-distro install ubuntu:26.04@sha256:0e73b714…`（index digest 锁定）。
- 备选路径：从国内镜像下载 `ubuntu-base-26.04-base-arm64.tar.gz` → 校验官方 sha256 → `proot-distro install <文件> --name ubuntu`。
- 未验证：Termux 实机拉取/安装/启动、手机网络下的实际速度、daocloud/1ms 的 layer 完整拉取。

## 2. 官方 SHA256（4 项）

| 对象 | 官方 URL | sha256 | 来源/核对 |
| --- | --- | --- | --- |
| Ubuntu Base 26.04 arm64 | `https://cdimage.ubuntu.com/ubuntu-base/releases/26.04/release/ubuntu-base-26.04-base-arm64.tar.gz` | `b2b46a37324ea1954e93f293fe6d7c2241daf2fc298c4022e6e4caceeed74cab` | [cdimage SHA256SUMS](https://cdimage.ubuntu.com/ubuntu-base/releases/26.04/release/SHA256SUMS)（1244 B） |
| Ubuntu Base 26.04.1 arm64 | `https://cdimage.ubuntu.com/ubuntu-base/releases/26.04/release/ubuntu-base-26.04.1-base-arm64.tar.gz` | `5a1906794ced63a71a8119c3f211ef5f0bbe0a243001b4bbd41fdf80c5b219fd` | 同上 SHA256SUMS（1244 B） |
| Cloud root tar 26.04 arm64 | `https://cloud-images.ubuntu.com/releases/resolute/release/ubuntu-26.04-server-cloudimg-arm64-root.tar.xz` | `482791c2480b396ca8f879b4bba0f49a1414086f1a5d318ccdf4e33d7d364134` | [cloud-images SHA256SUMS](https://cloud-images.ubuntu.com/releases/resolute/release/SHA256SUMS)（8788 B） |
| Docker Hub `ubuntu:26.04`（多架构 index） | `https://hub.docker.com/_/ubuntu`（tag 26.04） | `sha256:0e73b71479e7bc5f006bca872e25c3cd680dc052a0116f90d63ae363537db0dd` | Docker Hub API + Registry v2 `Docker-Content-Digest`（2026-10-28T01:04:14Z 更新） |

> SHA256 由 GITHUB 于 2026-10-29 拉取上述官方 SHA256SUMS 逐项比对；**首席同日二次复核一致**（base 1244 B、cloud 8788 B）。
> 复核命令（任何人可跑）：`curl -fsSLO <SHA256SUMS URL>` 后 `sha256sum -c SHA256SUMS --ignore-missing`。

## 3. Docker Hub `ubuntu:26.04` 的 OCI digest（arm64）

| 层 | digest | 大小 |
| --- | --- | --- |
| tag `26.04`（多架构 index） | `sha256:0e73b71479e7bc5f006bca872e25c3cd680dc052a0116f90d63ae363537db0dd` | — |
| linux/arm64 manifest | `sha256:86eb1bc1059720a19a777ba5a109e9ee3690d5dfe3e319871a6d6beb86fb7f85` | 41,122,696 B |
| config | `sha256:490aa88f39f72f944cc111695f97fa6f78f4f3cc047a333f9448e6f03d4089b1` | 4,467 B |
| layer 1 | `sha256:afa7f7d582de8ee3433df193ede10fc2c50d3398de31c14d329b643e7a69b852` | 41,122,308 B |
| layer 2 | `sha256:6f01cc7d6fb3d703f324d1ccddfddeaa2e8c97cf4b5d6936a66396eaf4089d99` | 388 B |

**可锁定性（proot-distro v5.10.3）**：README「Pinned by digest」写明，带 `@sha256:` 的引用按该 digest 拉取，逐层校验"该 digest 命名的文档、多架构 index 下的架构 manifest、config 与每个 layer"，缓存复用也重新校验；只支持 sha256。因此：

```sh
# 主推荐：锁定多架构 index（按当前 CPU 选 arm64 manifest）
proot-distro install ubuntu:26.04@sha256:0e73b71479e7bc5f006bca872e25c3cd680dc052a0116f90d63ae363537db0dd

# 备选：直接锁定 arm64 manifest（单架构）
proot-distro install ubuntu:26.04@sha256:86eb1bc1059720a19a777ba5a109e9ee3690d5dfe3e319871a6d6beb86fb7f85
```

> tag 会随官方重建移动；要冻结内容就用 digest。以上 digest 是 2026-10-29 快照。

## 4. 国内源实测（本机，2026-10-29 00:50–00:58 +08，无代理）

| 源 | 测试 | 结果 | 判定 |
| --- | --- | --- | --- |
| `cdimage.ubuntu.com`（官方） | HEAD 26.04 arm64 文件 | HTTP 200，4119 ms | **可直连**；速度未测（仅建连耗时） |
| `cloud-images.ubuntu.com`（官方） | HEAD root.tar.xz | HTTP 200，4181 ms | **可直连**；速度未测 |
| `registry-1.docker.io` | HEAD `/v2/` | HTTP 401，1880 ms（正常 auth challenge） | **可直连**；随后 token+manifest 成功 |
| `auth.docker.io` | HEAD token 端点 | HTTP 405，2911 ms（HEAD 不允许，正常） | **可直连**；GET token 正常 |
| `hub.docker.com` API | tag 查询 | HTTP 200，2701 ms | 可直连 |
| TUNA `ubuntu-cdimage` | 下载 base 26.04 arm64 | HTTP 200，219 ms；35,094,845 B / 18.4 s（**1.82 MB/s**），sha256 与官方**一致** | **国内可直连、已端到端校验** |
| USTC `ubuntu-cdimage` | HEAD 同文件 | HTTP 200，124 ms | 可直连（未下载校验） |
| 阿里云 `ubuntu-cdimage` | HEAD 同文件 | HTTP 200，270 ms | 可直连（未下载校验） |
| TUNA 26.04.1 | HEAD 同文件 | HTTP 200，`Content-Length` 35,092,106 | 可直连 |
| `docker.m.daocloud.io`（Docker 镜像） | 401 → token → manifest | manifest 200，digest = `0e73b714…`，与 Docker Hub 一致 | 可作 OCI 备选（未拉 layer） |
| `docker.1ms.run`（Docker 镜像） | 401 → token → manifest | manifest 200，digest = `0e73b714…`，与 Docker Hub 一致 | 可作 OCI 备选（未拉 layer） |

镜像地址（与官方同路径）：

- TUNA：`https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/26.04/release/ubuntu-base-26.04-base-arm64.tar.gz`
- USTC：`https://mirrors.ustc.edu.cn/ubuntu-cdimage/ubuntu-base/releases/26.04/release/ubuntu-base-26.04-base-arm64.tar.gz`
- 阿里云：`https://mirrors.aliyun.com/ubuntu-cdimage/ubuntu-base/releases/26.04/release/ubuntu-base-26.04-base-arm64.tar.gz`

> 以上只是**本机/本网**样本，不代表所有地区/运营商；手机 Wi-Fi 下需重测。

## 5. 两条安装路径（供方案甲对比）

**A. OCI 路径（主推）**

```sh
pkg update && pkg install -y proot-distro      # 5.10.3
proot-distro install ubuntu:26.04@sha256:0e73b71479e7bc5f006bca872e25c3cd680dc052a0116f90d63ae363537db0dd
proot-distro login ubuntu
```

- 国内 registry 备选（镜像名前缀即 registry；proot-distro 会跟随 `/v2/` 的 Bearer challenge）：
  `proot-distro install docker.m.daocloud.io/library/ubuntu:26.04@sha256:<index digest>`
  `proot-distro install docker.1ms.run/library/ubuntu:26.04@sha256:<index digest>`
- 若只照抄 tag（不锁 digest），得到的内容可能随官方重建变化。

**B. tarball 路径（备用/离线）**

```sh
# 下载（任一国内镜像），并校验官方 sha256：
curl -LO https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/26.04/release/ubuntu-base-26.04-base-arm64.tar.gz
sha256sum ubuntu-base-26.04-base-arm64.tar.gz
# 期望：b2b46a37324ea1954e93f293fe6d7c2241daf2fc298c4022e6e4caceeed74cab

proot-distro install ./ubuntu-base-26.04-base-arm64.tar.gz --name ubuntu
# 或 URL 直装（文件会先完整下载再按本地文件处理）：
proot-distro install https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/26.04/release/ubuntu-base-26.04-base-arm64.tar.gz --name ubuntu
```

- 说明（README v5.10.3）：plain rootfs tarball 按顶层目录识别根，支持 gzip/xz/zstd 等；**不写 manifest.json，所以 `reset`/`run` 子命令不可用**，`login` 可用。要保留这些能力就用 OCI 路径。
- 备选 rootfs：cloud root tar（237 MB，sha256 `482791c2…364134`），同样按 plain rootfs tarball 导入。

## 6. 实机验收建议（供测试官）

1. `proot-distro list` 显示 `ubuntu`；`proot-distro list --image` 记录镜像 ID/来源。
2. `proot-distro login ubuntu` 后：`cat /etc/os-release` 应为 `VERSION_ID="26.04"`；`uname -m` 为 `aarch64`。
3. OCI 路径下核对 `PD_IMAGE_ID` = config digest `sha256:490aa88f…`（README v5.10.3 环境变量语义）。
4. `apt update` 能走通（proot 内 DNS 继承 Termux/Android 设置）；失败先查 `/etc/resolv.conf`。
5. 记录：安装路径（OCI/tarball）、实际拉取 digest、耗时、磁盘占用（`du -sh` 容器目录）、异常。

## 7. 边界与未验证

- 未在 Termux 实机执行安装/启动；未测手机 Wi-Fi 下的下载速度与稳定性。
- 下载速度样本只有 TUNA 一次（1.82 MB/s），不能代表其它镜像/时段。
- daocloud / 1ms.run 只验证到 manifest digest 一致，未验证 layer 拉取与 proot-distro 客户端兼容性。
- Docker Hub tag/digest 会随官方重建变化；本文 digest 为 2026-10-29 快照，重建后需重取并更新本文件。
