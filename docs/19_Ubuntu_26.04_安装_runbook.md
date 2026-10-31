# 19 · Ubuntu 26.04 proot 安装 Runbook（第 2 版，2026-10-31）

> 状态：**未完成、不记账**。设备自 2026-10-29 起离线（adb/fastboot/LAN 均不可达），重装与重启验收都没做成。
> 关联：镜像/校验/国内源见 [`docs/18`](./18_proot_Ubuntu_26.04_镜像与国内源.md)。
> 设备：polaris `7c06f250`（真机操作只由首席执行；GITHUB 只做文档与只读核对）。

## 0. 本版更正（重要，先读）

第 1 版 R1 要求「任何 root/adb 写 Termux 数据目录后必须 `restorecon -R`」，并在安装流程第 6 步与恢复流程里各写了一遍。**该指导已于 2026-10-31 撤回，是错的**：`restorecon -R` 会把标签重置成不带应用分类的 `app_data_file:s0`，与系统期望的 `s0:c184,c256,c512,c768` 不一致，PackageManager 判定 `/data/data/com.termux` 数据损坏并**删除重建**——这正是 10-29 那次「Termux 数据整个被清空」事故的直接触发点。

事故证据（首席上报，设备侧日志）：
`pm_critical_info: Failed to create app data for com.termux ... Failed to prepare /data/data/com.termux`

## 1. 硬规则（R1–R4，优先级最高）

**R1：Termux 数据目录禁止 `restorecon -R`。** 任何情况下都不要对 `/data/data/com.termux` 及其子目录执行递归 restorecon。

**R2：root/adb 写入 Termux 数据目录后，只能用精确标签的 `chcon`。** 标签固定为
`u:object_r:app_data_file:s0:c184,c256,c512,c768`；同时 `chown 10184:10184`；目录 `755`、文件 `644`。
逐条对目标路径执行，不要递归套用到不该改的路径上。

**R3：装完必须抽查四个路径的标签**，四个都必须带分类 `s0:c184,c256,c512,c768`：
```
/data/data/com.termux
/data/data/com.termux/files
/data/data/com.termux/files/usr
/data/data/com.termux/files/home
```

**R4：重启验证前，先确认 `pm_critical_info` 里没有 prepare 失败。** 有失败就先排查标签/写入通道，不要急着重启——重启会把「数据损坏 → 删除重建」走完。

## 2. 辅助规则（沿用第 1 版，仍然成立）

- **R5**：安装、下载、校验、apt 尽量以 **Termux 用户身份** 执行；adb root 只用于只读诊断或受控文件操作。Termux 的 apt 拒绝以 root 运行。
- **R6**：先校时再走 HTTPS。本次设备时钟曾慢 6 天，会直接导致证书校验失败、证据时间线错位。
- **R7**：Ubuntu base 镜像不含 `ca-certificates`；首次 apt 先用 HTTP 源装 `ca-certificates`，再切 TUNA HTTPS。
- **R8**：把安装包与 rootfs 压缩包放在共享存储（`/sdcard`），不要只放 Termux home；数据被清时可快速恢复。

## 3. 自检命令（只读，可先跑）

```sh
# R3：四个路径的标签（输出里必须有 s0:c184,c256,c512,c768）
ls -ldZ /data/data/com.termux /data/data/com.termux/files \
        /data/data/com.termux/files/usr /data/data/com.termux/files/home

# R2：需要修正单个路径时（示例，路径按实际替换，不要加 -R）
chcon u:object_r:app_data_file:s0:c184,c256,c512,c768 /data/data/com.termux/files/home
chown 10184:10184 /data/data/com.termux/files/home
chmod 755 /data/data/com.termux/files/home

# R4：重启前检查有没有 prepare 失败
adb logcat -b all -d | grep -iE 'pm_critical_info|Failed to prepare /data/data/com.termux'
```

## 4. 安装流程（本次实际执行，命令细节待首席回填）

1. 手机侧从 TUNA 下载 `ubuntu-base-26.04.1-base-arm64.tar.gz`（35,092,106 B），校验 sha256
   `5a1906794ced63a71a8119c3f211ef5f0bbe0a243001b4bbd41fdf80c5b219fd`。
2. 解压 rootfs 到 `~/ubuntu-26.04`（约 886 MB）。
3. 安装/使用 proot（本次实测 `proot 5.1.107`）。
4. 配 TUNA 源：先 HTTP 装 `ca-certificates`，再切 HTTPS。
5. 生成启动器 `~/ubuntu.sh`（Termux 用户身份可执行）。
6. **不再执行 `restorecon`**；如需修正某路径标签，按 R2 用精确 `chcon`，按 R3 抽查四个路径。
7. 重启 → 复查 rootfs/启动器/APT/网络持久化，并确认 R4 的日志检查无 prepare 失败。
8. 验收通过前不记账、不写「已安装」。

## 5. 实测记录（首席上报，GITHUB 未复核）

| 项 | 值 |
| --- | --- |
| 发行版 | Ubuntu Base **26.04.1 LTS**（Resolute Raccoon） |
| rootfs 体积 | 约 886 MB（`~/ubuntu-26.04`） |
| 下载源/速度 | TUNA，35,092,106 B，约 9.45 MB/s，sha256 与官方一致 |
| proot | 5.1.107，可用 |
| 组件 | Node **v22.22.1**、npm 9.2.0、git 2.53.0，apt 走 TUNA HTTPS 正常 |
| 设备时钟 | 原慢 6 天，已校正 |
| 启动器 | `~/ubuntu.sh` 已生成 |
| 重启验收 | **未完成**：10-29 数据被清空，之后设备离线 |

## 6. 回退与恢复

- Termux 数据被清空时：Termux 会自动 bootstrap；随后重装 `proot`、从 `/sdcard` 的备份恢复 rootfs。
- 恢复后按 R2/R3 检查标签，**不要**用 `restorecon -R`「修一下」。
- 安装不改 DO/锁任务配置；真机操作只由首席执行。

## 7. 待办

- [ ] 设备回来：重装 + R3 四路径标签抽查 + R4 日志检查 + 重启验收。
- [ ] 首席回填实际命令/耗时/磁盘占用，本文从「草案」转正。
- [ ] 主机官安装脚本 v2（下载→sha256→解压→proot→apt→启动器→精确 chcon/chown 自检→重启后验证），落 `scripts/`，先不执行。
- [ ] 测试官验收清单补两条：重启前后标签一致、`pm_critical_info` 无 prepare 失败。
- [ ] 方案甲 DSH 需求清单。

## 8. 验收命令（待真机执行后填结果）

```sh
ls -l ~/ubuntu.sh && bash ~/ubuntu.sh -- /usr/bin/env true
bash ~/ubuntu.sh -- cat /etc/os-release    # 期望 VERSION_ID="26.04"
bash ~/ubuntu.sh -- node -v                 # 期望 v22.x
bash ~/ubuntu.sh -- git --version
bash ~/ubuntu.sh -- apt-get update
# 重启后复查：rootfs、启动器、APT、网络，以及 R3 的四路径标签
```