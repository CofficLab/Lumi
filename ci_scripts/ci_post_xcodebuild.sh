#!/bin/bash
# ============================================================
# ci_post_xcodebuild.sh — Xcode Cloud: xcodebuild 完成后执行
# ============================================================
# 此脚本在每次 xcodebuild 命令执行完毕后运行。
# 注意:此钩子在每次 xcodebuild 后都会触发(包括失败时),
#       不能依赖 BUILD_SUCCEEDED 来判断阶段成败,请使用 exit code。
# 用途:输出构建结果摘要、定位产物路径、收集环境信息。
#       仅做只读操作,不修改任何文件、不触发额外构建。
# ============================================================

set -euo pipefail

echo "==> [ci_post_xcodebuild] 开始执行..."

# --------------------------------------------------
# 1. 验证工作目录
# --------------------------------------------------
WORKSPACE_ROOT="$(pwd)"
echo "    工作目录: ${WORKSPACE_ROOT}"

# --------------------------------------------------
# 2. 输出构建环境摘要
# --------------------------------------------------
echo "==> [ci_post_xcodebuild] 构建环境摘要..."
echo "    Scheme:               ${SCHEME_NAME:-<未设置>}"
echo "    Configuration:        ${CONFIGURATION:-<未设置>}"
echo "    Product:              ${PRODUCT_NAME:-<未设置>}"
echo "    Action:               ${XCODEBUILD_ACTION:-<未设置>}"
echo "    Build Number:         ${CI_BUILD_NUMBER:-<未设置>}"
echo "    Commit SHA:           ${CI_COMMIT:-<未设置>}"
echo "    Branch:               ${CI_BRANCH:-<未设置>}"
echo "    Xcode Version:        $(xcodebuild -version 2>/dev/null | head -1)"
echo "    Swift Version:        $(swift --version 2>/dev/null | head -1)"
echo "    macOS Version:        $(sw_vers -productVersion 2>/dev/null || echo '<未知>')"
echo "    Architecture:         $(uname -m)"

# --------------------------------------------------
# 3. 输出构建结果
# --------------------------------------------------
echo "==> [ci_post_xcodebuild] 构建结果..."
if [[ "${XCODEBUILD_ACTION:-}" == "test" ]]; then
    echo "    阶段类型: 测试"
elif [[ "${XCODEBUILD_ACTION:-}" == "archive" ]]; then
    echo "    阶段类型: 归档 (Archive)"
elif [[ "${XCODEBUILD_ACTION:-}" == "build" ]]; then
    echo "    阶段类型: 编译"
else
    echo "    阶段类型: <未识别: ${XCODEBUILD_ACTION:-}>"
fi

# 注: Xcode Cloud 在构建失败时也会调用此脚本,
# 此时 BUILD_DIR 中可能没有产物,这里只探测不报错。
BUILD_DIR="${BUILD_DIR:-$HOME/Library/Developer/Xcode/DerivedData}"
if [[ -d "${BUILD_DIR}" ]]; then
    echo "    DerivedData 存在: ${BUILD_DIR}"
    # 只统计 .app / .xcarchive 等产物数量,不深入遍历
    APP_COUNT=$(find "${BUILD_DIR}" -maxdepth 6 -name "*.app" -type d 2>/dev/null | wc -l | tr -d ' ')
    ARCHIVE_COUNT=$(find "${BUILD_DIR}" -maxdepth 6 -name "*.xcarchive" -type d 2>/dev/null | wc -l | tr -d ' ')
    echo "    发现 .app 产物:     ${APP_COUNT} 个"
    echo "    发现 .xcarchive:    ${ARCHIVE_COUNT} 个"
else
    echo "    DerivedData 不存在 (构建可能失败或被清理)"
fi

# --------------------------------------------------
# 4. 输出 xcresult bundle 路径(只读探测)
# --------------------------------------------------
echo "==> [ci_post_xcodebuild] xcresult 定位..."
RESULT_PATH="${CI_RESULT_BUNDLE_PATH:-}"
if [[ -n "${RESULT_PATH}" && -d "${RESULT_PATH}" ]]; then
    echo "    xcresult 路径: ${RESULT_PATH}"
    # 仅打印顶层元信息,不解析内容
    if [[ -f "${RESULT_PATH}/Info.plist" ]]; then
        echo "    Info.plist 存在,可用于后续导出日志"
    fi
else
    echo "    xcresult 路径未提供或不存在 (Xcode Cloud 会自动归档)"
fi

# --------------------------------------------------
# 5. 输出磁盘使用情况(只读)
# --------------------------------------------------
echo "==> [ci_post_xcodebuild] 磁盘使用情况..."
df -h "${HOME}" 2>/dev/null | tail -n 1 || echo "    无法读取磁盘信息"

echo "==> [ci_post_xcodebuild] 完成,等待下一阶段."