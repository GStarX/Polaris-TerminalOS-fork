#!/usr/bin/env bash
#
# collect-artifacts.sh — 收集构建产物、生成 sha256sums.txt 与 build-info.txt
#
# 用途：
#   1) 把 $OUT 下的 *.zip、recovery.img、boot.img、dtbo.img 复制到
#        <源码根>/out/artifacts/<UTC 时间戳>/
#   2) 在目标目录生成 sha256sums.txt（每个产物的 sha256）
#   3) 生成 build-info.txt（各仓库 git log -1 --oneline、Build ID、构建日期、lunch target 等）
#   4) 使用唯一时间戳目录，绝不覆盖历史收集目录。
#
# 用法：
#   bash scripts/collect-artifacts.sh [选项]
#
# 参数：
#   --source-root DIR   源码根目录（默认 $HOME/android/lineage；用于定位 out/artifacts 与仓库信息）
#   --out-dir DIR       构建输出目录（默认：$OUT，若未设置则 <源码根>/out/target/product/polaris）
#   --lunch-target T    可选，写入 build-info.txt（如 terminalos_polaris-userdebug）
#   --dry-run           只打印将要执行的操作，不复制、不写文件
#   -h, --help          显示本帮助
#
# 安全说明：
#   * 本脚本只操作本地文件，不构建、不下载、不执行任何设备写入/刷机操作。
#   * 幂等/安全：每次创建新的时间戳目录；同一秒重复执行会追加 -1、-2 后缀，不覆盖旧目录。
#
# 状态：脚本语法已静态检查；尚未在真实构建主机执行（待验证）。
#
set -euo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_NAME

readonly DEVICE="polaris"
readonly DEFAULT_SOURCE_ROOT="${HOME}/android/lineage"
readonly -a PROJECTS=(
  device/xiaomi/polaris
  vendor/terminalos
  kernel/xiaomi/sdm845
  vendor/xiaomi/polaris
  vendor/xiaomi/sdm845-common
  .repo/manifests
)

SOURCE_ROOT=""
OUT_DIR=""
LUNCH_TARGET=""
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
用法：bash scripts/collect-artifacts.sh [选项]

把构建产物复制到 out/artifacts/<UTC 时间戳>/，并生成 sha256sums.txt 与 build-info.txt。

选项：
  --source-root DIR   源码根目录（默认 $HOME/android/lineage）
  --out-dir DIR       构建输出目录（默认 $OUT；否则 <源码根>/out/target/product/polaris）
  --lunch-target T    可选，写入 build-info.txt
  --dry-run           只打印操作，不复制、不写文件
  -h, --help          显示本帮助

说明：
  * 收集文件：*.zip、recovery.img、boot.img、dtbo.img。
  * 每次生成新的时间戳目录，不覆盖历史目录。
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
      --out-dir)
        [[ $# -ge 2 ]] || die "--out-dir 需要一个参数"
        OUT_DIR="$2"
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

resolve_source_root() {
  if [[ -n $SOURCE_ROOT ]]; then
    [[ -d "$SOURCE_ROOT" ]] || die "指定的源码根目录不存在：$SOURCE_ROOT"
  elif [[ -d "$PWD/.repo" ]]; then
    SOURCE_ROOT="$PWD"
  elif [[ -d "$DEFAULT_SOURCE_ROOT/.repo" ]]; then
    SOURCE_ROOT="$DEFAULT_SOURCE_ROOT"
  else
    die "未找到源码根目录。请在源码根目录执行，或用 --source-root 指定。"
  fi
  if command -v realpath >/dev/null 2>&1; then
    SOURCE_ROOT="$(realpath -m "$SOURCE_ROOT")"
  fi
}

resolve_out_dir() {
  if [[ -z $OUT_DIR ]]; then
    if [[ -n ${OUT:-} ]]; then
      OUT_DIR="$OUT"
    else
      OUT_DIR="$SOURCE_ROOT/out/target/product/$DEVICE"
    fi
  fi
  [[ -d $OUT_DIR ]] \
    || die "构建输出目录不存在：$OUT_DIR。请先完成构建，或用 --out-dir 指定。"
  if command -v realpath >/dev/null 2>&1; then
    OUT_DIR="$(realpath -m "$OUT_DIR")"
  fi
  log "OUT 目录：$OUT_DIR"
}

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

prop_value() {
  local file=$1
  local key=$2
  local value=""
  if [[ -f $file ]]; then
    value="$(grep -m1 "^${key//./\\.}=" "$file" 2>/dev/null | cut -d= -f2- || true)"
  fi
  printf '%s' "$value"
}

collect_files() {
  local -a candidates=()
  shopt -s nullglob
  candidates=(
    "$OUT_DIR"/*.zip
    "$OUT_DIR"/recovery.img
    "$OUT_DIR"/boot.img
    "$OUT_DIR"/dtbo.img
  )
  shopt -u nullglob
  # 字面量路径（recovery.img 等）即使文件不存在也会留在数组里，必须逐个确认存在
  local -a found=()
  local f
  for f in "${candidates[@]}"; do
    if [[ -f $f ]]; then
      found+=("$f")
    fi
  done
  if (( ${#found[@]} == 0 )); then
    return 0
  fi
  printf '%s\n' "${found[@]}"
}

write_sha256sums() {
  local dest=$1
  shift
  local -a files=("$@")
  if ! command -v sha256sum >/dev/null 2>&1; then
    warn "未找到 sha256sum，跳过 sha256sums.txt 生成。"
    return 0
  fi
  (
    cd "$dest"
    sha256sum -- "${files[@]}" > sha256sums.txt
  )
  log "已生成：$dest/sha256sums.txt"
}

write_build_info() {
  local dest=$1
  local build_prop="$OUT_DIR/system/build.prop"
  local info="$dest/build-info.txt"
  local build_id=""
  local build_date=""
  local lineage_version=""
  local android_release=""
  build_id="$(prop_value "$build_prop" "ro.build.id")"
  build_date="$(prop_value "$build_prop" "ro.build.date")"
  lineage_version="$(prop_value "$build_prop" "ro.lineage.version")"
  android_release="$(prop_value "$build_prop" "ro.build.version.release")"
  {
    printf '# 构建产物信息（scripts/collect-artifacts.sh 自动生成）\n'
    printf '# 注意：产物已收集 ≠ 已验证；实机测试结果见 docs/05_构建与产物记录模板.md\n'
    printf '# 收集时间（UTC）：%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '# 构建主机：%s\n' "$(uname -srm)"
    printf '# 源码根目录：%s\n' "$SOURCE_ROOT"
    printf '# OUT：%s\n' "$OUT_DIR"
    printf '# lunch target（记录值）：%s\n' "${LUNCH_TARGET:-未提供}"
    printf '# Build ID：%s\n' "${build_id:-未找到（system/build.prop 缺失或未构建）}"
    printf '# Android 版本：%s\n' "${android_release:-未知}"
    printf '# Lineage/TerminalOS 版本：%s\n' "${lineage_version:-未知}"
    printf '# 构建日期（build.prop ro.build.date）：%s\n' "${build_date:-未知}"
    printf '#\n# 各仓库 commit（git log -1 --oneline）\n'
    local path line
    for path in "${PROJECTS[@]}"; do
      line=""
      line="$(project_git "$path" log -1 --oneline 2>/dev/null || true)"
      printf '# %-32s %s\n' "$path" "${line:-未同步/无法读取}"
    done
    printf '#\n# 产物 sha256 见同目录 sha256sums.txt\n'
  } > "$info"
  log "已生成：$info"
}

main() {
  parse_args "$@"
  resolve_source_root
  resolve_out_dir

  local -a files=()
  mapfile -t files < <(collect_files)
  if (( ${#files[@]} == 0 )); then
    die "在 $OUT_DIR 下未找到可收集产物（*.zip / recovery.img / boot.img / dtbo.img）。"
  fi

  local artifacts_root="$SOURCE_ROOT/out/artifacts"
  local timestamp
  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  local dest="$artifacts_root/$timestamp"
  local suffix=0
  while [[ -e $dest ]]; do
    suffix=$((suffix + 1))
    (( suffix <= 50 )) || die "无法创建唯一产物目录（已尝试 50 次）：$artifacts_root"
    dest="$artifacts_root/${timestamp}-${suffix}"
  done

  log "计划收集 ${#files[@]} 个产物到：$dest"
  local f
  if [[ $DRY_RUN == true ]]; then
    printf '  + mkdir -p %s\n' "$dest"
    for f in "${files[@]}"; do
      printf '  + cp -p %s %s/\n' "$f" "$dest"
    done
    printf '  + sha256sum ... > %s/sha256sums.txt\n' "$dest"
    printf '  + 生成 %s/build-info.txt\n' "$dest"
    log "dry-run 结束：未复制、未写文件。"
    return 0
  fi

  mkdir -p "$dest"
  local -a copied=()
  for f in "${files[@]}"; do
    cp -p "$f" "$dest/"
    copied+=("$(basename "$f")")
  done

  write_sha256sums "$dest" "${copied[@]}"
  write_build_info "$dest"

  printf '\n========== 产物收集完成 ==========\n'
  printf '目录：%s\n' "$dest"
  ls -lh "$dest"
  printf '\n后续：把产物名与 sha256 记录到 docs/05_构建与产物记录模板.md；\n'
  printf '      实机操作（刷写/恢复）只由首席在 Phase 0 核实后执行，本脚本不涉及。\n'
}

main "$@"
