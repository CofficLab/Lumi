#!/bin/bash
# ============================================================
# ci_post_clone.sh — Xcode Cloud: 克隆完成后执行
# ============================================================
# 此脚本在 Xcode Cloud 完成 Git 克隆后运行。
# ============================================================

set -euo pipefail

echo "==> [ci_post_clone] 开始执行..."

# --------------------------------------------------
# 1. 定位仓库根目录
# --------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
echo "    脚本目录: ${SCRIPT_DIR}"
echo "    仓库根目录: ${WORKSPACE_ROOT}"
echo "    Xcode 版本: $(xcodebuild -version 2>/dev/null | head -1)"
echo "    Swift 版本: $(swift --version 2>/dev/null | head -1)"

# --------------------------------------------------
# 2. 版本号注入（按 CI_TAG 前缀分发到对应 app）
# --------------------------------------------------
# 版本号源自 git tag（由 GitHub Actions 的 *-tag.yml 推上来），
# 不进 git 历史，仅在此刻改写 CI checkout 的工程副本。
# 每个 app 一个 set-*-version.sh，内部会校验 CI_TAG 前缀：
# 非自己前缀的一律跳过，因此多 app 共用 ci_scripts 不会互相干扰。
SCRIPTS_DIR="${WORKSPACE_ROOT}/.github/scripts"
SET_VERSION_SCRIPT=""
case "${CI_TAG:-}" in
    booklet-v*)         SET_VERSION_SCRIPT="${SCRIPTS_DIR}/set-booklet-version.sh" ;;
    appicondesigner-v*) SET_VERSION_SCRIPT="${SCRIPTS_DIR}/set-appicondesigner-version.sh" ;;
    caddesigner-v*)     SET_VERSION_SCRIPT="${SCRIPTS_DIR}/set-caddesigner-version.sh" ;;
    databasemanager-v*) SET_VERSION_SCRIPT="${SCRIPTS_DIR}/set-databasemanager-version.sh" ;;
    *) echo "    CI_TAG='${CI_TAG:-<未设置>}' 非已知 app tag 前缀，跳过版本注入。" ;;
esac

if [[ -n "${SET_VERSION_SCRIPT}" ]]; then
    if [[ ! -f "${SET_VERSION_SCRIPT}" ]]; then
        echo "    ERROR: 版本注入脚本不存在: ${SET_VERSION_SCRIPT}" >&2
        exit 1
    fi

    "${SET_VERSION_SCRIPT}"
fi

echo "==> [ci_post_clone] 完成,进入构建阶段."
