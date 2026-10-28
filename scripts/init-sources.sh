#!/usr/bin/env bash
#
# init-sources.sh — 初始化 LineageOS 源码树并挂载 TerminalOS 的 local manifest
#
# 用途：
#   1) 创建源码目录（默认 $HOME/android/lineage）；
#   2) 执行 repo init（LineageOS/android.git，默认分支 lineage-23.2）；
#   3) 把项目的 local_manifests/terminalos.xml 复制到 .repo/local_manifests/。
#
# 用法：
#   bash scripts/init-sources.sh [选项]
#
# 参数：
#   --branch BRANCH          manifest 分支，默认 lineage-22.2（可构建基线）；
#                            允许 lineage-23.2（Android 16 实验目标）
#   --source-root DIR        源码根目录，默认 $HOME/android/lineage
#   --local-manifest FILE    指定 terminalos.xml 路径；
#                            默认在项目仓库 local_manifests/terminalos.xml 查找
#   --no-local-manifest      不复制 local manifest（用于纯上游 lineage-22.2 基线：
#                            docs/03 的 P1-02/P1-03 路线）
#   --force-init             即使 .repo 已存在且分支一致，也重新执行 repo init
#   --dry-run                只打印将要执行的命令，不做任何修改
#   -h, --help               显示本帮助
#
# 安全说明：
#   * 本脚本只做源码初始化，不构建 ROM、不执行任何设备写入/刷机操作。
#   * 幂等：分支一致时跳过 repo init；local manifest 内容一致时跳过复制。
#   * 本脚本不自动修改 manifest 内容；local manifest 由项目仓库提供。
#
# 状态：脚本语法已静态检查；尚未在真实构建主机执行（待验证）。
#
set -euo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_NAME
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PROJECT_ROOT

readonly MANIFEST_URL="https://github.com/LineageOS/android.git"
readonly DEFAULT_BRANCH="lineage-22.2"
readonly DEFAULT_SOURCE_ROOT="${HOME}/android/lineage"

BRANCH="$DEFAULT_BRANCH"
SOURCE_ROOT="$DEFAULT_SOURCE_ROOT"
LOCAL_MANIFEST=""
FORCE_INIT=false
NO_LOCAL_MANIFEST=false
DRY_RUN=false

log()  { printf '[%s] %s\n' "$SCRIPT_NAME" "$*"; }
warn() { printf '[%s] 警告：%s\n' "$SCRIPT_NAME" "$*" >&2; }
die()  { printf '[%s] 错误：%s\n' "$SCRIPT_NAME" "$*" >&2; exit 1; }

on_error() {
  local code=$?
  printf '[%s] 错误：命令失败（退出码 %s）：%s\n' \
    "$SCRIPT_NAME" "$code" "${BASH_COMMAND:-未知命令}" >&2
  printf '[%s] 提示：常见原因是网络/凭据问题，或源码目录权限不足；修复后可重新执行。\n' \
    "$SCRIPT_NAME" >&2
}
trap on_error ERR

usage() {
  cat <<'EOF'
用法：bash scripts/init-sources.sh [选项]

初始化 LineageOS 源码树（默认 $HOME/android/lineage），并复制 TerminalOS local manifest。

选项：
  --branch BRANCH        默认 lineage-22.2（可构建基线）；lineage-23.2 为实验目标
  --source-root DIR      指定源码根目录（默认 $HOME/android/lineage）
  --local-manifest FILE  指定 local_manifests/terminalos.xml 路径
  --no-local-manifest    不复制 local manifest（纯上游 lineage-22.2 基线用）
  --force-init           分支一致也重新执行 repo init
  --dry-run              只打印命令，不执行
  -h, --help             显示本帮助

说明：
  * 依赖 repo 工具（scripts/setup-build-host.sh 会安装到 ~/bin）。
  * 本脚本不构建 ROM、不执行任何设备写入/刷机操作。
  * local manifest 需由项目仓库提供：local_manifests/terminalos.xml。
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --branch)
        [[ $# -ge 2 ]] || die "--branch 需要一个参数"
        BRANCH="$2"
        shift 2
        ;;
      --source-root)
        [[ $# -ge 2 ]] || die "--source-root 需要一个参数"
        SOURCE_ROOT="$2"
        shift 2
        ;;
      --local-manifest)
        [[ $# -ge 2 ]] || die "--local-manifest 需要一个参数"
        LOCAL_MANIFEST="$2"
        shift 2
        ;;
      --force-init) FORCE_INIT=true; shift ;;
      --no-local-manifest) NO_LOCAL_MANIFEST=true; shift ;;
      --dry-run) DRY_RUN=true; shift ;;
      -h|--help) usage; exit 0 ;;
      *) usage >&2; die "未知参数：$1" ;;
    esac
  done
}

validate_branch() {
  case "$BRANCH" in
    lineage-23.2|lineage-22.2) ;;
    *)
      die "不支持的分支：${BRANCH}。允许：lineage-22.2（默认，可构建基线）或 lineage-23.2（Android 16 实验目标）。"
      ;;
  esac
  if [[ $BRANCH == lineage-22.2 ]]; then
    warn "选择 lineage-22.2 基线：local manifest 中的 revision 必须与 22.2 兼容，否则 repo sync 会失败。"
    warn "纯上游 22.2 基线（docs/03 的 P1-02/P1-03）请加 --no-local-manifest，避免把 23.2 的自有仓库/设备树 fork 叠加到基线上。"
  fi
}

resolve_source_root() {
  # 统一为绝对路径；目录可能尚不存在，只用 -m（不要求路径存在）
  if command -v realpath >/dev/null 2>&1; then
    SOURCE_ROOT="$(realpath -m "$SOURCE_ROOT")"
  else
    case "$SOURCE_ROOT" in
      /*) ;;
      *) SOURCE_ROOT="$PWD/$SOURCE_ROOT" ;;
    esac
  fi
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
  die "未找到 repo 工具。请先执行 scripts/setup-build-host.sh（会把 repo 安装到 ~/bin 并提示配置 PATH）。"
}

find_local_manifest() {
  if [[ -n $LOCAL_MANIFEST ]]; then
    [[ -f $LOCAL_MANIFEST ]] || die "指定的 local manifest 不存在：$LOCAL_MANIFEST"
    printf '%s\n' "$LOCAL_MANIFEST"
    return 0
  fi
  # 按分支选择对应的 local manifest：
  #   lineage-22.2 -> local_manifests/terminalos-22.2.xml（revision 指向 terminalos/lineage-22.2）
  #   lineage-23.2 -> local_manifests/terminalos.xml（revision 指向 terminalos/lineage-23.2）
  local branch_manifest="terminalos.xml"
  if [[ $BRANCH == lineage-22.2 ]]; then
    branch_manifest="terminalos-22.2.xml"
  fi
  local -a candidates=(
    "$PROJECT_ROOT/local_manifests/${branch_manifest}"
    "$PROJECT_ROOT/local_manifests/terminalos.xml"
    "$SOURCE_ROOT/.repo/local_manifests/terminalos.xml"
  )
  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -f $candidate ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  die "未找到 local manifest（期望 ${PROJECT_ROOT}/local_manifests/${branch_manifest}）。请把项目仓库放到构建主机，或用 --local-manifest 指定。"
}

validate_local_manifest() {
  local file=$1
  # local manifest 允许大段注释，因此在整个文件里查找 <manifest>（文件很小，开销可忽略）
  if ! grep -q '<manifest' "$file"; then
    die "local manifest 格式可疑（未找到 <manifest>）：$file"
  fi
}

current_manifest_branch() {
  local manifests_dir="$SOURCE_ROOT/.repo/manifests"
  [[ -d $manifests_dir ]] || return 1
  git -C "$manifests_dir" rev-parse --abbrev-ref HEAD 2>/dev/null
}

run_repo_init() {
  log "执行 repo init：分支 ${BRANCH}，manifest ${MANIFEST_URL}"
  printf '  + cd %s\n' "$SOURCE_ROOT"
  printf '  + repo init -u %s -b %s --git-lfs --no-clone-bundle\n' "$MANIFEST_URL" "$BRANCH"
  if [[ $DRY_RUN == true ]]; then
    return 0
  fi
  (
    cd "$SOURCE_ROOT"
    repo init -u "$MANIFEST_URL" -b "$BRANCH" --git-lfs --no-clone-bundle
  )
}

install_local_manifest() {
  local src=$1
  local dest_dir="$SOURCE_ROOT/.repo/local_manifests"
  local dest="$dest_dir/terminalos.xml"
  if [[ $DRY_RUN == true ]]; then
    printf '  + mkdir -p %s\n' "$dest_dir"
    printf '  + cp %s %s\n' "$src" "$dest"
    return 0
  fi
  mkdir -p "$dest_dir"
  if [[ -f $dest ]] && cmp -s "$src" "$dest"; then
    log "local manifest 内容一致，跳过复制：$dest"
    return 0
  fi
  cp "$src" "$dest"
  log "已复制 local manifest：$src -> $dest"
}

verify_layout() {
  if [[ $DRY_RUN == true ]]; then
    return 0
  fi
  [[ -f "$SOURCE_ROOT/.repo/manifests/default.xml" ]] \
    || die "repo init 未生成 .repo/manifests/default.xml，初始化可能失败。"
  if [[ $NO_LOCAL_MANIFEST == false ]]; then
    [[ -f "$SOURCE_ROOT/.repo/local_manifests/terminalos.xml" ]] \
      || die "local manifest 未就位：$SOURCE_ROOT/.repo/local_manifests/terminalos.xml"
  fi
}

main() {
  parse_args "$@"
  validate_branch
  find_repo_tool
  resolve_source_root
  local manifest=""
  if [[ $NO_LOCAL_MANIFEST == true ]]; then
    log "未应用 local manifest（纯上游基线模式；适用于 docs/03 的 P1-02/P1-03）。"
  else
    manifest="$(find_local_manifest)"
    validate_local_manifest "$manifest"
    log "local manifest：${manifest}"
  fi
  log "分支：${BRANCH}"
  log "源码目录：${SOURCE_ROOT}"

  if [[ $DRY_RUN == true ]]; then
    printf '  + mkdir -p %s\n' "$SOURCE_ROOT"
    run_repo_init
    if [[ $NO_LOCAL_MANIFEST == false ]]; then
      install_local_manifest "$manifest"
    fi
    log "dry-run 结束：以上命令均未真正执行。"
    return 0
  fi

  mkdir -p "$SOURCE_ROOT"
  if [[ -d "$SOURCE_ROOT/.repo" ]] && [[ $FORCE_INIT == false ]]; then
    local current=""
    current="$(current_manifest_branch || true)"
    if [[ $current == "$BRANCH" ]]; then
      log ".repo 已存在且 manifest 分支为 ${BRANCH}，跳过 repo init（需要重新初始化请加 --force-init）。"
    else
      log ".repo 已存在但 manifest 分支为 ${current:-未知}，重新执行 repo init 切换到 ${BRANCH}。"
      run_repo_init
    fi
  else
    run_repo_init
  fi

  if [[ $NO_LOCAL_MANIFEST == false ]]; then
    install_local_manifest "$manifest"
  fi
  verify_layout
  log "初始化完成（尚未同步、未构建）。"
  log "下一步：bash scripts/sync-sources.sh --source-root ${SOURCE_ROOT}"
}

main "$@"
