#!/usr/bin/env bash
#
# verify-pins.sh — 只读校验源码树各仓库 HEAD 是否等于交付线 pin 文件
#
# 用途：
#   在构建前（或构建记录归档时）确认「实际源码输入 == 结案/验收所依据的 commit」，
#   即 K3-01「可复现构建」中的 sha 校验环节。
#
# 用法：
#   bash scripts/verify-pins.sh [--source-root DIR] [--pins FILE]
#
# 参数：
#   --source-root DIR  已初始化的源码根（含 .repo）；默认当前目录（含 .repo）或 $HOME/android/lineage
#   --pins FILE        pin 文件；默认本仓库 local_manifests/pins-22.2.txt
#   -h, --help         显示本帮助
#
# 退出码：
#   0  全部仓库 HEAD 与 pin 一致
#   1  存在不一致或仓库缺失
#   2  参数/环境错误
#
# 安全说明：
#   * 本脚本只读：不 fetch、不 checkout、不修改任何仓库、不构建、不执行任何设备写入。
#   * 不改变任何既有脚本的行为；构建是否允许继续由人（或 CI）依据退出码决定。
#
# 状态：脚本静态审读完成；尚未在真实源码树上执行（本机无 Linux 构建机，待验证）。
#
set -euo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_NAME
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PROJECT_ROOT

DEFAULT_SOURCE_ROOT="${HOME}/android/lineage"
DEFAULT_PINS_FILE="${PROJECT_ROOT}/local_manifests/pins-22.2.txt"

SOURCE_ROOT=""
PINS_FILE=""
ok_count=0
fail_count=0
missing_count=0

log()  { printf '[%s] %s\n' "$SCRIPT_NAME" "$*"; }
warn() { printf '[%s] 警告：%s\n' "$SCRIPT_NAME" "$*" >&2; }
die()  { printf '[%s] 错误：%s\n' "$SCRIPT_NAME" "$*" >&2; exit 2; }

usage() {
  cat <<'EOF'
用法：bash scripts/verify-pins.sh [--source-root DIR] [--pins FILE]

只读校验源码树各仓库 HEAD 是否等于交付线 pin 文件（默认 local_manifests/pins-22.2.txt）。

参数：
  --source-root DIR  已初始化的源码根（含 .repo）；默认当前目录（含 .repo）或 $HOME/android/lineage
  --pins FILE        pin 文件路径
  -h, --help         显示本帮助

说明：
  * 只读：不 fetch / 不 checkout / 不改仓库 / 不构建 / 不触碰设备。
  * 不一致时退出码为 1；是否阻止构建由人或 CI 依据退出码决定。
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
      --pins)
        [[ $# -ge 2 ]] || die "--pins 需要一个参数"
        PINS_FILE="$2"
        shift 2
        ;;
      -h|--help) usage; exit 0 ;;
      *) usage >&2; die "未知参数：$1" ;;
    esac
  done
}

resolve_source_root() {
  if [[ -n $SOURCE_ROOT ]]; then
    [[ -d "$SOURCE_ROOT/.repo" ]] \
      || die "指定的源码目录未初始化：$SOURCE_ROOT/.repo 不存在。"
  elif [[ -d "$PWD/.repo" ]]; then
    SOURCE_ROOT="$PWD"
  elif [[ -d "$DEFAULT_SOURCE_ROOT/.repo" ]]; then
    SOURCE_ROOT="$DEFAULT_SOURCE_ROOT"
  else
    die "未找到已初始化的源码树。请在源码根目录执行，或用 --source-root 指定。"
  fi
  if command -v realpath >/dev/null 2>&1; then
    SOURCE_ROOT="$(realpath -m "$SOURCE_ROOT")"
  fi
  log "源码根目录：$SOURCE_ROOT"
}

resolve_pins_file() {
  if [[ -z $PINS_FILE ]]; then
    PINS_FILE="$DEFAULT_PINS_FILE"
  fi
  [[ -f $PINS_FILE ]] || die "pin 文件不存在：$PINS_FILE"
  log "pin 文件：$PINS_FILE"
}

# 与其它脚本一致：优先工作树，其次 .repo/projects 下的裸库
project_head() {
  local path=$1
  local dir="$SOURCE_ROOT/$path"
  if [[ -d $dir ]] && git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$dir" rev-parse HEAD 2>/dev/null && return 0
  fi
  local bare_dir="$SOURCE_ROOT/.repo/projects/$path.git"
  if [[ -d $bare_dir ]]; then
    git --git-dir="$bare_dir" rev-parse HEAD 2>/dev/null && return 0
  fi
  return 1
}

check_pins() {
  local path sha head line
  while IFS= read -r line || [[ -n $line ]]; do
    # 去掉行尾 CR（Windows 编辑过的文件）与首尾空白
    line="${line%$'\r'}"
    [[ -z ${line//[[:space:]]/} ]] && continue
    [[ $line == \#* ]] && continue
    path="$(printf '%s' "$line" | awk '{print $1}')"
    sha="$(printf '%s' "$line" | awk '{print $2}')"
    [[ -n $path && -n $sha ]] || { warn "跳过无法解析的行：$line"; continue; }
    if [[ ! $sha =~ ^[0-9a-f]{40}$ ]]; then
      warn "pin 的 sha 不是 40 位小写十六进制：$path -> $sha"
      fail_count=$((fail_count + 1))
      continue
    fi
    if ! head="$(project_head "$path" 2>/dev/null)" || [[ -z $head ]]; then
      printf '[缺失] %-32s 未同步或不是 repo 项目\n' "$path"
      missing_count=$((missing_count + 1))
      continue
    fi
    if [[ $head == "$sha" ]]; then
      printf '[一致] %-32s %s\n' "$path" "$head"
      ok_count=$((ok_count + 1))
    else
      printf '[不一致] %-30s pin=%s 实际=%s\n' "$path" "$sha" "$head"
      fail_count=$((fail_count + 1))
    fi
  done < "$PINS_FILE"

  printf '\n========== pin 校验结论 ==========\n'
  printf '一致：%d 项；不一致：%d 项；缺失：%d 项\n' "$ok_count" "$fail_count" "$missing_count"
  if (( fail_count > 0 || missing_count > 0 )); then
    printf '结论：构建输入与 pin 不一致。请先确认 sync 是否漂移；不要带着不一致的输入产出验收结论。\n'
    exit 1
  fi
  printf '结论：全部仓库与 pin 一致（这只证明输入未漂移，不代表构建成功或可启动）。\n'
}

main() {
  parse_args "$@"
  resolve_source_root
  resolve_pins_file
  log "开始只读校验（不 fetch、不 checkout、不修改仓库）"
  check_pins
  log "本脚本未执行任何设备写入/刷机操作。"
}

main "$@"
