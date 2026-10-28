#!/usr/bin/env bash
#
# build-baseline.sh — 构建未修改的 lineage_polaris 基线（用于验证工具链与上游可构建性）
#
# 用途：
#   在已同步的 LineageOS 源码树中，按 LineageOS 官方流程构建基线：
#       source build/envsetup.sh
#       breakfast polaris
#       brunch polaris
#   构建成功后把产物清单写入 out/baseline-artifacts.txt。
#
# 用法：
#   bash scripts/build-baseline.sh [--source-root DIR] [--lunch-target TARGET] [--dry-run]
#
# 参数：
#   --source-root DIR   源码根目录（默认 $HOME/android/lineage）
#   --lunch-target T    显式指定 lunch target，仅允许 lineage_polaris-{userdebug,user,eng}；
#                       传入时用 `lunch <target>` 代替 `breakfast polaris`，随后仍执行
#                       `brunch polaris`（brunch 会按设备名选择 lineage_polaris 的默认变体）
#   --dry-run           只打印将要执行的命令，不构建
#   -h, --help          显示本帮助
#
# 安全说明：
#   * 本脚本只编译 ROM 产物，不执行任何设备写入/刷机操作。
#   * 首次执行前应先通过 scripts/fetch-vendor-deps.sh 检查依赖；
#     23.2 上游 kernel / vendor blobs 缺失属于已知阻塞项（见 docs/02_构建环境与依赖.md）。
#   * 本脚本只构建未修改的 lineage_polaris；TerminalOS 产品请用 build-terminalos.sh。
#
# 状态：脚本语法已静态检查；尚未在真实构建主机执行（待验证）。
#
set -euo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_NAME

readonly DEVICE="polaris"
readonly DEFAULT_SOURCE_ROOT="${HOME}/android/lineage"

SOURCE_ROOT=""
LUNCH_TARGET_OVERRIDE=""
DRY_RUN=false

log()  { printf '[%s] %s\n' "$SCRIPT_NAME" "$*"; }
warn() { printf '[%s] 警告：%s\n' "$SCRIPT_NAME" "$*" >&2; }
die()  { printf '[%s] 错误：%s\n' "$SCRIPT_NAME" "$*" >&2; exit 1; }

on_error() {
  local code=$?
  printf '[%s] 错误：命令失败（退出码 %s）：%s\n' \
    "$SCRIPT_NAME" "$code" "${BASH_COMMAND:-未知命令}" >&2
  printf '[%s] 提示：保留完整构建输出，并在 docs/05_构建与产物记录模板.md 记录失败日志路径。\n' \
    "$SCRIPT_NAME" >&2
}
trap on_error ERR

usage() {
  cat <<'EOF'
用法：bash scripts/build-baseline.sh [--source-root DIR] [--lunch-target TARGET] [--dry-run]

构建未修改的 lineage_polaris 基线（验证工具链/上游可构建性）。

参数：
  --source-root DIR   源码根目录（默认 $HOME/android/lineage）
  --lunch-target T    显式 lunch target，仅允许 lineage_polaris-{userdebug,user,eng}
  --dry-run           只打印命令，不构建
  -h, --help          显示本帮助

说明：
  * 默认流程：source build/envsetup.sh → breakfast polaris → brunch polaris。
  * 成功后产物清单写入 <源码根>/out/baseline-artifacts.txt。
  * 本脚本不执行任何设备写入/刷机操作。
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
      --lunch-target)
        [[ $# -ge 2 ]] || die "--lunch-target 需要一个参数"
        LUNCH_TARGET_OVERRIDE="$2"
        shift 2
        ;;
      --dry-run) DRY_RUN=true; shift ;;
      -h|--help) usage; exit 0 ;;
      *) usage >&2; die "未知参数：$1" ;;
    esac
  done
}

validate_lunch_target() {
  if [[ -z $LUNCH_TARGET_OVERRIDE ]]; then
    return 0
  fi
  if [[ ! $LUNCH_TARGET_OVERRIDE =~ ^lineage_polaris-(userdebug|user|eng)$ ]]; then
    die "非法 --lunch-target：${LUNCH_TARGET_OVERRIDE}。基线脚本只允许 lineage_polaris-{userdebug,user,eng}。"
  fi
}

resolve_source_root() {
  if [[ -n $SOURCE_ROOT ]]; then
    [[ -f "$SOURCE_ROOT/build/envsetup.sh" ]] \
      || die "指定的源码目录无效：$SOURCE_ROOT/build/envsetup.sh 不存在。"
  elif [[ -d "$PWD/.repo" ]] && [[ -f "$PWD/build/envsetup.sh" ]]; then
    SOURCE_ROOT="$PWD"
  elif [[ -f "$DEFAULT_SOURCE_ROOT/build/envsetup.sh" ]]; then
    SOURCE_ROOT="$DEFAULT_SOURCE_ROOT"
  else
    die "未找到已初始化的源码树。请在源码根目录执行，或用 --source-root 指定。"
  fi
  if command -v realpath >/dev/null 2>&1; then
    SOURCE_ROOT="$(realpath -m "$SOURCE_ROOT")"
  fi
  log "源码根目录：$SOURCE_ROOT"
}

manifest_branch() {
  local manifests_dir="$SOURCE_ROOT/.repo/manifests"
  [[ -d $manifests_dir ]] || return 1
  git -C "$manifests_dir" rev-parse --abbrev-ref HEAD 2>/dev/null
}

check_resources() {
  local ram_gb="未知"
  local disk_gb="未知"
  if [[ -r /proc/meminfo ]]; then
    ram_gb="$(awk '/^MemTotal:/ {printf "%d", $2/1024/1024}' /proc/meminfo 2>/dev/null || true)"
    [[ -n $ram_gb ]] || ram_gb="未知"
  fi
  if command -v df >/dev/null 2>&1; then
    disk_gb="$(df -BG --output=avail "$SOURCE_ROOT" 2>/dev/null | tail -n 1 | tr -dc '0-9' || true)"
    [[ -n $disk_gb ]] || disk_gb="未知"
  fi
  log "构建主机资源：内存 ${ram_gb} GB，源码分区可用 ${disk_gb} GB"
  if [[ $ram_gb =~ ^[0-9]+$ ]] && (( ram_gb < 32 )); then
    warn "内存 ${ram_gb} GB 偏低（官方 21+ 建议 64 GB），完整编译可能 OOM，请注意观察。"
  fi
  if [[ $disk_gb =~ ^[0-9]+$ ]] && (( disk_gb < 100 )); then
    warn "源码分区可用 ${disk_gb} GB 偏低（官方 21+ 建议预留 400 GB），构建可能中途失败。"
  fi
}

preflight() {
  if [[ $EUID -eq 0 ]]; then
    die "不要以 root 用户运行 AOSP/LineageOS 构建（官方明确禁止）。"
  fi
  [[ -f "$SOURCE_ROOT/build/envsetup.sh" ]] || die "缺少 build/envsetup.sh，源码树不完整。"
  if [[ ! -d "$SOURCE_ROOT/device/xiaomi/polaris" ]]; then
    die "缺少设备树 device/xiaomi/polaris；请先执行 scripts/sync-sources.sh 并检查 local manifest。"
  fi
  if [[ ! -f "$SOURCE_ROOT/vendor/xiaomi/polaris/BoardConfigVendor.mk" ]]; then
    die "缺少 vendor blobs（vendor/xiaomi/polaris/BoardConfigVendor.mk）；请先执行 scripts/fetch-vendor-deps.sh 查看阻塞说明。"
  fi
  if [[ ! -d "$SOURCE_ROOT/kernel/xiaomi/sdm845" ]]; then
    die "缺少内核源码 kernel/xiaomi/sdm845；请先执行 scripts/sync-sources.sh 并检查 local manifest。"
  fi
  local branch=""
  branch="$(manifest_branch || true)"
  log "当前 manifest 分支：${branch:-未知}"
  check_resources
}

build_baseline() {
  local start_ts=$SECONDS
  if [[ $DRY_RUN == true ]]; then
    printf '  + cd %s\n' "$SOURCE_ROOT"
    printf '  + source build/envsetup.sh\n'
    if [[ -n $LUNCH_TARGET_OVERRIDE ]]; then
      printf '  + lunch %s\n' "$LUNCH_TARGET_OVERRIDE"
    else
      printf '  + breakfast %s\n' "$DEVICE"
    fi
    printf '  + brunch %s\n' "$DEVICE"
    return 0
  fi

  cd "$SOURCE_ROOT"
  # Android/LineageOS 的 envsetup.sh 与构建函数不兼容 `set -u`（会引用未定义变量），
  # 因此构建阶段临时关闭 nounset；命令结束后恢复。
  set +u
  # shellcheck disable=SC1091
  source build/envsetup.sh
  if [[ -n $LUNCH_TARGET_OVERRIDE ]]; then
    lunch "$LUNCH_TARGET_OVERRIDE"
  else
    breakfast "$DEVICE"
  fi
  brunch "$DEVICE"
  set -u

  LAST_BUILD_SECONDS=$((SECONDS - start_ts))
  log "构建命令执行完成，耗时约 ${LAST_BUILD_SECONDS} 秒"
}

write_artifacts_file() {
  local out_dir=$1
  local report="$SOURCE_ROOT/out/baseline-artifacts.txt"
  local -a files=()
  shopt -s nullglob
  files=( "$out_dir"/*.zip "$out_dir"/*.img "$out_dir"/*.tar.md5 )
  shopt -u nullglob
  if (( ${#files[@]} == 0 )); then
    die "构建命令返回成功，但 $out_dir 下未找到 zip/img 产物；请检查构建日志。"
  fi
  mkdir -p "$SOURCE_ROOT/out"
  local f size
  {
    printf '# 基线构建产物清单（scripts/build-baseline.sh 自动生成）\n'
    printf '# 注意：本清单只说明产物存在，不代表已通过实机验证。\n'
    printf '# 生成时间（UTC）：%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '# 构建主机：%s\n' "$(uname -srm)"
    printf '# 目标：lineage_polaris-userdebug（brunch polaris）\n'
    printf '# 构建耗时（秒）：%s\n' "${LAST_BUILD_SECONDS:-未知}"
    printf '# OUT：%s\n' "$out_dir"
    printf '#\n# 文件\t大小(字节)\n'
    for f in "${files[@]}"; do
      size="$(wc -c < "$f" | tr -d ' ')"
      printf '%s\t%s\n' "$(basename "$f")" "$size"
    done
  } > "$report"
  log "产物清单已写入：$report"
}

print_artifacts() {
  local out_dir=$1
  local -a files=()
  shopt -s nullglob
  files=( "$out_dir"/*.zip "$out_dir"/*.img "$out_dir"/*.tar.md5 )
  shopt -u nullglob
  printf '\n========== 基线构建产物 ==========\n'
  printf 'OUT：%s\n' "$out_dir"
  local f
  for f in "${files[@]}"; do
    ls -lh "$f"
  done
  printf '\n提示：产物仅供后续验证/收集，本脚本不执行任何设备写入/刷机操作。\n'
  printf '下一步：用 scripts/collect-artifacts.sh 收集并生成 sha256；记录到 docs/05。\n'
}

main() {
  parse_args "$@"
  validate_lunch_target
  resolve_source_root
  log "基线构建开始（dry-run=${DRY_RUN}）"
  preflight
  build_baseline
  if [[ $DRY_RUN == true ]]; then
    log "dry-run 结束：未执行构建。"
    return 0
  fi
  local out_dir="${OUT:-$SOURCE_ROOT/out/target/product/$DEVICE}"
  write_artifacts_file "$out_dir"
  print_artifacts "$out_dir"
}

main "$@"
