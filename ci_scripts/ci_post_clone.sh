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

echo "==> [ci_post_clone] 完成,进入构建阶段."
