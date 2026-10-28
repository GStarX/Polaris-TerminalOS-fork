#!/usr/bin/env bash
#
# sync-sources.sh — 同步 LineageOS / TerminalOS 源码树，并打印关键项目的版本
#
# 用途：
#   1) 在已初始化的源码根目录执行 repo sync（默认参数，不附加并发/强制参数）；
#   2) 同步失败时给出明确的排查/重试指引；
#   3) 同步后打印关键项目路径与 git log -1 --oneline：
#        device/xiaomi/polaris、vendor/terminalos、kernel/xiaomi/sdm845、
#        vendor/xiaomi/polaris、（附带）vendor/xiaomi/sdm845-common、.repo/manifests。
#
# 用法：
#   bash scripts/sync-sources.sh [--source-root DIR] [--dry-run]
#
# 参数：
#   --source-root DIR  源码根目录；默认取当前目录（若含 .repo），否则 $HOME/android/lineage
#   --dry-run          只打印命令，不执行同步
#   -h, --help         显示本帮助
#
# 安全说明：
#   * 本脚本只下载/更新源码，不构建 ROM、不执行任何设备写入/刷机操作。
#   * 默认不添加 -j 等参数；并发调优请按失败提示人工执行。
#   * 幂等：repo sync 可重复执行。
#
# 状态：脚本语法已静态检查；尚未在真实构建主机执行（待验证）。
#
set -euo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_NAME

readonly DEFAULT_SOURCE_ROOT="${HOME}/android/lineage"
# 构建链需要重点关注的项目（顺序即打印顺序）
readonly -a PROJECTS=(
  device/xiaomi/polaris
  vendor/terminalos
  kernel/xiaomi/sdm845
  vendor/xiaomi/polaris
  vendor/xiaomi/sdm845-common
)

SOURCE_ROOT=""
DRY_RUN=false

log()  { printf '[%s] %s\n' "$SCRIPT_NAME" "$*"; }
warn() { printf '[%s] 警告：%s\n' "$SCRIPT_NAME" "$*" >&2; }
die()  { printf '[%s] 错误：%s\n' "$SCRIPT_NAME" "$*" >&2; exit 1; }

on_error() {
  local code=$?
  printf '[%s] 错误：命令失败（退出码 %s）：%s\n' \
    "$SCRIPT_NAME" "$code" "${BASH_COMMAND:-未知命令}" >&2
}
trap on_error ERR

usage() {
  cat <<'EOF'
用法：bash scripts/sync-sources.sh [--source-root DIR] [--dry-run]

在已初始化的源码树中执行 repo sync，并打印关键项目版本。

参数：
  --source-root DIR  源码根目录（默认：当前目录含 .repo 时用当前目录，
                     否则用 $HOME/android/lineage）
  --dry-run          只打印命令，不执行同步
  -h, --help         显示本帮助

说明：
  * 默认使用 repo 默认参数，不附加 -j / --force-sync。
  * 同步失败时脚本会给出降并发重试等排查提示。
  * 本脚本不构建 ROM、不执行任何设备写入/刷机操作。
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source-root)
        [[ $# -ge 2 ]] || die "--source-root 需要一个参数"
        SOURCE_ROOT="$2"
        shift 2
        ;;
      --dry-run) DRY_RUN=true; shift ;;
      -h|--help) usage; exit 0 ;;
      *) usage >&2; die "未知参数：$1" ;;
    esac
  done
}

find_repo_tool() {
  if command -v repo >/dev/null 2>&1; then
    return 0
  fi
  if [[ -x "$HOME/bin/repo" ]]; then
    export PATH="$HOME/bin:$PATH"
    log "使用 $HOME/bin/repo（已加入 PATH）。"
    return 0
  fi
  die "未找到 repo 工具。请先执行 scripts/setup-build-host.sh。"
}

resolve_source_root() {
  if [[ -n $SOURCE_ROOT ]]; then
    [[ -d "$SOURCE_ROOT/.repo" ]] \
      || die "指定的源码目录未初始化：$SOURCE_ROOT/.repo 不存在（先执行 scripts/init-sources.sh）。"
  elif [[ -d "$PWD/.repo" ]]; then
    SOURCE_ROOT="$PWD"
  elif [[ -d "$DEFAULT_SOURCE_ROOT/.repo" ]]; then
    SOURCE_ROOT="$DEFAULT_SOURCE_ROOT"
  else
    die "未找到已初始化的源码树。请在源码根目录执行，或用 --source-root 指定（先执行 scripts/init-sources.sh）。"
  fi
  if command -v realpath >/dev/null 2>&1; then
    SOURCE_ROOT="$(realpath -m "$SOURCE_ROOT")"
  fi
  log "源码根目录：$SOURCE_ROOT"
}

# 在 repo 管理的工作区里，git 元数据通常在 .repo/projects/<path>.git；
# 这里两种布局都兼容，任何一步失败都返回非零而不是静默继续。
project_git() {
  local path=$1
  shift
  local dir="$SOURCE_ROOT/$path"
  if [[ -d $dir ]] && git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$dir" "$@"
    return $?
  fi
  local bare_dir="$SOURCE_ROOT/.repo/projects/$path.git"
  if [[ -d $bare_dir ]]; then
    git --git-dir="$bare_dir" "$@"
    return $?
  fi
  return 1
}

run_sync() {
  log "执行 repo sync（默认参数，未附加 -j / --force-sync）"
  if [[ $DRY_RUN == true ]]; then
    printf '  + cd %s\n' "$SOURCE_ROOT"
    printf '  + repo sync\n'
    return 0
  fi
  if ! ( cd "$SOURCE_ROOT" && repo sync ); then
    printf '\n[%s] repo sync 失败。按下面顺序排查：\n' "$SCRIPT_NAME" >&2
    printf '  1) 网络/并发：降低并发并强制重置单个项目后重试，例如在源码目录执行：\n' >&2
    printf '       repo sync -j4 --force-sync --no-clone-bundle\n' >&2
    printf '     （机器/网络较差时把 -j4 再调低；本脚本默认不带并发参数）\n' >&2
    printf '  2) 磁盘：确认 %s 所在分区至少预留约 400 GB（官方 21+ 建议）。\n' "$SOURCE_ROOT" >&2
    printf '  3) 凭据/代理：检查 GitHub 访问、Git LFS 拉取、SSH/HTTPS 凭据。\n' >&2
    printf '  4) 局部重试：repo sync <project-path>，例如 repo sync device/xiaomi/polaris\n' >&2
    printf '  5) 依据 repo 的具体报错处理；不要直接删除 .repo 重来（会丢失已下载内容）。\n' >&2
    exit 1
  fi
}

print_manifest_branch() {
  local manifests_dir="$SOURCE_ROOT/.repo/manifests"
  if [[ -d $manifests_dir ]]; then
    local branch=""
    branch="$(git -C "$manifests_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    printf 'manifest 分支：%s\n' "${branch:-未知}"
  fi
}

print_project_versions() {
  local path
  for path in "${PROJECTS[@]}"; do
    printf '\n== %s ==\n' "$path"
    if [[ ! -d "$SOURCE_ROOT/$path" ]]; then
      printf '  未同步：目录不存在\n'
      continue
    fi
    local line=""
    if line="$(project_git "$path" log -1 --oneline 2>/dev/null)" && [[ -n $line ]]; then
      printf '  HEAD    : %s\n' "$line"
    else
      printf '  无法读取 git 信息（不是 repo 项目或同步不完整）\n'
    fi
    local branch=""
    branch="$(project_git "$path" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    if [[ -n $branch ]]; then
      printf '  branch  : %s\n' "$branch"
    fi
  done
}

warn_missing_projects() {
  local path
  local missing=0
  for path in "${PROJECTS[@]}"; do
    if [[ ! -d "$SOURCE_ROOT/$path" ]]; then
      warn "项目目录不存在：$path（local manifest 可能未生效或项目尚未同步）"
      missing=$((missing + 1))
    fi
  done
  if (( missing > 0 )); then
    warn "共 ${missing} 个关键项目缺失；TerminalOS/23.2 构建依赖请先看 scripts/fetch-vendor-deps.sh 的检查结果。"
  fi
}

main() {
  parse_args "$@"
  find_repo_tool
  resolve_source_root
  log "开始同步（耗时取决于网络与本地缓存，可能需要较长时间）"
  run_sync
  if [[ $DRY_RUN == true ]]; then
    log "dry-run 结束：未执行同步。"
    return 0
  fi
  printf '\n========== 同步后关键项目版本 ==========\n'
  print_manifest_branch
  print_project_versions
  warn_missing_projects
  log "同步完成（尚未构建）。下一步：bash scripts/fetch-vendor-deps.sh --source-root ${SOURCE_ROOT}"
}

main "$@"
