
## 7. 2026-10-29 独立复验（GITHUB）

| 项 | 复验结果 |
| --- | --- |
| `ubuntu-base-26.04-base-arm64.tar.gz` | 官方 `SHA256SUMS` 现值 = `b2b46a37…74cab`；从 TUNA 下载本体 **35,094,845 B**，本地 sha256 **逐位一致** |
| `ubuntu-base-26.04.1-base-arm64.tar.gz` | 官方清单值 `5a190679…219fd` |
| `ubuntu-26.04-server-cloudimg-arm64-root.tar.xz` | 官方清单值 `482791c2…64134`（未下载本体） |
| `proot-distro` | GitHub API：`v5.10.3`，`2026-10-25T15:31:13Z`，`prerelease=false` |
| Docker Hub `ubuntu:26.04` index digest | Hub API 与 Registry v2 `Docker-Content-Digest` 头**两处一致**：`sha256:0e73b714…db0dd` |

编号冲突处理：本次另有同主题 `docs/17_proot_Ubuntu26.04_来源校验.md`（重复内容），已删除，只保留本文。**仍未做**：未在 Termux 实机拉取/安装/启动，未动设备。