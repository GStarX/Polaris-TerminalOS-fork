# 19 · Ubuntu 26.04 proot 安装 Runbook（草案，2026-10-29）

> 状态：**安装进行中，未完成、不记账**。首次安装成功过，但重启验收时 Termux 数据被自修复清空；首席正在重装并在重装后补 `restorecon` 再重启验证。最终结果出来前，本文只记录流程与事故教训。
> 关联：镜像/校验/国内源材料见 [`docs/18`](./18_proot_Ubuntu_26.04_镜像与国内源.md)。
> 设备：polaris `7c06f250`（设备操作只由首席执行；GITHUB 只做文档与只读核对）。

## 1. 环境与入口（首席实测上报）

- adb root 可用；Termux 已带 apt；Wi-Fi 可用（`223.5.5.5` 约 43 ms）。
- 手机侧网络：**只有 TUNA 通**，`cdimage.ubuntu.com` 在手机上打不开（与 PC 侧不同，PC 两个源都通）。
- **Termux 的 apt 拒绝以 root 运行**：装包/apt 必须切到 Termux 用户身份执行；adb root 只用于只读诊断或受控的文件操作。

## 2. 硬规则（本次事故直接教训，优先级最高）

**R1（最重要）**：**任何通过 root/adb 写入 `/data/data/com.termux/files` 的操作，写后必须立刻 `restorecon -R /data/data/com.termux/files`，再重启验证。**
本次事故：首席用 adb root 往 Termux 数据目录写文件，SELinux 标签不对；Termux 启动时判定环境损坏 → 自动重跑 bootstrap → **删掉整个 `files/` 目录（连 home 一起）**，rootfs 与 proot 全丢。

**R2**：安装、下载、校验、apt 尽量在 **Termux 用户身份**下执行；能不用 root 就不用。

**R3**：先校时再走 HTTPS。本次设备时钟**慢 6 天**，会直接导致证书校验失败、证据时间线对不上。

**R4**：Ubuntu base 镜像**不含 `ca-certificates`**。首次 `apt` 先用 HTTP 源装 `ca-certificates`，再切回 HTTPS（TUNA）源。

**R5**：重启验收是必做项；Termux 数据异常清空时，先查 SELinux 标签与写入通道，不要先归因于"重启清数据"。首席的对照实验：root 往 Termux home 放标记文件 → 重启后标记仍在 → **重启本身不清数据**，是标签触发了自修复。

## 3. 安装流程（本次实际执行顺序，命令细节待首席回填）

1. 手机侧从 TUNA 下载 Ubuntu Base 26.04.1 arm64，并校验官方 sha256：
   - `ubuntu-base-26.04.1-base-arm64.tar.gz`，35,092,106 B，sha256 `5a1906794ced63a71a8119c3f211ef5f0bbe0a243001b4bbd41fdf80c5b219fd`
2. 解压 rootfs 到 `~/ubuntu-26.04`（约 886 MB）。
3. 安装/使用 proot（本次实测 `proot 5.1.107`）。
4. 配 apt 国内源（TUNA），先 HTTP 装 `ca-certificates`，再切 HTTPS。
5. 生成启动器 `~/ubuntu.sh`（Termux 用户身份可执行）。
6. **`restorecon -R /data/data/com.termux/files`**。
7. 重启 → 复查 rootfs/启动器/APT/网络持久化。
8. 验收通过前不记账、不写"已安装"。

## 4. 实测记录（首席上报，GITHUB 未复核）

| 项 | 值 |
| --- | --- |
| 发行版 | Ubuntu Base **26.04.1 LTS**（Resolute Raccoon） |
| rootfs 体积 | 约 886 MB（`~/ubuntu-26.04`） |
| 下载源/速度 | TUNA，35,092,106 B，约 9.45 MB/s，sha256 与官方一致 |
| proot | 5.1.107，可用 |
| 组件 | Node **v22.22.1**、npm 9.2.0、git 2.53.0（apt 走 TUNA、HTTPS 正常） |
| 设备时钟 | 原慢 6 天，已校正 |
| 启动器 | `~/ubuntu.sh` 已生成 |
| 重启验收 | **失败**：Termux 数据被 SELinux 自修复清空；正在重装（重装后补 `restorecon`） |

## 5. 回退与恢复

- Termux 环境被清空时：Termux 会自动 bootstrap；随后需要重装 `proot`/克隆 rootfs。
- **把安装包与 rootfs 压缩包放在共享存储（`/sdcard`）**，不要只放 Termux home；这样 Termux 数据被清也能快速恢复。
- 恢复后先 `restorecon -R /data/data/com.termux/files`，再重启验证，避免二次清空。
- 设备本身仍是 kiosk（锁任务），本次安装不改变 DO/锁任务配置；真机操作只由首席执行。

## 6. 待办

- [ ] 首席完成重装 + `restorecon` + 重启持久化验证，报最终结果。
- [ ] 首席回填实际命令/耗时/磁盘占用，本 runbook 从"草案"转正。
- [ ] 主机官安装脚本骨架（下载→sha256→解压→换源→装包→可卸载）落 `scripts/`。
- [ ] 复核官定案 A/B 路线与 26.04 vs 26.04.1、回退条件。
- [ ] 测试官验收项与补证清单。
- [ ] 复核官/首席确认后再把 Ubuntu 线记入 `docs/13` 或 `docs/15` 的验收记录。

## 7. 验收命令（待真机执行后填结果）

```sh
# 1) 启动器与 proot
ls -l ~/ubuntu.sh && bash ~/ubuntu.sh -- /usr/bin/env true
# 2) 发行版
bash ~/ubuntu.sh -- cat /etc/os-release    # 期望 VERSION_ID="26.04"
# 3) 组件
bash ~/ubuntu.sh -- node -v                 # 期望 v22.x
bash ~/ubuntu.sh -- git --version
# 4) APT/HTTPS
bash ~/ubuntu.sh -- apt-get update
# 5) 重启后复查：rootfs、启动器、APT、网络仍正常
```
