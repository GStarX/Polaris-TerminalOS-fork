# 20 · DSH 分发状态与「手机当客户端」方案（2026-11-01）

> 结论先行：**官方没有 Linux 包，也没有 TUI 包**；手机装 DSH 本体这条路当前不可行。用户已选「手机当客户端」：PC 跑 `dsh --profile web`，手机浏览器访问。
> 本文只记查证结果与已验证链路；token 等凭据**不入库**。

## 1. 官方分发状态（查证，非推测）

| 渠道 | 实测结果 |
| --- | --- |
| `download.deepseek.com/dsh-desk/feeds/` | 只提供 `win-x64`；`linux-x64`、`linux-arm64`、`mac-*` 均 404，返回的是 SPA 兜底页而非安装包 |
| npm `deepseek-harness` | 占位包，原文：「Reserved package name for the DeepSeek Harness TUI project (dsh-tui). The real package will be published here when development completes.」 |
| 第三方 `Zhou-Yujing114514/deepseek-harness-linux` | 有 arm64 包，但属**非官方 re-pack**，不采用 |
| 桌面形态 | DSH 桌面端是 Electron GUI；proot 内无显示服务，即便装上也无法启动界面 |

## 2. 选定方案：PC 作服务端，手机作客户端

- PC 侧启动（实测命令）：
  ```sh
  dsh --profile web --host 192.168.31.140 --port 8899 --no-open
  ```
- 手机侧验证（实测）：带 token `curl` 返回 **200**，**37,971 B**，标题为 `<title>DeepSeek Harness</title>`，链路可用。
- 访问方式：手机浏览器打开 `http://192.168.31.140:8899`，按页面提示登录。

## 3. 安全与边界

- **token 不入库**：不写进文档、不贴群、不落 git；本机互访只在局域网内。
- 不要把 `--host` 绑到 `0.0.0.0` 后暴露到公网；需要远程先走隧道并单独评估。
- 端口 `8899` 是本机临时选择，可改；改动后以实际为准。
- 手机与 PC 必须同一网段（本次 `192.168.31.0/24`）。

## 4. 未验证（不写成已完成）

- 只做了 `curl` 拉首页的链路验证；**手机浏览器实际交互、长连接、文件上传、插件加载**都未验证。
- 手机侧长时间使用时的耗电/发热、断线重连未测。
- 未在 Ubuntu（proot）里跑任何 DSH 相关组件——它现在只是备用运行时。

## 5. 后路：若官方发布 Linux/TUI 包

需要一份「在 Ubuntu 26.04 proot 内的安装与验证清单」（`@方案甲` 负责出，先放着）：Node 版本要求、安装方式（deb / npm / tarball）、启动命令、数据目录、是否需要额外系统依赖、无显示服务下能否运行。