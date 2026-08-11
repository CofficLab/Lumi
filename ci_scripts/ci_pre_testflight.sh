#!/bin/bash
# ============================================================
# ci_pre_testflight.sh — Xcode Cloud: 上传 TestFlight 前执行
# ============================================================
# 此脚本在将构建产物上传到 TestFlight 之前运行。
# 用途:输出上传前的环境摘要、校验版本号/构建号、
#       检查 metadata 与上传所需文件是否就绪。
#       仅做只读操作,不触发实际的上传动作。
# ============================================================

set -euo pipefail

echo "==> [ci_pre_testflight] 开始执行..."

# --------------------------------------------------
# 1. 验证工作目录
# --------------------------------------------------
WORKSPACE_ROOT="$(pwd)"
echo "    工作目录: ${WORKSPACE_ROOT}"

# --------------------------------------------------
# 2. 输出 TestFlight 上传环境
# --------------------------------------------------
echo "==> [ci_pre_testflight] 上传环境摘要..."
echo "    Scheme:               ${SCHEME_NAME:-<未设置>}"
echo "    Configuration:        ${CONFIGURATION:-<未设置>}"
echo "    Product:              ${PRODUCT_NAME:-<未设置>}"
echo "    Build Number:         ${CI_BUILD_NUMBER:-<未设置>}"
echo "    Commit SHA:           ${CI_COMMIT:-<未设置>}"
echo "    Branch:               ${CI_BRANCH:-<未设置>}"
echo "    Xcode Version:        $(xcodebuild -version 2>/dev/null | head -1)"

# --------------------------------------------------
# 3. 定位 archive 产物(只读探测)
# --------------------------------------------------
echo "==> [ci_pre_testflight] Archive 产物定位..."
BUILD_DIR="${BUILD_DIR:-$HOME/Library/Developer/Xcode/DerivedData}"
if [[ -d "${BUILD_DIR}" ]]; then
    # 仅输出最近一次 archive 的路径,不解析内部结构
    LATEST_ARCHIVE=$(find "${BUILD_DIR}" -maxdepth 6 -name "*.xcarchive" -type d -newer "${BUILD_DIR}" 2>/dev/null | sort | tail -n 1 || true)
    if [[ -n "${LATEST_ARCHIVE}" ]]; then
        echo "    最近 archive: ${LATEST_ARCHIVE}"
        echo "    archive 大小: $(du -sh "${LATEST_ARCHIVE}" 2>/dev/null | awk '{print $1}')"
    else
        echo "    未发现 .xcarchive (Xcode Cloud 会由 altool 自动处理)"
    fi
else
    echo "    DerivedData 不存在"
fi

# --------------------------------------------------
# 4. 校验 Info.plist 中的版本号(只读)
# --------------------------------------------------
echo "==> [ci_pre_testflight] 版本信息校验..."
INFO_PLIST="AppIconDesignerApp/AppIconDesigner-Info.plist"
if [[ -f "${INFO_PLIST}" ]]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        BUNDLE_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "${INFO_PLIST}" 2>/dev/null || echo "<未找到>")
        SHORT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${INFO_PLIST}" 2>/dev/null || echo "<未找到>")
    else
        # Linux CI 上没有 PlistBuddy,使用 grep 兜底
        BUNDLE_VERSION=$(grep -A1 "CFBundleVersion" "${INFO_PLIST}" | tail -1 | sed 's/.*>\(.*\)<.*/\1/' || echo "<未找到>")
        SHORT_VERSION=$(grep -A1 "CFBundleShortVersionString" "${INFO_PLIST}" | tail -1 | sed 's/.*>\(.*\)<.*/\1/' || echo "<未找到>")
    fi
    echo "    CFBundleVersion:              ${BUNDLE_VERSION}"
    echo "    CFBundleShortVersionString:   ${SHORT_VERSION}"
    echo "    CI_BUILD_NUMBER(预期匹配):    ${CI_BUILD_NUMBER:-<未设置>}"
else
    echo "WARNING: ${INFO_PLIST} 不存在"
fi

# --------------------------------------------------
# 5. 检查上传所需凭据(只读,只探测是否存在)
# --------------------------------------------------
echo "==> [ci_pre_testflight] 凭据探测..."
if [[ -n "${APP_STORE_CONNECT_API_KEY_PATH:-}" && -f "${APP_STORE_CONNECT_API_KEY_PATH}" ]]; then
    echo "    App Store Connect API Key: 已配置"
else
    echo "    App Store Connect API Key: 未配置 (Xcode Cloud 自动注入)"
fi

echo "==> [ci_pre_testflight] 完成,即将上传到 TestFlight."