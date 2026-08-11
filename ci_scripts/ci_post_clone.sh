#!/bin/bash
# ============================================================
# ci_post_clone.sh — Xcode Cloud: 克隆完成后执行
# ============================================================
# 此脚本在 Xcode Cloud 完成 Git 克隆后运行。
# ============================================================

set -euo pipefail

echo "==> [ci_post_clone] 开始执行..."

# --------------------------------------------------
# 1. 验证工作目录
# --------------------------------------------------
WORKSPACE_ROOT="$(pwd)"
echo "    工作目录: ${WORKSPACE_ROOT}"
echo "    Xcode 版本: $(xcodebuild -version 2>/dev/null | head -1)"
echo "    Swift 版本: $(swift --version 2>/dev/null | head -1)"

# --------------------------------------------------
# 2. BookletMaker 版本号注入（仅 booklet-v* tag 触发时）
# --------------------------------------------------
# 版本号源自 git tag（由 GitHub Actions 的 booklet-tag.yml 推上来），
# 不进 git 历史，仅在此刻改写 CI checkout 的工程副本。
# 脚本内部会判断 CI_TAG 前缀：非 booklet-v* 一律跳过，
# 因此 Lumi / AppIconDesigner 的 tag 触发构建不会被误改。
SET_VERSION_SCRIPT="$(pwd)/.github/scripts/set-booklet-version.sh"
if [[ -f "${SET_VERSION_SCRIPT}" ]]; then
    chmod +x "${SET_VERSION_SCRIPT}"
    "${SET_VERSION_SCRIPT}"
else
    echo "    WARNING: ${SET_VERSION_SCRIPT} 不存在，跳过 BookletMaker 版本注入"
fi

echo "==> [ci_post_clone] 完成,进入构建阶段."
