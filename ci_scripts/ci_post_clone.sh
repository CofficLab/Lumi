#!/bin/bash
# ============================================================
# ci_post_clone.sh — Xcode Cloud: 克隆完成后执行
# ============================================================
# 此脚本在 Xcode Cloud 完成 Git 克隆后运行。
# 用途: 安装 Swift 依赖(如有)、设置 SPM package 缓存、
#       验证必要的文件和目录结构是否存在。
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
# 2. 验证项目文件存在
# --------------------------------------------------
if [[ ! -d "Lumi.xcodeproj" ]]; then
    echo "ERROR: Lumi.xcodeproj 不存在!"
    exit 1
fi
echo "    ✓ Lumi.xcodeproj 存在"

if [[ ! -d "AppIconDesignerApp" ]]; then
    echo "ERROR: AppIconDesignerApp 目录不存在!"
    exit 1
fi
echo "    ✓ AppIconDesignerApp 目录存在"

if [[ ! -d "Plugins/AppIconDesignerPlugin" ]]; then
    echo "ERROR: Plugins/AppIconDesignerPlugin 不存在!"
    exit 1
fi
echo "    ✓ Plugins/AppIconDesignerPlugin 存在"

# --------------------------------------------------
# 3. 解析并解析 SPM 依赖(Xcode Cloud 自动处理,但可做预检)
# --------------------------------------------------
echo "==> [ci_post_clone] 解析 Swift Package Manager 依赖..."
# xcodebuild -resolvePackageDependencies 已在 Xcode Cloud 中自动执行,
# 此处仅做可选的额外验证:
if [[ -f "Lumi.xcodeproj/project.xcworkspace/../../Packages" ]] || \
   [[ -d ".swiftpm" ]]; then
    echo "    ✓ Swift Package 配置目录存在"
else
    echo "    (未发现额外的 SPM 配置目录,跳过)"
fi

# --------------------------------------------------
# 4. 确保 Plugins 模块已正确配置(Xcode Cloud 会自动 resolve)
# --------------------------------------------------
echo "==> [ci_post_clone] 完成,进入构建阶段."
