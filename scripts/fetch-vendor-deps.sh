#!/usr/bin/env bash
#
# fetch-vendor-deps.sh — 检查后置依赖（内核分支 / vendor blobs / Termux APK）
#
# 用途：
#   在 repo sync 之后、开始构建之前，对"后置依赖"做只读检查：
#     1) kernel/xiaomi/sdm845 是否存在目标分支（默认 lineage-22.2）；
#     2) vendor/xiaomi/polaris/BoardConfigVendor.mk 是否存在；
#     3) 提示 Termux APK 需要先执行 vendor/terminalos/scripts/fetch-termux.sh。
#
# 用法：
#   bash scripts/fetch-vendor-deps.sh [--source-root DIR] [--target-branch BRANCH]
#                                     [--allow-22.2-pinned-deps] [--dry-run]
#
# 参数：
#   --source-root DIR          源码根目录；默认当前目录（含 .repo）或 $HOME/android/lineage
#   --target-branch BRANCH     目标分支，默认 lineage-22.2（基线）；lineage-23.2 为实验目标
#   --allow-22.2-pinned-deps   显式允许"内核无 23.2 分支、但 local manifest 已锁定
#                              revision=lineage-22.2"的实验路径：
#                              此时内核分支缺失降级为警告（不是阻塞），退出码可为 0；
#                              该方案下"23.2 设备树 + 22.2 内核"能否编译/启动未验证。
#   --dry-run                  只打印检查项，不实际读取（本脚本本身只读）
#   -h, --help                 显示本帮助
#
# 退出码：
#   0  无阻塞项（使用 --allow-22.2-pinned-deps 时可能只代表"按 22.2 锁定方案可以继续",
#      不代表编译/启动成功）
#   1  存在阻塞项（内核分支缺失且无 manifest 锁定证据 / vendor blobs 缺失 / 源码未同步）
#   2  参数或环境错误
#
# 安全说明：
#   * 本脚本只读：不下载、不修改 manifest、不构建、不执行任何设备写入/刷机操作。
#   * 已知上游状态（2026-10-27 核实）：kernel 与 TheMuppets vendor blobs 最高只有
#     lineage-22.2。默认情况下本脚本会把"内核无 23.2 分支"作为阻塞项报告，
#     不掩盖已知缺口；只有显式加 --allow-22.2-pinned-deps 才按实验性 22.2 锁定方案放行。
#
# 状态：脚本语法已静态检查，并用假源码树做过 dry-run/阻塞路径自测；
#       尚未在真实构建主机执行（待验证）。
#
set -euo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_NAME

readonly DEFAULT_SOURCE_ROOT="${HOME}/android/lineage"
readonly KERNEL_PATH="kernel/xiaomi/sdm845"
readonly VENDOR_PATH="vendor/xiaomi/polaris"
readonly VENDOR_COMMON_PATH="vendor/xiaomi/sdm845-common"
readonly DEVICE_PATH="device/xiaomi/polaris"
readonly TERMINALOS_PATH="vendor/terminalos"
# 已核实的内核 22.2 分支 commit（用于识别"当前检出即 22.2"的证据之一）
readonly KERNEL_22_2_SHA="aa8adfe9bf212c6e93238a86980b4024da4f819a"

SOURCE_ROOT=""
TARGET_BRANCH="lineage-22.2"
ALLOW_PINNED_DEPS=false
DRY_RUN=false
blocking=0
pinned_warnings=0

log()  { printf '[%s] %s\n' "$SCRIPT_NAME" "$*"; }
warn() { printf '[%s] 警告：%s\n' "$SCRIPT_NAME" "$*" >&2; }
die()  { printf '[%s] 错误：%s\n' "$SCRIPT_NAME" "$*" >&2; exit 2; }

on_error() {
  local code=$?
  printf '[%s] 错误：命令失败（退出码 %s）：%s\n' \
    "$SCRIPT_NAME" "$code" "${BASH_COMMAND:-未知命令}" >&2
}
trap on_error ERR

usage() {
  cat <<'EOF'
用法：bash scripts/fetch-vendor-deps.sh [--source-root DIR] [--target-branch BRANCH]
                                       [--allow-22.2-pinned-deps] [--dry-run]

只读检查构建后置依赖：
  1) kernel/xiaomi/sdm845 是否存在目标分支（默认 lineage-22.2）
  2) vendor/xiaomi/polaris/BoardConfigVendor.mk 是否存在
  3) Termux APK 的获取提示（需执行 vendor/terminalos/scripts/fetch-termux.sh）

参数：
  --source-root DIR          源码根目录（默认当前目录含 .repo 时用当前目录，
                             否则 $HOME/android/lineage）
  --target-branch BRANCH     默认 lineage-22.2（可构建基线）；lineage-23.2 为实验目标
  --allow-22.2-pinned-deps   显式允许"内核无 23.2 分支，但 local manifest 已锁定
                             revision=lineage-22.2"的实验路径（缺失降级为警告）
  --dry-run                  只打印检查项，不实际读取
  -h, --help                 显示本帮助

默认行为：内核缺少 23.2 分支会打印
  "阻塞：需要内核分支或 local manifest 指定 revision=lineage-22.2"
并以非零码退出——这是已记录的上游缺口，不掩盖。
注意：本脚本不自动修改 manifest、不下载任何内容、不构建、不执行设备写入/刷机操作。
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
      --target-branch)
        [[ $# -ge 2 ]] || die "--target-branch 需要一个参数"
        TARGET_BRANCH="$2"
        shift 2
        ;;
      --allow-22.2-pinned-deps) ALLOW_PINNED_DEPS=true; shift ;;
      --dry-run) DRY_RUN=true; shift ;;
      -h|--help) usage; exit 0 ;;
      *) usage >&2; die "未知参数：$1" ;;
    esac
  done
}

validate_target_branch() {
  case "$TARGET_BRANCH" in
    lineage-23.2|lineage-22.2) ;;
    *)
      die "不支持的目标分支：${TARGET_BRANCH}。允许：lineage-22.2（默认，基线）或 lineage-23.2（实验）。"
      ;;
  esac
}

resolve_source_root() {
  if [[ -n $SOURCE_ROOT ]]; then
    [[ -d "$SOURCE_ROOT/.repo" ]] \
      || die "指定的源码目录未初始化：$SOURCE_ROOT/.repo 不存在（先执行 scripts/init-sources.sh 与 sync-sources.sh）。"
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
  log "源码根目录：$SOURCE_ROOT；目标分支：$TARGET_BRANCH"
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

head_sha() {
  local path=$1
  local sha=""
  sha="$(project_git "$path" rev-parse HEAD 2>/dev/null || true)"
  printf '%s' "$sha"
}

# 在 .repo/local_manifests/*.xml 中查找：同一个 <project> 块同时包含
# path="<want_path>" 与 revision="<want_revision>"
local_manifest_pins_path_revision() {
  local want_path=$1
  local want_revision=$2
  local dir="$SOURCE_ROOT/.repo/local_manifests"
  [[ -d $dir ]] || return 1
  local f
  for f in "$dir"/*.xml; do
    [[ -f $f ]] || continue
    if awk -v p="path=\"${want_path}\"" -v r="revision=\"${want_revision}\"" '
      /<project/ {
        in_block = 1
        block = $0 "\n"
        if ($0 ~ /\/>[[:space:]]*$/ || $0 ~ /<\/project>/) {
          if (index(block, p) && index(block, r)) { found = 1 }
          in_block = 0
        }
        next
      }
      in_block {
        block = block $0 "\n"
        if ($0 ~ /\/>[[:space:]]*$/ || $0 ~ /<\/project>/) {
          if (index(block, p) && index(block, r)) { found = 1 }
          in_block = 0
        }
      }
      END { exit(found ? 0 : 1) }
    ' "$f"; then
      return 0
    fi
  done
  return 1
}

kernel_has_branch() {
  local branches=""
  branches="$(project_git "$KERNEL_PATH" branch -a --format='%(refname:short)' 2>/dev/null || true)"
  if [[ -n $branches ]] && grep -Eq "(^|/)${TARGET_BRANCH//./\\.}$" <<<"$branches"; then
    return 0
  fi
  # 分支引用不存在时，用已核实的 22.2 commit 作为"当前检出即目标版本"的证据
  if [[ $TARGET_BRANCH == lineage-22.2 ]] && [[ "$(head_sha "$KERNEL_PATH")" == "$KERNEL_22_2_SHA" ]]; then
    return 0
  fi
  return 1
}

kernel_pinned_to_22_2() {
  if local_manifest_pins_path_revision "$KERNEL_PATH" "lineage-22.2"; then
    return 0
  fi
  if [[ "$(head_sha "$KERNEL_PATH")" == "$KERNEL_22_2_SHA" ]]; then
    return 0
  fi
  return 1
}

check_device_tree() {
  local line=""
  if [[ ! -d "$SOURCE_ROOT/$DEVICE_PATH" ]]; then
    warn "设备树不存在：${DEVICE_PATH}（repo sync 未完成或 local manifest 未生效）"
    return 0
  fi
  line="$(project_git "$DEVICE_PATH" log -1 --oneline 2>/dev/null || true)"
  log "设备树在位：${DEVICE_PATH}（HEAD: ${line:-未知}）"
}

check_kernel_branch() {
  if [[ ! -d "$SOURCE_ROOT/$KERNEL_PATH" ]]; then
    blocking=$((blocking + 1))
    printf '\n[阻塞] 内核源码目录不存在：%s\n' "$KERNEL_PATH"
    printf '  原因：repo sync 未完成，或 local manifest 未包含该内核项目。\n'
    printf '  处理：先执行 scripts/sync-sources.sh；本脚本不会自动修改 manifest。\n'
    return 0
  fi
  if kernel_has_branch; then
    local line=""
    line="$(project_git "$KERNEL_PATH" log -1 --oneline 2>/dev/null || true)"
    log "内核分支检查通过：${KERNEL_PATH} 存在 ${TARGET_BRANCH}（HEAD: ${line:-未知}）"
    return 0
  fi

  local pinned=false
  if kernel_pinned_to_22_2; then
    pinned=true
  fi
  if [[ $pinned == true ]] && [[ $ALLOW_PINNED_DEPS == true ]]; then
    pinned_warnings=$((pinned_warnings + 1))
    warn "已知缺口（非阻塞，按 --allow-22.2-pinned-deps 放行）：${KERNEL_PATH} 无 ${TARGET_BRANCH} 分支。"
    warn "  证据：local manifest 已指定 revision=lineage-22.2，或当前 HEAD 为 22.2 commit（${KERNEL_22_2_SHA}）。"
    warn "  风险：22.2 内核（Linux 4.9）+ 23.2 设备树的组合能否编译、能否启动、硬件是否完整，均未验证。"
    return 0
  fi

  blocking=$((blocking + 1))
  printf '\n[阻塞] 内核缺少目标分支：%s 中不存在 %s\n' "$KERNEL_PATH" "$TARGET_BRANCH"
  printf '阻塞：需要内核分支或 local manifest 指定 revision=lineage-22.2\n'
  local current=""
  current="$(project_git "$KERNEL_PATH" log -1 --oneline 2>/dev/null || true)"
  printf '  当前内核 HEAD：%s\n' "${current:-未知}"
  printf '  已知上游事实（2026-10-27 核实）：LineageOS/android_kernel_xiaomi_sdm845 没有\n'
  printf '  lineage-23.2 分支，最高为 lineage-22.2（aa8adfe9bf212c6e93238a86980b4024da4f819a）。\n'
  printf '  处理选项（均需 Lead 决策，脚本不自动执行）：\n'
  printf '    a) 等待/提交 Android 16 内核分支；\n'
  printf '    b) 在 local manifest 为内核项目指定 revision=lineage-22.2，并以实验方案继续\n'
  printf '       （确认后加 --allow-22.2-pinned-deps 重新运行本脚本）；\n'
  printf '    c) 自建内核分支并推送到自有仓库后在 manifest 指定 revision。\n'
  if [[ $pinned == true ]]; then
    printf '  补充：检测到 local manifest 已锁定 lineage-22.2；若要以该实验方案继续检查，\n'
    printf '        请加 --allow-22.2-pinned-deps 重新运行（本脚本不会自动改 manifest）。\n'
  fi
}

check_vendor_blobs() {
  local marker="$SOURCE_ROOT/$VENDOR_PATH/BoardConfigVendor.mk"
  if [[ -f $marker ]]; then
    log "vendor blobs 检查通过：${VENDOR_PATH}/BoardConfigVendor.mk 存在"
  else
    blocking=$((blocking + 1))
    printf '\n[阻塞] vendor blobs 缺失：%s/BoardConfigVendor.mk 不存在\n' "$VENDOR_PATH"
    printf '  已知上游事实（2026-10-27 核实）：TheMuppets/proprietary_vendor_xiaomi_polaris 与\n'
    printf '  TheMuppets/proprietary_vendor_xiaomi_sdm845-common 目前最高只有 lineage-22.2 分支。\n'
    printf '  处理选项（均需 Lead 决策，脚本不自动执行）：\n'
    printf '    a) 在 local manifest 为 vendor 项目指定可用 revision（例如 lineage-22.2）；\n'
    printf '    b) 等待 Android 16 vendor blobs 适配后再构建 23.2。\n'
  fi
  if [[ -d "$SOURCE_ROOT/$VENDOR_COMMON_PATH" ]]; then
    log "公共 vendor 目录在位：${VENDOR_COMMON_PATH}（仅供参考，未做强制校验）"
  else
    warn "公共 vendor 目录不存在：${VENDOR_COMMON_PATH}（sdm845-common 依赖可能不完整）"
  fi
}

check_termux_apk() {
  local prebuilt_dir="$SOURCE_ROOT/$TERMINALOS_PATH/prebuilt"
  local apk="$prebuilt_dir/Termux.apk"
  local sha="$prebuilt_dir/Termux.apk.sha256"
  if [[ -f $apk && -f $sha ]]; then
    log "Termux APK 与校验文件已存在：$apk（构建脚本会再次校验 sha256）"
    return 0
  fi
  printf '\n[提示] Termux APK 尚未就绪：%s\n' "$apk"
  printf '  需要执行 vendor/terminalos/scripts/fetch-termux.sh，生成 prebuilt/Termux.apk 与\n'
  printf '  prebuilt/Termux.apk.sha256。若源码树中找不到该脚本，请先确认 vendor/terminalos\n'
  printf '  已同步且包含 scripts/fetch-termux.sh。\n'
  printf '  说明：本项只提示，不计入本次阻塞统计；但 build-terminalos.sh 会强制校验，缺失即失败。\n'
}

print_summary() {
  printf '\n========== 依赖检查结论 ==========\n'
  printf '目标分支：%s\n' "$TARGET_BRANCH"
  if (( blocking > 0 )); then
    printf '阻塞项数量：%d\n' "$blocking"
    printf '结论：存在阻塞项，当前状态不能开始 %s 构建（这是已记录的上游缺口，不是本机错误）。\n' "$TARGET_BRANCH"
    printf '下一步：由 Lead 决策 local manifest revision 方案（22.2 基线 或 等待/自建 23.2 依赖），\n'
    printf '        再执行 scripts/init-sources.sh / sync-sources.sh 更新源码树。\n'
    exit 1
  fi
  if (( pinned_warnings > 0 )); then
    printf '降级为警告的已知缺口：%d 项（内核无 %s 分支，按 local manifest 锁定 lineage-22.2）\n' \
      "$pinned_warnings" "$TARGET_BRANCH"
    printf '结论：按"22.2 锁定"实验方案，依赖文件检查通过。\n'
    printf '重要：这不代表编译成功或可启动；23.2 并不存在官方设备支持，必须用基线构建与实机测试逐步验证。\n'
    printf '下一步：bash scripts/build-baseline.sh（先证明 22.2 基线）或 bash scripts/build-terminalos.sh（实验目标）。\n'
    return 0
  fi
  printf '结论：阻塞项检查通过。注意：这只说明依赖文件在位，不代表已经编译成功。\n'
  if [[ $TARGET_BRANCH == lineage-22.2 ]]; then
    printf '下一步：bash scripts/build-baseline.sh --source-root %s\n' "$SOURCE_ROOT"
  else
    printf '下一步：bash scripts/build-terminalos.sh --source-root %s\n' "$SOURCE_ROOT"
  fi
}

main() {
  parse_args "$@"
  validate_target_branch
  resolve_source_root
  log "开始只读检查（不下载、不修改 manifest、不构建）"
  if [[ $DRY_RUN == true ]]; then
    printf '  [检查项] 设备树：%s\n' "$DEVICE_PATH"
    printf '  [检查项] 内核分支：%s 是否存在 %s\n' "$KERNEL_PATH" "$TARGET_BRANCH"
    printf '  [检查项] vendor blobs：%s/BoardConfigVendor.mk\n' "$VENDOR_PATH"
    printf '  [检查项] Termux APK：%s/prebuilt/Termux.apk\n' "$TERMINALOS_PATH"
    printf '  [开关]    --allow-22.2-pinned-deps=%s\n' "$ALLOW_PINNED_DEPS"
    log "dry-run 结束：未实际读取仓库状态。"
    return 0
  fi
  check_device_tree
  check_kernel_branch
  check_vendor_blobs
  check_termux_apk
  print_summary
}

main "$@"
