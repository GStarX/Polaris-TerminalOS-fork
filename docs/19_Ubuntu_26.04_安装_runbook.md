# 19 · Ubuntu 26.04 proot 安装 Runbook（第 3 版，2026-11-01）

> 状态：**安装完成，重启持久化验收通过**（首席 2026-10-31 本机实测；GITHUB 未复核设备侧，仅按上报记录）。
> 关联：镜像/校验/国内源见 [`docs/18`](./18_proot_Ubuntu_26.04_镜像与国内源.md)。
> 设备：polaris `7c06f250`（真机操作只由首席执行）。

## 0. 版本更正（两处错，先读）

- **第 1 版**要求「root/adb 写 Termux 数据目录后必须 `restorecon -R`」——**该指导错误，已撤回**。
- **第 2 版**把 10-29「Termux 数据被清空重建」的根因判成 SELinux 标签——**判错了一半，本版更正为属主/权限**：

`dpkg-deb -x <deb> /` 解开 Termux 的 proot 包时，tar 把 `/data/data/com.termux`、`files`、`usr` 三个目录的属主改成了 **`root:root`**；开机时 `PackageManager` 准备应用数据发现属主不对，报
`pm_critical_info: Failed to prepare /data/data/com.termux`，判定数据损坏后**清空重建**。

SELinux 标签问题（`restorecon -R` 会打掉应用分类 `s0:c184,c256,c512,c768`）仍然存在且仍须避免，但它不是这次清空的主因。

## 1. 硬规则 v2（覆盖第 2 版全部规则，优先级最高）

**R1（属主/权限）**：用 `dpkg` 解包装 Termux 包后，必须立刻恢复属主：
```
chown -R u0_a184:u0_a184 /data/data/com.termux
```
权限：`com.termux`=700、`files`=771、`usr`=700、`home`=700。

**R2（标签）**：仍禁止 `restorecon -R`；需要修正标签时只用精确 `chcon`：
```
chcon u:object_r:app_data_file:s0:c184,c256,c512,c768 <path>
```

**R3（装完自检四项）**：① `ls -ld` 查属主/权限；② `ls -ldZ` 查标签；③ 重启后数据还在；④ `logcat -b events | grep pm_critical_info` 无 prepare 失败。

**R4（门槛）**：重启验证是**必做门槛**，不做不算完成。

## 2. 辅助规则（沿用，仍成立）

- **R5**：安装/下载/校验/apt 尽量以 **Termux 用户身份**执行；adb root 只用于只读诊断或受控文件操作（Termux 的 apt 拒绝以 root 运行）。
- **R6**：先校时再走 HTTPS（本次设备时钟曾慢 6 天，会让证书校验失败、证据时间线错位）。
- **R7**：Ubuntu base 不含 `ca-certificates`；首次 apt 先用 HTTP 源装 `ca-certificates`，再切 TUNA HTTPS。
- **R8**：安装包与 rootfs 压缩包放共享存储（`/sdcard`），不要只放 Termux home，数据被清时可快速恢复。

## 3. 自检命令（只读）

```sh
# R1：属主与权限（期望 u0_a184:u0_a184；700/771/700/700）
ls -ld /data/data/com.termux /data/data/com.termux/files \
       /data/data/com.termux/files/usr /data/data/com.termux/files/home

# R2：标签（期望带 s0:c184,c256,c512,c768）
ls -ldZ /data/data/com.termux /data/data/com.termux/files \
        /data/data/com.termux/files/usr /data/data/com.termux/files/home

# R3-④：重启前/后确认没有 prepare 失败
logcat -b events -d | grep -i pm_critical_info
```

## 4. 安装流程（本次实际执行，命令细节待首席完整报告回填）

1. 手机侧 TUNA 下载 `ubuntu-base-26.04.1-base-arm64.tar.gz`，校验官方 sha256 `5a190679…219fd`。
2. 解压 rootfs 到 `~/ubuntu-26.04`（约 887 MB）。
3. 安装/使用 proot（本次 5.1.107）；若用 `dpkg` 解包，**立刻按 R1 恢复属主与权限**。
4. TUNA 源：先 HTTP 装 `ca-certificates`，再切 HTTPS。
5. 生成启动器 `~/ubuntu.sh`（Termux 用户可执行）。
6. 按 R3 四项自检；按 R4 重启验证。
7. 验收通过前不写「已安装」；通过后按本页记录记账。

## 5. 实测记录（首席上报，GITHUB 未复核）

| 项 | 值 |
| --- | --- |
| rootfs | `~/ubuntu-26.04`，887 MB，重启后仍在 |
| 系统 | Ubuntu 26.04.1 LTS aarch64 |
| 运行时 | Node **v22.22.1**、npm **9.2.0**、git **2.53.0** |
| apt | TUNA 源 HTTPS 正常，`apt-get update` OK |
| 启动器 | `~/ubuntu.sh`，Termux 用户可执行，重启后仍在 |
| proot | 5.1.107，`PROOT_SMOKE_RC=0` |
| 重启 | uptime 64s 确认真重启；数据未丢；`pm_critical_info` 无 prepare 失败 |
| 磁盘 | `/data` 已用 1.3 G / 224 G |

## 6. 回退

- 删除 rootfs 目录 `~/ubuntu-26.04`，卸载 proot 相关包即可；不动 Android 分区、不改 DO、不碰锁任务配置。
- Termux 数据被清空时：让 Termux 自动 bootstrap，再从 `/sdcard` 的备份恢复 rootfs；恢复后按 R1/R2 检查，**不要**用 `restorecon -R`。

## 7. 待办

- [ ] 首席回填带命令的完整报告（实际命令/耗时/磁盘占用），本文补全第 4 节细节。
- [ ] 主机官脚本 v2：按 R1–R4 固化（下载→sha256→解压→proot→apt→启动器→属主/权限自检→重启验证），落 `scripts/`，先不执行。
- [ ] 方案甲 DSH 需求清单（Node 版本/安装方式/启动命令/数据目录/是否需要图形界面）——当前唯一阻塞。
- [ ] 测试官验收清单补：重启前后属主/权限与标签一致、`pm_critical_info` 无 prepare 失败。

## 8. 验收命令（真机）

```sh
ls -l ~/ubuntu.sh && bash ~/ubuntu.sh -- /usr/bin/env true
bash ~/ubuntu.sh -- cat /etc/os-release    # 期望 VERSION_ID="26.04"
bash ~/ubuntu.sh -- node -v                 # 期望 v22.x
bash ~/ubuntu.sh -- git --version
bash ~/ubuntu.sh -- apt-get update
# 重启后复查：rootfs、启动器、APT、网络，以及 R1/R2 的属主与标签
```
## 9. 命令回填（2026-11-01）

### 9.1 已验证、可直接执行的命令

```sh
# 属主/权限（R1）：dpkg 解包类安装后必须立刻做
chown -R u0_a184:u0_a184 /data/data/com.termux
chmod 700 /data/data/com.termux
chmod 771 /data/data/com.termux/files
chmod 700 /data/data/com.termux/files/usr
chmod 700 /data/data/com.termux/files/home

# 属主/权限与标签抽查（R3）
ls -ld  /data/data/com.termux /data/data/com.termux/files \
        /data/data/com.termux/files/usr /data/data/com.termux/files/home
ls -ldZ /data/data/com.termux /data/data/com.termux/files \
        /data/data/com.termux/files/usr /data/data/com.termux/files/home

# 单路径标签修正（R2，禁止 -R）
chcon u:object_r:app_data_file:s0:c184,c256,c512,c768 <path>

# 重启前后检查（R3-④/R4）
logcat -b events -d | grep -i pm_critical_info

# 启动与组件复核（首席实测通过）
ls -l ~/ubuntu.sh
bash ~/ubuntu.sh -- cat /etc/os-release
bash ~/ubuntu.sh -- node -v
bash ~/ubuntu.sh -- git --version
bash ~/ubuntu.sh -- apt-get update
```

### 9.2 待首席回填的原始命令

以下步骤已在设备上执行并通过，但**原始命令行文本**尚未回填，本文不臆造：

| 步骤 | 状态 |
| --- | --- |
| TUNA 下载 `ubuntu-base-26.04.1-base-arm64.tar.gz` 的完整命令 | 待回填 |
| rootfs 解压到 `~/ubuntu-26.04` 的命令 | 待回填 |
| proot 安装方式（`pkg install proot` 还是 `dpkg-deb -x` 解 Termux 包） | 待回填（属主事故即出在此步） |
| TUNA apt 源的写入方式 | 待回填 |
| `~/ubuntu.sh` 启动器内容 | 待回填 |

## 10. 重启验收记录（2026-10-31，首席实测）

| 检查项 | 结果 |
| --- | --- |
| rootfs 重启后仍存在 | ✅ `~/ubuntu-26.04` 887 MB |
| 启动器重启后仍存在 | ✅ `~/ubuntu.sh` |
| uptime 确认真的重启 | ✅ 64 s |
| `pm_critical_info` prepare 失败 | ✅ 无 |
| apt / 网络 | ✅ TUNA HTTPS 正常 |
| 数据丢失 | ✅ 无 |