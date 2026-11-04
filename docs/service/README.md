# TerminalOS 设备侧服务：守护 / 录音 agent / .bashrc

本目录是设备（小米 MIX 2S · Termux + proot Ubuntu 26.04）上后台服务的**可回滚副本**，
用于灾难恢复和版本对账。设备上的真身路径：

| 本目录文件 | 设备路径 | 字节 | sha256 |
|---|---|---|---|
| `tos_supervisor.sh` | `$HOME/tos_supervisor.sh` | 2742 | `eae7747ecddaed5bf4e37db0a284fe54452368e3900cea5664020ba73704ed14` |
| `bashrc` | `$HOME/.bashrc` | 508 | `e04cb86de09498ccc3932ca8067116cf26c3ca5ffaeaa0d19fe2aa4ab187b715` |
| `tos_agent.sh` | `$HOME/tos_agent.sh` | 646 | `05e41df61ae76e3868cde4fca68650cb841f4d7c10c021a02bf7f5d53b5e9d20` |

`$HOME` = `/data/data/com.termux/files/home`。

**证据等级（必须按这个读）**
- `tos_supervisor.sh`、`bashrc`：**与设备端实测值一致**——首席 2026-11-04 23:01 报的
  `2742 B / eae7747e…`、`508 B / e04cb86d…` 与本文件逐位相同。
- `tos_agent.sh`：**未验证**。本机没有设备端那份原件，这里的 646 B / `05e41df6…`
  是共享盘上的候选副本（`C:\AiWork\tmp\agent2.sh`，内容为 6 秒 AAC 分段 + agent.lock 单实例）。
  设备端 `~/tos_agent.sh` 的 sha256 若与此不同，**以设备版为准**，并把差异回填到本表。
  核对命令：`sha256sum ~/tos_agent.sh`（应输出 `05e41df6…`）。

## 1. 组成与职责

```
.bashrc ──(Termux 启动)──> tos_supervisor.sh ──┬─ 1Panel      (:10086)
                                              ├─ 语音后台 web (:8081)
                                              ├─ worker.py  (识别 + 48h 保留)
                                              └─ tos_agent.sh (仅工作时段录音)
```

- **`tos_supervisor.sh`**：单实例守护。每 `INTERVAL=10` 秒巡检一次，端口/进程探活，
  挂了就重启；日志按 5 MB 单份轮转。
- **`tos_agent.sh`**：录音 agent。循环录 6 秒 AAC 到 `~/ubuntu-26.04/opt/terminalos/voice/in/`，
  单实例靠 `$PREFIX/tmp/agent.lock` 目录锁（由 supervisor 在拉起前 `rm -rf` 清残留）。
- **`bashrc`**：Termux 每次开交互式会话时拉一次 supervisor（`pgrep` 判重），
  然后自动进入 proot Ubuntu（`TOS_UBUNTU_STARTED` 防重入）。

## 2. 机制细节（读脚本得出，非估计）

| 机制 | 实现 | 说明 |
|---|---|---|
| 单实例 | `mkdir $PREFIX/tmp/tos_supervisor.lock` + 写 `pid` + `kill -0` 判活 + `trap` 清理 | 锁目录残留但 pid 已死时会自动清锁重启 |
| 巡检 | `while :; sleep 10` | 1Panel / web / worker 用端口或 `pgrep -f` 判活；agent 用 `pgrep -f tos_agent.sh` |
| 日志轮转 | `rot()`：`stat -c %s > 5242880` 时 `mv f f.1` | **只保留一份 `.1`**，更早的历史直接覆盖，不是多份轮转 |
| 工作时段 | `tos_supervisor.conf` 里的 `WORK_START` / `WORK_END`（默认 9 / 19） | 按设备本地时区的小时数判断，**小时粒度**；区间为 `[WORK_START, WORK_END)` |
| 配置覆盖 | `[ -f "$CONF" ] && . "$CONF"` | 改时段不用改脚本，写 `WORK_START=9`、`WORK_END=19` 到 `~/tos_supervisor.conf` |
| 环境隔离 | 所有常驻服务跑在 `proot -0 -r ~/ubuntu-26.04` 里，`env -i` 清环境 | Termux 侧只留 supervisor 与 agent |

## 3. 安装 / 更新

```bash
# 在 Termux 里（$HOME = /data/data/com.termux/files/home）
cp tos_supervisor.sh ~/tos_supervisor.sh && chmod +x ~/tos_supervisor.sh
cp tos_agent.sh      ~/tos_agent.sh      && chmod +x ~/tos_agent.sh
cp bashrc            ~/.bashrc           # 覆盖前先备份：cp ~/.bashrc ~/.bashrc.bak-$(date +%F)
# 重启守护（先停后起，避免新旧两个 supervisor 抢锁）
pkill -f tos_supervisor.sh; rm -rf $PREFIX/tmp/tos_supervisor.lock
nohup ~/tos_supervisor.sh >/dev/null 2>&1 &
```

## 4. 回滚

按影响面从小到大，每步都能单独撤：

```bash
# 4.1 只停录音（保留全部后台服务）
pkill -f tos_agent.sh; rm -rf $PREFIX/tmp/agent.lock
# 4.2 停整个 supervisor（会连带停掉它拉起的 1Panel/web/worker）
pkill -f tos_supervisor.sh; rm -rf $PREFIX/tmp/tos_supervisor.lock
# 4.3 恢复旧 .bashrc（自启关闭）
cp ~/.bashrc.bak-<日期> ~/.bashrc
# 4.4 彻底回退到手工启停
#     执行 4.2 + 4.3 后，Termux 重开不再自动拉起任何服务
```

## 5. 验收命令（每条都能独立判定）

```bash
# A. 单实例：只应有 1 个 supervisor、1 个 agent（时段内）
pgrep -fc tos_supervisor.sh; pgrep -fc tos_agent.sh
# B. 自愈：kill 掉 worker，10~20 秒内应看到 restart worker 且 pid 变化
pkill -f worker.py; sleep 15; grep 'restart worker' ~/ubuntu-26.04/opt/terminalos/logs/supervisor.log | tail -2
# C. 工作时段门控：把当前小时改到窗外，agent 应被停
echo 'WORK_START=3; WORK_END=4' > ~/tos_supervisor.conf   # 举例，按当前时间选窗外窗口
sleep 15; grep 'stop agent' ~/ubuntu-26.04/opt/terminalos/logs/supervisor.log | tail -2; pgrep -fc tos_agent.sh
# D. 轮转：造 >5MB 日志，下一轮巡检应出现 app.log.1
head -c 6000000 /dev/zero > ~/ubuntu-26.04/opt/terminalos/logs/agent.log; sleep 15
ls -l ~/ubuntu-26.04/opt/terminalos/logs/agent.log*
# E. 文件对账：三件与仓库一致
sha256sum ~/tos_supervisor.sh ~/.bashrc ~/tos_agent.sh
```

**已实测的项（首席 2026-11-04 23:01）**：B（kill worker → `supervisor.log 23:01:23 restart worker`，pid 15795）、
`.bashrc` 重开 Termux 后服务自恢复、端口 8081/10086 均 `200`、agent 按时段被停。
**本文件未实测的项**：A 的计数、C 的窗外门控、D 的轮转、E 的 agent 哈希——本机没有设备，不做伪证。

## 6. 已知限制

1. 轮转只留一份 `.1`，跨两轮的大量日志会丢；需要更长历史得改成按日期命名。
2. 时段是**小时粒度**，不支持「9:30–18:30」这种半小时间隔。
3. 依赖设备本地时区；时区错了时段就错，`WORK_START`/`WORK_END` 不会自动跟随。
4. agent 的静默丢弃阈值是**文件大小 < 3000 B**，worker 侧另有一套 `amp_max<300` / `rms<25`，
   两套阈值没有联动，改一个不会影响另一个。
5. 单实例靠 pid 判活，pid 被复用时可能误判（概率低，但存在）。
6. 本目录是副本，改成设备真身必须两边同步，否则下次回滚会回到旧版本。
