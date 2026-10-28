# 验收证据目录

本目录存放**测试官执行的可复现静态预检证据**。真机证据由首席按 `EXEC_MATRIX.md` §5.1 的目录规范放在 `acceptance/evidence/`（本目录是 `_evidence/`，只放测试官夹具输出，避免混放）。

## 为什么是 `.txt` 不是 `.log`

仓库根 `.gitignore` 有 `*.log`，预览/构建日志不入库。验收证据需要入库（没有证据不算完成），因此本目录统一用 `.txt` 后缀。

## 现有证据

| 文件 | 内容 | 结果 |
| --- | --- | --- |
| `2026-10-28_static_checks_baseline.txt` | `static_checks.py --verbose` 全量静态预检 | 11 项检查 / 126 条断言 / 0 失败 |
| `2026-10-28_static_checks_mutation.txt` | `--mutation-test`：注入 11 个真实缺陷，要求对应检查由 PASS 变 FAIL | 11 个变异 / 11 检出 / 0 漏检 |

两条日志头部都记录了被测仓库的 HEAD（home `ccedcc4`、vendor `d4559c3`、device `a7f8017`，均为 `terminalos/lineage-22.2` 工作树），用于日后复现时对齐源码。

## 重新生成

```bash
cd C:\AiWork\Polaris-TerminalOS
python acceptance/static_checks.py --root C:\AiWork\Polaris-TerminalOS-repos --verbose ^
  --log acceptance/_evidence/2026-10-28_static_checks_baseline.txt
python acceptance/static_checks.py --root C:\AiWork\Polaris-TerminalOS-repos --mutation-test ^
  --log acceptance/_evidence/2026-10-28_static_checks_mutation.txt
```

证据文件一律由脚本以 **UTF-8 无 BOM** 写入（`--log` 参数），不走 shell 重定向——Windows PowerShell 的重定向会写出 UTF-16/BOM，git 会把它当二进制。

- 23.2 树同步后须复跑并新增日期文件（不要覆盖旧证据）；`S08` 的监督角色断言在 22.2 上按预期 SKIP，23.2 上必须真实 PASS。
- 变异锚点是文本匹配；重构导致锚点失效时应更新锚点，**不得删检查或删变异**。
