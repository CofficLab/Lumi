#!/bin/bash
# ============================================================
# ci_post_testflight.sh — Xcode Cloud: TestFlight 上传完成后执行
# ============================================================
# 此脚本在构建产物成功上传到 TestFlight 之后运行。
# 注意:仅在上传成功时触发;若上传失败,Xcode Cloud 会跳过此钩子。
# 用途:输出上传结果摘要、记录版本号/构建号、
#       输出后续阶段(TestFlight 内部处理)所需的信息。
#       仅做只读操作,不触发额外的网络请求或上传动作。
# ============================================================

set -euo pipefail

echo "==> [ci_post_testflight] 开始执行..."

# --------------------------------------------------
# 1. 验证工作目录
# --------------------------------------------------
WORKSPACE_ROOT="$(pwd)"
echo "    工作目录: ${WORKSPACE_ROOT}"

# --------------------------------------------------
# 2. 输出上传后的环境摘要
# --------------------------------------------------
echo "==> [ci_post_testflight] 上传结果摘要..."
echo "    Scheme:               ${SCHEME_NAME:-<未设置>}"
echo "    Configuration:        ${CONFIGURATION:-<未设置>}"
echo "    Product:              ${PRODUCT_NAME:-<未设置>}"
echo "    Build Number:         ${CI_BUILD_NUMBER:-<未设置>}"
echo "    Commit SHA:           ${CI_COMMIT:-<未设置>}"
echo "    Branch:               ${CI_BRANCH:-<未设置>}"
echo "    Xcode Version:        $(xcodebuild -version 2>/dev/null | head -1)"
echo "    时间戳:               $(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# --------------------------------------------------
# 3. 汇总本次构建关键信息(只读)
# --------------------------------------------------
echo "==> [ci_post_testflight] 构建汇总..."
# 路径约定：{Scheme}App/{Scheme}-Info.plist（5 个 app 通用）
SCHEME="${SCHEME_NAME:-}"
INFO_PLIST="${SCHEME}App/${SCHEME}-Info.plist"
if [[ -n "${SCHEME}" && -f "${INFO_PLIST}" ]]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        BUNDLE_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "${INFO_PLIST}" 2>/dev/null || echo "<未找到>")
        SHORT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${INFO_PLIST}" 2>/dev/null || echo "<未找到>")
    else
        BUNDLE_VERSION=$(grep -A1 "CFBundleVersion" "${INFO_PLIST}" | tail -1 | sed 's/.*>\(.*\)<.*/\1/' || echo "<未找到>")
        SHORT_VERSION=$(grep -A1 "CFBundleShortVersionString" "${INFO_PLIST}" | tail -1 | sed 's/.*>\(.*\)<.*/\1/' || echo "<未找到>")
    fi
    echo "    CFBundleVersion:              ${BUNDLE_VERSION}"
    echo "    CFBundleShortVersionString:   ${SHORT_VERSION}"
else
    echo "    Info.plist 未找到"
fi

# --------------------------------------------------
# 4. xcresult 路径回显(只读)
# --------------------------------------------------
echo "==> [ci_post_testflight] xcresult 位置..."
RESULT_PATH="${CI_RESULT_BUNDLE_PATH:-}"
if [[ -n "${RESULT_PATH}" && -d "${RESULT_PATH}" ]]; then
    echo "    xcresult 路径: ${RESULT_PATH}"
else
    echo "    xcresult 路径未提供或不存在"
fi

# --------------------------------------------------
# 5. 输出磁盘使用情况(只读)
# --------------------------------------------------
echo "==> [ci_post_testflight] 磁盘使用情况..."
df -h "${HOME}" 2>/dev/null | tail -n 1 || echo "    无法读取磁盘信息"

echo "==> [ci_post_testflight] 完成,TestFlight 后续处理中."