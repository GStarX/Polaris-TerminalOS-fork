#!/usr/bin/env bash
#
# build-terminalos.sh — 构建 TerminalOS 产品（terminalos_polaris-userdebug）
#
# 用途：
#   在已同步且依赖齐备的源码树中构建 TerminalOS：
#       1) source build/envsetup.sh
#       2) lunch terminalos_polaris-userdebug
#       3) 校验 vendor/terminalos/prebuilt/Termux.apk 的 sha256（对照 Termux.apk.sha256）
#       4) brunch terminalos_polaris
#       5) 产物清单写入 out/terminalos-artifacts.txt
#
# 用法：
#   bash scripts/build-terminalos.sh [--source-root DIR] [--lunch-target TARGET] [--dry-run]
#
# 参数：
#   --source-root DIR   源码根目录（默认 $HOME/android/lineage）
#   --lunch-target T    默认 terminalos_polaris-userdebug；仅允许 terminalos_polaris-{userdebug,user,eng}
#   --dry-run           只打印将要执行的命令，不构建、不校验
#   -h, --help          显示本帮助
#
# 重要说明：
#   * Termux APK 必须由 vendor/terminalos/scripts/fetch-termux.sh 生成，且 sha256 必须匹配；
#     缺失或不匹配时本脚本直接失败，绝不继续构建（避免产物中打包错误 APK）。
#   * 本脚本只编译 ROM 产物，不执行任何设备写入/刷机操作。
#   * `brunch <product>` 依赖 LineageOS envsetup 对完整 product 名的支持；该行为需在首次
#     真实构建时验证（当前状态：未构建）。若不支持，应与 Lead 确认后改为 lunch 后 mka bacon，
#     不要静默改变构建目标。
#
# 状态：脚本语法已静态检查；尚未在真实构建主机执行（待验证）。
#
set -euo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_NAME

readonly DEVICE="polaris"
readonly PRODUCT="terminalos_polaris"
readonly DEFAULT_LUNCH_TARGET="terminalos_polaris-userdebug"
readonly DEFAULT_SOURCE_ROOT="${HOME}/android/lineage"

SOURCE_ROOT=""
LUNCH_TARGET="$DEFAULT_LUNCH_TARGET"
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
用法：bash scripts/build-terminalos.sh [--source-root DIR] [--lunch-target TARGET] [--dry-run]

构建 TerminalOS（terminalos_polaris-userdebug）。

参数：
  --source-root DIR   源码根目录（默认 $HOME/android/lineage）
  --lunch-target T    默认 terminalos_polaris-userdebug；
                      仅允许 terminalos_polaris-{userdebug,user,eng}
  --dry-run           只打印命令，不构建、不校验
  -h, --help          显示本帮助

前置条件：
  * 源码已同步，device/vendor/kernel 依赖齐备（先跑 scripts/fetch-vendor-deps.sh）。
  * vendor/terminalos/prebuilt/Termux.apk 与 Termux.apk.sha256 已由
    vendor/terminalos/scripts/fetch-termux.sh 生成，且 sha256 一致。
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
        LUNCH_TARGET="$2"
        shift 2
        ;;
      --dry-run) DRY_RUN=true; shift ;;
      -h|--help) usage; exit 0 ;;
      *) usage >&2; die "未知参数：$1" ;;
    esac
  done
}

validate_lunch_target() {
  if [[ ! $LUNCH_TARGET =~ ^terminalos_polaris-(userdebug|user|eng)$ ]]; then
    die "非法 lunch target：${LUNCH_TARGET}。只允许 terminalos_polaris-{userdebug,user,eng}。"
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
    warn "内存 ${ram_gb} GB 偏低（官方 21+ 建议 64 GB），完整编译可能 OOM。"
  fi
  if [[ $disk_gb =~ ^[0-9]+$ ]] && (( disk_gb < 100 )); then
    warn "源码分区可用 ${disk_gb} GB 偏低（官方 21+ 建议预留 400 GB）。"
  fi
}

preflight() {
  if [[ $EUID -eq 0 ]]; then
    die "不要以 root 用户运行 AOSP/LineageOS 构建（官方明确禁止）。"
  fi
  [[ -f "$SOURCE_ROOT/build/envsetup.sh" ]] || die "缺少 build/envsetup.sh，源码树不完整。"
  if [[ ! -d "$SOURCE_ROOT/device/xiaomi/polaris" ]]; then
    die "缺少设备树 device/xiaomi/polaris；请先执行 scripts/sync-sources.sh。"
  fi
  if [[ ! -d "$SOURCE_ROOT/vendor/terminalos" ]]; then
    die "缺少 vendor/terminalos；请确认项目仓库已同步到 vendor/terminalos（local manifest 配置）。"
  fi
  if [[ ! -d "$SOURCE_ROOT/kernel/xiaomi/sdm845" ]]; then
    die "缺少内核源码 kernel/xiaomi/sdm845；请先执行 scripts/fetch-vendor-deps.sh 查看阻塞说明。"
  fi
  if [[ ! -f "$SOURCE_ROOT/vendor/xiaomi/polaris/BoardConfigVendor.mk" ]]; then
    die "缺少 vendor blobs（vendor/xiaomi/polaris/BoardConfigVendor.mk）；请先执行 scripts/fetch-vendor-deps.sh。"
  fi
  if ! grep -rqs --include='*.mk' 'terminalos_polaris' "$SOURCE_ROOT/vendor/terminalos"; then
    warn "在 vendor/terminalos 的 *.mk 中未找到 terminalos_polaris 产品定义；lunch 可能失败，请确认产品配置。"
  fi
  check_resources
}

verify_termux_apk() {
  local prebuilt_dir="$SOURCE_ROOT/vendor/terminalos/prebuilt"
  local apk="$prebuilt_dir/Termux.apk"
  local sha_file="$prebuilt_dir/Termux.apk.sha256"
  command -v sha256sum >/dev/null 2>&1 \
    || die "未找到 sha256sum，无法校验 Termux APK（请安装 coreutils）。"
  [[ -f $apk ]] \
    || die "缺少 Termux APK：$apk。请先执行 vendor/terminalos/scripts/fetch-termux.sh。"
  [[ -f $sha_file ]] \
    || die "缺少 Termux APK 校验文件：$sha_file。请重新执行 vendor/terminalos/scripts/fetch-termux.sh。"
  local expected=""
  expected="$(awk 'NR==1 {print $1}' "$sha_file")"
  if [[ ! $expected =~ ^[0-9a-fA-F]{64}$ ]]; then
    die "校验文件格式不正确（首字段应为 64 位 sha256）：$sha_file"
  fi
  local actual=""
  actual="$(sha256sum "$apk" | awk '{print $1}')"
  expected="${expected,,}"
  actual="${actual,,}"
  if [[ $actual != "$expected" ]]; then
    die "Termux.apk sha256 不匹配：期望 ${expected}，实际 ${actual}。请重新执行 fetch-termux.sh（不要手工替换 APK）。"
  fi
  TERMUX_SHA256="$actual"
  log "Termux APK 校验通过：sha256=${actual}"
}

build_terminalos() {
  local start_ts=$SECONDS
  if [[ $DRY_RUN == true ]]; then
    printf '  + cd %s\n' "$SOURCE_ROOT"
    printf '  + source build/envsetup.sh\n'
    printf '  + lunch %s\n' "$LUNCH_TARGET"
    printf '  + 校验 vendor/terminalos/prebuilt/Termux.apk 的 sha256 与 Termux.apk.sha256\n'
    printf '  + brunch %s\n' "$PRODUCT"
    return 0
  fi

  cd "$SOURCE_ROOT"
  # Android/LineageOS 的 envsetup.sh 与构建函数不兼容 `set -u`，构建阶段临时关闭 nounset。
  set +u
  # shellcheck disable=SC1091
  source build/envsetup.sh
  lunch "$LUNCH_TARGET"
  set -u

  verify_termux_apk

  set +u
  brunch "$PRODUCT"
  set -u

  LAST_BUILD_SECONDS=$((SECONDS - start_ts))
  log "构建命令执行完成，耗时约 ${LAST_BUILD_SECONDS} 秒"
}

write_artifacts_file() {
  local out_dir=$1
  local report="$SOURCE_ROOT/out/terminalos-artifacts.txt"
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
    printf '# TerminalOS 构建产物清单（scripts/build-terminalos.sh 自动生成）\n'
    printf '# 注意：本清单只说明产物存在，不代表已通过实机验证。\n'
    printf '# 生成时间（UTC）：%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '# 构建主机：%s\n' "$(uname -srm)"
    printf '# lunch target：%s\n' "$LUNCH_TARGET"
    printf '# 构建命令：brunch %s\n' "$PRODUCT"
    printf '# Termux.apk sha256：%s\n' "${TERMUX_SHA256:-未知}"
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
  printf '\n========== TerminalOS 构建产物 ==========\n'
  printf 'OUT：%s\n' "$out_dir"
  local f
  for f in "${files[@]}"; do
    ls -lh "$f"
  done
  printf '\n提示：本脚本不执行任何设备写入/刷机操作。\n'
  printf '下一步：用 scripts/collect-artifacts.sh 收集并生成 sha256；记录到 docs/05。\n'
}

main() {
  parse_args "$@"
  validate_lunch_target
  resolve_source_root
  log "TerminalOS 构建开始（dry-run=${DRY_RUN}，lunch target=${LUNCH_TARGET}）"
  preflight
  build_terminalos
  if [[ $DRY_RUN == true ]]; then
    log "dry-run 结束：未执行构建。"
    return 0
  fi
  local out_dir="${OUT:-$SOURCE_ROOT/out/target/product/$DEVICE}"
  write_artifacts_file "$out_dir"
  print_artifacts "$out_dir"
}

main "$@"
