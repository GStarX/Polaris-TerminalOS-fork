#!/usr/bin/env bash
#
# verify-wiring.sh —— CI（sync-check）里的离线结构校验，不构建、不刷机。
#
# 由 .github/workflows/sync-check.yml 调用：
#   WORKSPACE          repo 同步后的源码根目录（含 device/ vendor/ kernel/ ...）
#   LINEAGE_BRANCH     目标分支（lineage-22.2 / lineage-23.2）
#   GITHUB_WORKSPACE   项目仓库检出目录（用于写报告 out/ci）
#
# 校验内容（全部为"文件存在 / 字符串契约"级，不做编译）：
#   1. 设备树产品配置注册与继承链
#   2. vendor/terminalos 产品片段、Termux presigned 预置契约
#   3. TerminalHome 模块名 / 包名 / HOME intent-filter 契约
#   4. 内核 polaris.config、vendor blobs BoardConfigVendor.mk
#   5. 分支相关的 overlay 资源差异（22.2 不得包含 23.2 才有的资源）
#   6. 仓库内脚本不得出现刷机命令（fastboot）
#
# 退出码：0 全部通过；1 存在失败项（报告仍会写出，供 artifact 上传）。
set -uo pipefail

: "${WORKSPACE:?需要 WORKSPACE 环境变量}"
: "${LINEAGE_BRANCH:?需要 LINEAGE_BRANCH 环境变量}"
: "${GITHUB_WORKSPACE:?需要 GITHUB_WORKSPACE 环境变量}"

REPORT_DIR="${GITHUB_WORKSPACE}/out/ci"
mkdir -p "${REPORT_DIR}"
REPORT="${REPORT_DIR}/wiring-report.txt"

failures=0
passes=0

report() { printf '%s\n' "$*" | tee -a "${REPORT}"; }
pass()   { passes=$((passes + 1)); report "PASS  $*"; }
fail()   { failures=$((failures + 1)); report "FAIL  $*"; }

check_file() {
    local path=$1
    if [[ -f "$path" ]]; then pass "file exists: ${path#${WORKSPACE}/}"; else fail "missing file: ${path}"; fi
}

check_contains() {
    local file=$1 pattern=$2 desc=$3
    if [[ ! -f "$file" ]]; then fail "cannot grep missing file: ${file}"; return; fi
    if grep -Eq "$pattern" "$file"; then pass "$desc"; else fail "$desc (pattern '${pattern}' not found in ${file#${WORKSPACE}/})"; fi
}

check_absent() {
    local file=$1 pattern=$2 desc=$3
    if [[ ! -f "$file" ]]; then fail "cannot grep missing file: ${file}"; return; fi
    if grep -Eq "$pattern" "$file"; then fail "$desc (unexpected pattern '${pattern}' in ${file#${WORKSPACE}/})"; else pass "$desc"; fi
}

: > "${REPORT}"
report "TerminalOS sync-check wiring report"
report "branch:  ${LINEAGE_BRANCH}"
report "date:    $(date -u +%Y-%m-%dT%H:%M:%SZ)"
report "commit:  $(git -C "${GITHUB_WORKSPACE}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
report "------------------------------------------------------------"

DEV="${WORKSPACE}/device/xiaomi/polaris"
VENDOR="${WORKSPACE}/vendor/terminalos"
APP="${WORKSPACE}/packages/apps/TerminalHome"
KERNEL="${WORKSPACE}/kernel/xiaomi/sdm845"
BLOBS="${WORKSPACE}/vendor/xiaomi/polaris"
COMMON_BLOBS="${WORKSPACE}/vendor/xiaomi/sdm845-common"

# --- 1. 设备树产品配置 ---
check_file "${DEV}/AndroidProducts.mk"
check_contains "${DEV}/AndroidProducts.mk" 'terminalos_polaris\.mk' "device tree registers terminalos_polaris.mk"
check_file "${DEV}/terminalos_polaris.mk"
check_contains "${DEV}/terminalos_polaris.mk" 'inherit-product, device/xiaomi/polaris/lineage_polaris\.mk' "product inherits lineage_polaris.mk"
check_contains "${DEV}/terminalos_polaris.mk" 'inherit-product, vendor/terminalos/terminalos\.mk' "product inherits vendor/terminalos/terminalos.mk"
check_contains "${DEV}/terminalos_polaris.mk" 'PRODUCT_NAME := terminalos_polaris' "PRODUCT_NAME is terminalos_polaris"

# --- 2. vendor/terminalos 契约 ---
check_file "${VENDOR}/terminalos.mk"
check_contains "${VENDOR}/terminalos.mk" 'TerminalHome' "product packages include TerminalHome"
check_contains "${VENDOR}/terminalos.mk" 'Termux' "product packages include Termux"
check_contains "${VENDOR}/terminalos.mk" 'PRODUCT_PACKAGE_OVERLAYS' "product uses static overlay"
check_file "${VENDOR}/Android.bp"
check_contains "${VENDOR}/Android.bp" 'android_app_import' "Termux imported as prebuilt app"
check_contains "${VENDOR}/Android.bp" 'presigned: *true' "Termux prebuilt is presigned (no re-signing)"
check_file "${VENDOR}/prebuilt/Termux.apk.sha256"

# --- 3. TerminalHome 契约 ---
check_file "${APP}/Android.bp"
check_contains "${APP}/Android.bp" 'name: *"TerminalHome"' "TerminalHome module name"
check_file "${APP}/AndroidManifest.xml"
check_contains "${APP}/AndroidManifest.xml" 'org\.terminalos\.terminalhome' "TerminalHome package name"
check_contains "${APP}/AndroidManifest.xml" 'android\.intent\.category\.HOME' "TerminalHome declares HOME category"
check_contains "${APP}/src/org/terminalos/terminalhome/TerminalOsConfig.java" 'com\.termux\.app\.TermuxActivity' "Termux launcher component pinned"

# --- 4. 内核 / blobs ---
check_file "${KERNEL}/arch/arm64/configs/vendor/xiaomi/polaris.config"
check_file "${BLOBS}/BoardConfigVendor.mk"
check_file "${COMMON_BLOBS}/BoardConfigVendor.mk"

# --- 5. 分支相关的 overlay 差异 ---
OVERLAY="${VENDOR}/overlay/frameworks/base/core/res/res/values/config.xml"
check_file "${OVERLAY}"
check_contains "${OVERLAY}" 'config_showNavigationBar' "overlay hides navigation bar"
if [[ "$LINEAGE_BRANCH" == "lineage-22.2" ]]; then
    check_absent "${OVERLAY}" '<string name="config_allowedSupervisionRolePackages"' "22.2 overlay does not use 23.2-only supervision resource"
else
    check_contains "${OVERLAY}" '<string name="config_allowedSupervisionRolePackages"' "23.2 overlay allows supervision role for TerminalHome"
fi

# --- 6. 禁止刷机命令 ---
for dir in "${DEV}" "${VENDOR}" "${APP}"; do
    if grep -RIn --include='*.sh' --include='*.xml' --include='*.mk' --include='*.bp' -E 'fastboot[[:space:]]+(flash|erase|update)' "$dir" >/dev/null 2>&1; then
        fail "flashing command found under $(basename "$dir")"
    else
        pass "no flashing commands under $(basename "$dir")"
    fi
done

# --- 各仓库版本 ---
report "------------------------------------------------------------"
report "repository revisions:"
for path in "device/xiaomi/polaris" "vendor/terminalos" "packages/apps/TerminalHome" "kernel/xiaomi/sdm845" "vendor/xiaomi/polaris" "vendor/xiaomi/sdm845-common"; do
    rev=$(git -C "${WORKSPACE}/${path}" log -1 --oneline 2>/dev/null || echo "NOT A GIT REPO")
    report "  ${path}: ${rev}"
done

report "------------------------------------------------------------"
report "RESULT: passes=${passes} failures=${failures}"

if (( failures > 0 )); then
    exit 1
fi
exit 0
