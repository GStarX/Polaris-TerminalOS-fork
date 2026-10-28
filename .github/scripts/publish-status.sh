#!/usr/bin/env bash
#
# publish-status.sh —— 把 CI 结果写回仓库的 ci-status 分支，便于在没有 GitHub UI
# 访问权限的场合（例如从其他工具）核对"云端到底跑没跑、结果如何"。
#
# 由 workflow 调用（push 权限由 workflow 的 permissions: contents: write 提供）。
#
# 环境变量：
#   GITHUB_WORKSPACE / GITHUB_REPOSITORY / GITHUB_TOKEN  GitHub Actions 内置
#   JOB_KIND      sync-check | build-rom
#   JOB_STATUS    success | failure | cancelled
#   JOB_DETAIL    JSON 字符串（由 workflow 组装，例如 {"branch":"lineage-22.2",...}）
#
# 行为：
#   - 在 ci-status 分支写 runs/<UTC 时间戳>-<job_kind>.json（只追加，不修改历史）；
#   - 若 ci-status 分支不存在则创建 orphan 分支；
#   - 任何失败只打印错误并 exit 0，绝不让"写状态"把整个 CI 变成失败。
set -uo pipefail

# 状态写入是"锦上添花"：缺 token 时只警告，不得让 CI 失败
if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    echo 'WARN: GITHUB_TOKEN 未注入，跳过 ci-status 写入（检查 workflow 的 env 与 permissions）'
    exit 0
fi

: "${GITHUB_REPOSITORY:?}"
: "${JOB_KIND:=unknown}"
: "${JOB_STATUS:=unknown}"
: "${JOB_DETAIL:={}}"

work_dir=$(mktemp -d)
trap 'rm -rf "${work_dir}"' EXIT

token_url="https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"

if git clone --quiet --depth 1 --branch ci-status "${token_url}" "${work_dir}/status" 2>/dev/null; then
    echo "ci-status 分支已存在，追加记录"
else
    echo "ci-status 分支不存在，创建 orphan 分支"
    if ! git clone --quiet --depth 1 "${token_url}" "${work_dir}/status" 2>/dev/null; then
        echo "ERROR: clone 仓库失败，跳过状态写入"
        exit 0
    fi
    cd "${work_dir}/status"
    git checkout --orphan ci-status >/dev/null 2>&1 || true
    git rm -rf . >/dev/null 2>&1 || true
fi

cd "${work_dir}/status"
git config user.name "TerminalOS CI"
git config user.email "ci@users.noreply.github.com"

mkdir -p runs
stamp=$(date -u +%Y%m%dT%H%M%SZ)
file="runs/${stamp}-${JOB_KIND}.json"

cat > "${file}" <<JSON
{
  "kind": "${JOB_KIND}",
  "status": "${JOB_STATUS}",
  "timestamp": "${stamp}",
  "repository": "${GITHUB_REPOSITORY}",
  "run_id": "${GITHUB_RUN_ID:-}",
  "run_url": "${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID:-}",
  "ref": "${GITHUB_REF:-}",
  "sha": "${GITHUB_SHA:-}",
  "detail": ${JOB_DETAIL}
}
JSON

git add "${file}"
git commit -q -m "ci: ${JOB_KIND} ${JOB_STATUS} (${stamp})" || true
if git push --quiet origin HEAD:ci-status; then
    echo "status written: ${file}"
else
    echo "ERROR: push ci-status 失败（权限或分支保护），已忽略"
fi
exit 0
