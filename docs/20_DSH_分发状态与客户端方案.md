# 20 · DSH 在手机上的形态与「手机当服务端」方案（第 2 版，2026-11-01）

> 第 2 版更正：第 1 版写的「官方没有 Linux 包，也没有 TUI 包」**只对桌面端成立**。官方 npm 有 CLI/web 包，Linux 服务端可行。
> 本文只记查证到的分发事实与架构口径；设备侧安装结果由首席实测报告，GITHUB 不代写「已验证」。
> **token / 登录凭据一律不入库、不贴群、不写文档。**

## 1. 分发事实（npm registry 实测）

| 项 | 值 |
| --- | --- |
| 包名 | `@deepseek-ai/dsh` |
| 最新 dist-tag | **`0.2.1-rc.5`**（`npm view` 实测；版本序列从 `0.0.1-rc.1` 到 `0.2.2-alpha.2` 共 40 个） |
| `bin` | `dsh → lib/bin.js` |
| 直接依赖数 | **86**（`dependencies`，无 `optionalDependencies`） |
| 描述 | `dsh CLI: profile launch, plugin management, and configuration inspection` |
| Web 入口 | `dsh --profile web --host <h> --port <p> --no-open`（首席在设备上实测 `--help` 支持） |

分发面结论：
- **桌面端**（Electron GUI）：只有 `win-x64`；`linux-*`/`mac-*` 的 feed 返回 SPA 兜底页，不是安装包。proot 无显示服务，桌面端本来也不适用。
- **CLI / web**：官方 npm 包，跨平台（受原生模块约束），是手机上跑服务端的正确形态。
- npm 上的 `deepseek-harness` 是占位包（TUI 项目预留），不是本方案用的包。
- 第三方 `Zhou-Yujing114514/deepseek-harness-linux` 是非官方 re-pack，不采用。

## 2. 原生模块在 linux-arm64 上的可用性（预判，待设备实测确认）

86 个直接依赖全是 `@deepseek-ai/*` 加 `js-yaml`/`commander`/`node-addon-require-builtin`；下面几个原生模块是**传递依赖**：

| 模块 | linux-arm64 情况 | 依据 |
| --- | --- | --- |
| `sharp` | ✅ 有 `@img/sharp-linux-arm64` 预编译包 | registry `optionalDependencies` |
| `koffi` | ✅ 有 `@koromix/koffi-linux-arm64` | registry `optionalDependencies` |
| `@vscode/ripgrep` | ✅ 有 `@vscode/ripgrep-linux-arm64` | registry `optionalDependencies` |
| `node-pty` | ⚠️ `install` 脚本为 `node scripts/prebuild.js || node-gyp rebuild`；有 arm64 预编译就走预编译，否则**需要 build-essential + python3** 现编 | registry `scripts.install` |
| `sherpa-onnx` | ❓ 未在 registry 元数据里看到平台包，待设备侧安装结果确认 | registry 无 `optionalDependencies` |

结论：**大概率能装，最坏情况需要 build-essential 现编 node-pty**；这属于主机官依赖问题清单的范围。

## 3. 架构口径（首席定，2026-11-01）

```
[手机 Android]
  └─ Termux ── ~/dsh-web.sh（编排：起 proot 内 dsh web → 等端口 → 解析带 token URL
              → am start 拉起查看器 → 监控 dsh 进程 → 退出时 am start 回 Termux）
       └─ proot Ubuntu 26.04 ── ~/dsh/start-web.sh（npm i -g @deepseek-ai/dsh@0.2.1-rc.5
              → dsh --profile web --host 127.0.0.1 --port 8899 --no-open）
  └─ DshViewer（自制 App）：全屏 WebView；初始画面显示「地址:端口」与连接状态；
         收到 url 后加载；dsh 退出广播 → 自动 finish；「返回」→ 刷新/重连回初始画面
```

分工：Ubuntu 内安装与启动 = 主机官；Termux 编排 = 主机官；查看器 App = 注入官；intent/广播/错误态协议 = 服务官；验收 = 测试官；机制评审（谁监控谁、Termux 被杀、锁任务下 `am start` 权限）= 方案甲/方案乙/复核官。

## 4. 桥接协议（占位：以服务官定义为准）

本文只固定必须存在的东西，具体字符串由服务官定：
- 拉起查看器的 intent action + extras（`url`、`token`；**token 只在内存与 intent 里传，不落盘**）；
- dsh 退出时发送的广播 action（查看器收到后 finish 回 Termux）；
- 错误态：端口未就绪、页面加载失败、token 失效，各自的可显示文案。

## 5. 验收（测试官执行，首席上机）

1. `dsh web` 起来（端口监听、日志出现带 token 的 URL）；
2. 查看器自动出现并加载页面；
3. `kill` 掉 dsh 进程；
4. 查看器自动回到 Termux；
5. 查看器内点「返回」→ 回到初始画面并显示地址:端口。

## 6. 安全与边界

- `dsh web` 绑 `127.0.0.1`，不绑 `0.0.0.0`；查看器与 dsh 在同一网络栈，可直接访问。
- token 不落盘、不入库、不贴群；查看器不写日志。
- 不改 DO、不碰锁任务配置；真机操作只由首席执行。

## 7. 未验证（不写成已完成）

- 设备侧 `npm i -g` 的实际结果、node-pty 是否需要现编、sherpa-onnx 是否可用；
- 锁任务（kiosk）模式下 Termux 侧 `am start` 的权限；
- 查看器 App 尚未实现，五步验收链路未跑过。