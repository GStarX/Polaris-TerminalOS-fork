#!/usr/bin/env bash
#
# setup-build-host.sh — 在 Ubuntu LTS 构建主机上安装 LineageOS / TerminalOS 构建依赖
#
# 用途：
#   1) 安装 LineageOS 官方构建文档列出的 apt 依赖；
#   2) 配置 ccache 上限为 50G；
#   3) 安装 repo 工具到 ~/bin；
#   4) 初始化 git-lfs；
#   5) 设置 git trailer.changeid.key = Change-Id。
#
# 用法：
#   bash scripts/setup-build-host.sh [--dry-run] [--yes]
#
# 参数：
#   --dry-run    只打印将要执行的命令，不做任何修改（可在任意机器上预检）
#   --yes, -y    跳过 sudo 前的交互确认（默认每条 sudo 命令都会先打印再询问）
#   -h, --help   显示本帮助
#
# 安全说明：
#   * 本脚本只修改构建主机（apt 软件包、~/.gitconfig、~/bin/repo、ccache 配置），
#     不下载 Android 源码、不编译 ROM、不执行任何设备写入/刷机操作。
#   * 幂等：重复执行不会重复安装已安装的包，也不会重复写入相同配置。
#   * 不静默 sudo：每条 sudo 命令先完整打印，再由用户确认后才执行。
#   * 资源低于官方建议（LineageOS 21+：64 GB RAM / 400 GB 磁盘）时只警告，不阻止。
#
# 参考：LineageOS 官方构建文档（building_basics）与 polaris 构建说明。
# 状态：脚本语法已做静态检查；尚未在真实 Ubuntu 构建主机上执行（待验证）。
#
set -euo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_NAME

DRY_RUN=false
ASSUME_YES=false

readonly CCACHE_MAX_SIZE="50G"
readonly REPO_URL="https://storage.googleapis.com/git-repo-downloads/repo"
readonly GIT_CHANGEID_KEY="Change-Id"
readonly RECOMMENDED_RAM_GB=64
readonly RECOMMENDED_DISK_GB=400

# LineageOS 官方构建文档（building_basics）列出的依赖包
readonly -a APT_PACKAGES=(
  bc
  bison
  build-essential
  ccache
  curl
  erofs-utils
  flex
  g++-multilib
  gcc-multilib
  git
  git-lfs
  gnupg
  gperf
  imagemagick
  kmod
  protobuf-compiler
  python3-protobuf
  lib32readline-dev
  lib32z1-dev
  libdw-dev
  libelf-dev
  libgnutls28-dev
  lz4
  libsdl1.2-dev
  libssl-dev
  libxml2
  libxml2-utils
  lzop
  pngcrush
  rsync
  schedtool
  squashfs-tools
  xsltproc
  xxd
  zip
  zlib1g-dev
)

# ---------------------------------------------------------------------------
# 通用输出与错误处理
# ---------------------------------------------------------------------------
log()  { printf '[%s] %s\n' "$SCRIPT_NAME" "$*"; }
warn() { printf '[%s] 警告：%s\n' "$SCRIPT_NAME" "$*" >&2; }
die()  { printf '[%s] 错误：%s\n' "$SCRIPT_NAME" "$*" >&2; exit 1; }

on_error() {
  local code=$?
  printf '[%s] 错误：命令失败（退出码 %s）：%s\n' \
    "$SCRIPT_NAME" "$code" "${BASH_COMMAND:-未知命令}" >&2
  printf '[%s] 提示：修复后重新执行本脚本即可（脚本幂等）。\n' "$SCRIPT_NAME" >&2
}
trap on_error ERR

usage() {
  cat <<'EOF'
用法：bash scripts/setup-build-host.sh [--dry-run] [--yes]

在 Ubuntu LTS 构建主机上安装并配置 LineageOS / TerminalOS 构建依赖：
  * apt 依赖（LineageOS 官方构建文档列表）
  * ccache 上限 50G
  * repo 工具（安装到 ~/bin）
  * git-lfs 初始化
  * git trailer.changeid.key = Change-Id

参数：
  --dry-run    只打印将要执行的命令，不做任何修改
  --yes, -y    跳过 sudo 前的交互确认
  -h, --help   显示本帮助

注意：
  * 需要普通用户 + sudo 权限；不要整段脚本用 root 执行。
  * 本脚本不下载源码、不构建、不执行任何设备写入/刷机操作。
  * 重复执行是安全的（幂等）。
EOF
}

# ---------------------------------------------------------------------------
# 命令执行封装（--dry-run 时只打印）
# ---------------------------------------------------------------------------
run() {
  printf '  + %s\n' "$*"
  if [[ $DRY_RUN == true ]]; then
    return 0
  fi
  "$@"
}

confirm() {
  local prompt=$1
  if [[ $ASSUME_YES == true ]]; then
    log "已通过 --yes 跳过确认：${prompt}"
    return 0
  fi
  if [[ ! -t 0 ]]; then
    die "当前不是交互终端，无法确认 sudo 操作；请直接运行并确认，或显式加 --yes。"
  fi
  local answer=""
  read -r -p "${prompt} [y/N] " answer || true
  case "$answer" in
    y|Y|yes|YES|Yes) return 0 ;;
    *) die "用户取消：未执行后续 sudo 操作。" ;;
  esac
}

# 先打印完整命令，再确认，最后才 sudo（不静默执行）
run_sudo() {
  printf '  [将执行] sudo %s\n' "$*"
  if [[ $DRY_RUN == true ]]; then
    return 0
  fi
  confirm "以上 sudo 命令会修改构建主机系统，确认执行？"
  sudo "$@"
}

# ---------------------------------------------------------------------------
# 环境检查
# ---------------------------------------------------------------------------
detect_distro() {
  local distro_id="unknown"
  local distro_ver="unknown"
  if [[ -r /etc/os-release ]]; then
    set +u
    # shellcheck disable=SC1091
    . /etc/os-release
    set -u
    distro_id="${ID:-unknown}"
    distro_ver="${VERSION_ID:-unknown}"
  fi
  if [[ $distro_id != ubuntu ]]; then
    warn "检测到非 Ubuntu 系统（ID=${distro_id}，VERSION=${distro_ver}）。"
    warn "apt 包名与安装方式可能与 Ubuntu 不同；请人工确认后再继续。"
  else
    log "系统：Ubuntu ${distro_ver}"
  fi
}

check_resources() {
  local ram_gb="未知"
  local disk_gb="未知"
  if [[ -r /proc/meminfo ]]; then
    ram_gb="$(awk '/^MemTotal:/ {printf "%d", $2/1024/1024}' /proc/meminfo 2>/dev/null || true)"
    [[ -n $ram_gb ]] || ram_gb="未知"
  fi
  if command -v df >/dev/null 2>&1; then
    disk_gb="$(df -BG --output=avail "$HOME" 2>/dev/null | tail -n 1 | tr -dc '0-9' || true)"
    [[ -n $disk_gb ]] || disk_gb="未知"
  fi
  log "内存：${ram_gb} GB；\$HOME 可用磁盘：${disk_gb} GB"
  if [[ $ram_gb =~ ^[0-9]+$ ]]; then
    if (( ram_gb < RECOMMENDED_RAM_GB )); then
      warn "内存 ${ram_gb} GB 低于 LineageOS 21+ 官方建议的 ${RECOMMENDED_RAM_GB} GB，"
      warn "完整编译可能 OOM（可加 swap/zram，但不保证成功）。"
    fi
  fi
  if [[ $disk_gb =~ ^[0-9]+$ ]]; then
    if (( disk_gb < RECOMMENDED_DISK_GB )); then
      warn "可用磁盘 ${disk_gb} GB 低于官方建议的 ${RECOMMENDED_DISK_GB} GB。"
    fi
  fi
}

check_environment() {
  local kernel_name
  kernel_name="$(uname -s)"
  if [[ $kernel_name != Linux ]]; then
    die "本脚本只能在 Linux（Ubuntu）构建主机上执行，当前系统：${kernel_name}。"
  fi
  detect_distro
  if ! command -v apt-get >/dev/null 2>&1; then
    die "未找到 apt-get：本脚本只支持 Debian / Ubuntu 系构建主机。"
  fi
  if [[ $EUID -eq 0 ]]; then
    warn "检测到以 root 用户执行；建议使用普通用户，由脚本按需调用 sudo。"
  fi
  local arch
  arch="$(uname -m)"
  if [[ $arch != x86_64 ]]; then
    warn "CPU 架构为 ${arch}，不是 x86_64；LineageOS/Android 构建官方仅支持 x86_64。"
  fi
  check_resources
}

# ---------------------------------------------------------------------------
# apt 依赖
# ---------------------------------------------------------------------------
missing_packages() {
  local pkg
  local -a missing=()
  if ! command -v dpkg-query >/dev/null 2>&1; then
    # 无法查询时按"全部缺失"处理，由 apt 自己判断（并在非 Debian 系上给出错误）
    printf '%s\n' "${APT_PACKAGES[@]}"
    return 0
  fi
  for pkg in "${APT_PACKAGES[@]}"; do
    if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'install ok installed'; then
      missing+=("$pkg")
    fi
  done
  if (( ${#missing[@]} > 0 )); then
    printf '%s\n' "${missing[@]}"
  fi
}

install_packages() {
  local -a missing=()
  mapfile -t missing < <(missing_packages)
  if (( ${#missing[@]} == 0 )); then
    log "apt 依赖均已安装，跳过 apt-get install。"
    return 0
  fi
  log "缺少 ${#missing[@]} 个 apt 包：${missing[*]}"
  run_sudo env DEBIAN_FRONTEND=noninteractive apt-get update
  run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing[@]}"
}

# ---------------------------------------------------------------------------
# ccache
# ---------------------------------------------------------------------------
configure_ccache() {
  if [[ $DRY_RUN == true ]] && ! command -v ccache >/dev/null 2>&1; then
    log "ccache 尚未安装（dry-run）；计划设置上限为 ${CCACHE_MAX_SIZE}。"
    run ccache --max-size="$CCACHE_MAX_SIZE"
    return 0
  fi
  command -v ccache >/dev/null 2>&1 \
    || die "未找到 ccache（apt 安装可能未完成），无法设置缓存上限。"
  run ccache --max-size="$CCACHE_MAX_SIZE"
  if [[ $DRY_RUN == false ]]; then
    log "ccache 上限已设置为 ${CCACHE_MAX_SIZE}（重复执行结果相同，幂等）。"
  fi
}

# ---------------------------------------------------------------------------
# repo 工具
# ---------------------------------------------------------------------------
install_repo_tool() {
  local bin_dir="$HOME/bin"
  local repo_bin="$bin_dir/repo"
  if [[ -x $repo_bin ]]; then
    log "repo 工具已存在：$repo_bin（跳过下载）。"
  elif [[ $DRY_RUN == true ]]; then
    printf '  + mkdir -p %s\n' "$bin_dir"
    printf '  + curl -fsSL %s -o %s\n' "$REPO_URL" "$repo_bin"
    printf '  + chmod +x %s\n' "$repo_bin"
  else
    mkdir -p "$bin_dir"
    log "下载 repo 工具到 $repo_bin"
    if ! curl -fsSL "$REPO_URL" -o "$repo_bin"; then
      die "下载 repo 工具失败（网络不通或 URL 变更）：${REPO_URL}"
    fi
    [[ -s $repo_bin ]] || die "repo 工具文件为空：$repo_bin"
    chmod +x "$repo_bin"
    log "repo 工具安装完成：$repo_bin"
  fi
  case ":$PATH:" in
    *":$bin_dir:"*)
      log "$bin_dir 已在 PATH 中。"
      ;;
    *)
      warn "$bin_dir 不在 PATH 中；请在 ~/.bashrc 追加下面一行（本脚本不自动修改 shell 配置）："
      warn "  export PATH=\"\$HOME/bin:\$PATH\""
      ;;
  esac
}

# ---------------------------------------------------------------------------
# git-lfs 与 Change-Id trailer
# ---------------------------------------------------------------------------
configure_git_lfs() {
  if [[ $DRY_RUN == true ]] && ! command -v git-lfs >/dev/null 2>&1; then
    log "git-lfs 尚未安装（dry-run）；计划执行 git lfs install。"
    run git lfs install
    return 0
  fi
  command -v git-lfs >/dev/null 2>&1 \
    || die "未找到 git-lfs（apt 安装可能未完成）。"
  run git lfs install
  if [[ $DRY_RUN == false ]]; then
    log "git-lfs 已初始化：$(git lfs version 2>/dev/null || echo '版本未知')"
  fi
}

configure_git_changeid() {
  local current=""
  current="$(git config --global --get trailer.changeid.key 2>/dev/null || true)"
  if [[ $current == "$GIT_CHANGEID_KEY" ]]; then
    log "git trailer.changeid.key 已为 ${GIT_CHANGEID_KEY}，跳过。"
    return 0
  fi
  run git config --global trailer.changeid.key "$GIT_CHANGEID_KEY"
}

# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) DRY_RUN=true; shift ;;
      --yes|-y)  ASSUME_YES=true; shift ;;
      -h|--help) usage; exit 0 ;;
      *) usage >&2; die "未知参数：$1" ;;
    esac
  done
}

main() {
  parse_args "$@"
  log "构建主机依赖安装开始（dry-run=${DRY_RUN}）"
  check_environment
  install_packages
  configure_ccache
  install_repo_tool
  configure_git_lfs
  configure_git_changeid
  if [[ $DRY_RUN == true ]]; then
    log "dry-run 结束：以上命令均未真正执行。"
  else
    log "完成。下一步：bash scripts/init-sources.sh"
  fi
  log "本脚本未执行任何设备写入/刷机操作。"
}

main "$@"
