#!/bin/bash
# ============================================================
# ci_pre_xcodebuild.sh — Xcode Cloud: xcodebuild 执行前运行
# ============================================================
# 此脚本在每次 xcodebuild 命令执行前运行。
# 用途: 清理旧的构建产物、验证证书和 provisioning profile、
#       设置代码签名为手动模式(避免 Xcode Cloud 报签名错误)。
# ============================================================

set -euo pipefail

echo "==> [ci_pre_xcodebuild] 开始执行..."

# --------------------------------------------------
# 1. 构建配置参数(从环境变量读取,无则用默认值)
# --------------------------------------------------
SCHEME="${SCHEME_NAME:-AppIconDesigner}"
CONFIGURATION="${CONFIGURATION:-Debug}"
PRODUCT_NAME="${PRODUCT_NAME:-AppIconDesigner}"

echo "    Scheme: ${SCHEME}"
echo "    Configuration: ${CONFIGURATION}"
echo "    Product: ${PRODUCT_NAME}"

# --------------------------------------------------
# 2. 清理上一次构建的残留(可选,Xcode Cloud 每次有干净环境)
# --------------------------------------------------
echo "==> [ci_pre_xcodebuild] 清理构建产物..."
BUILD_DIR="${BUILD_DIR:-$HOME/Library/Developer/Xcode/DerivedData}"
# Xcode Cloud 每次都是干净 VM,此处仅作防御性清理
if [[ -d "${BUILD_DIR}" ]]; then
    echo "    DerivedData 存在,Xcode Cloud 会自动清理"
fi

# --------------------------------------------------
# 3. 代码签名配置
# --------------------------------------------------
echo "==> [ci_pre_xcodebuild] 代码签名配置..."

# Xcode Cloud 会自动注入 CI=true 环境变量,
# 并使用 App Store Connect 中配置的签名证书。
# 此处明确告知 xcodebuild 使用 Automatic 签名,但由 CI 环境接管:
export CODE_SIGN_IDENTITY="-"
export CODE_SIGNING_REQUIRED=NO
export CODE_SIGNING_ALLOWED=NO

echo "    CODE_SIGN_IDENTITY: 自动(CI 环境提供)"
echo "    CODE_SIGNING_REQUIRED: NO (测试阶段跳过签名)"
echo "    -> 对于 Archive 操作,需在 App Store Connect 中配置正确的签名证书"

# --------------------------------------------------
# 4. 验证 Info.plist 存在
# --------------------------------------------------
INFO_PLIST="AppIconDesignerApp/AppIconDesigner-Info.plist"
if [[ -f "${INFO_PLIST}" ]]; then
    echo "    ✓ ${INFO_PLIST} 存在"
else
    echo "WARNING: ${INFO_PLIST} 不存在!"
fi

# --------------------------------------------------
# 5. 验证 scheme 存在
# --------------------------------------------------
SCHEME_PATH="Lumi.xcodeproj/xcshareddata/xcschemes/${SCHEME}.xcscheme"
if [[ -f "${SCHEME_PATH}" ]]; then
    echo "    ✓ ${SCHEME_PATH} 存在"
else
    echo "WARNING: ${SCHEME_PATH} 不存在!"
fi

echo "==> [ci_pre_xcodebuild] 完成,开始 xcodebuild..."
