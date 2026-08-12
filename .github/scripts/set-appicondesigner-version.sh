#!/bin/bash
#
# set-appicondesigner-version.sh — 把 AppIconDesigner 的版本号写进工程文件
#
# 设计要点：
#   1. 版本号来源是 git tag（由 GitHub Actions 的 appicondesigner-tag.yml 推上来），
#      通过 Xcode Cloud 注入的 CI_TAG 环境变量读取，格式 appicondesigner-v1.2.3。
#      版本号不进 git 历史，只改 CI 临时 checkout 的工程副本。
#   2. 单工程多 app 结构（共用一个 Lumi.xcodeproj），因此不能用 agvtool
#      new-marketing-version（会同时改所有 target）。这里精确改 AppIconDesigner
#      的 xcconfig。
#   3. MARKETING_VERSION = tag 解析出的语义版本（如 1.2.3）。
#      CURRENT_PROJECT_VERSION = CI 构建号（CI_BUILD_NUMBER），保证同版本
#      下 TestFlight build 号单调递增（App Store Connect 硬性要求）。
#
# Usage: set-appicondesigner-version.sh
#   依赖环境变量：
#     CI_TAG          Xcode Cloud 注入的触发 tag（appicondesigner-v1.2.3）
#     CI_BUILD_NUMBER Xcode Cloud 构建号（用于 CURRENT_PROJECT_VERSION）
#   可以从任意工作目录执行。
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# -----------------------------------------------------------------------------
# 1. 解析版本号
# -----------------------------------------------------------------------------
TAG="${CI_TAG:-}"
if [ -z "$TAG" ]; then
  echo "==> [set-appicondesigner-version] CI_TAG 未设置，跳过版本写入（非 tag 触发的构建）。"
  exit 0
fi

# 只认 appicondesigner-v* 前缀的 tag；其他 tag 直接跳过，
# 避免在其他 app 发版时误改 AppIconDesigner 版本。
case "$TAG" in
  appicondesigner-v*) ;;
  *)
    echo "==> [set-appicondesigner-version] CI_TAG='$TAG' 不是 appicondesigner-v*，跳过。"
    exit 0
    ;;
esac

VERSION="${TAG#appicondesigner-v}"
# 校验是 x.y.z 形式，防止脏 tag 写进工程文件
if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "==> [set-appicondesigner-version] 错误：'$TAG' 解析出的版本 '$VERSION' 不是 x.y.z" >&2
  exit 1
fi

BUILD_NUMBER="${CI_BUILD_NUMBER:-}"
if ! echo "$BUILD_NUMBER" | grep -qE '^[1-9][0-9]*$'; then
  echo "==> [set-appicondesigner-version] 错误：CI_BUILD_NUMBER='$BUILD_NUMBER' 不是正整数" >&2
  exit 1
fi

echo "==> [set-appicondesigner-version] 写入 AppIconDesigner 版本"
echo "    tag:              $TAG"
echo "    MARKETING_VERSION → $VERSION"
echo "    CURRENT_PROJECT_VERSION → $BUILD_NUMBER"

# -----------------------------------------------------------------------------
# 2. 写入 AppIconDesigner 的 xcconfig
#
# build settings 已从 project.pbxproj 迁移到 Config/AppIconDesigner.xcconfig。
# Debug/Release 共用这一个文件（两者配置一致），
# 所以改这一个文件即可同时覆盖两个 configuration。
# -----------------------------------------------------------------------------
XCCONFIG="${REPOSITORY_ROOT}/Config/AppIconDesigner.xcconfig"
if [ ! -f "$XCCONFIG" ]; then
  echo "==> [set-appicondesigner-version] 错误：找不到 $XCCONFIG" >&2
  exit 1
fi

sed -i '' "s/^MARKETING_VERSION = .*/MARKETING_VERSION = $VERSION/" "$XCCONFIG"
sed -i '' "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $BUILD_NUMBER/" "$XCCONFIG"

# -----------------------------------------------------------------------------
# 3. 校验
# -----------------------------------------------------------------------------
if ! grep -q "^MARKETING_VERSION = $VERSION$" "$XCCONFIG"; then
  echo "==> [set-appicondesigner-version] 错误：MARKETING_VERSION 未写入 $XCCONFIG" >&2
  exit 1
fi
if ! grep -q "^CURRENT_PROJECT_VERSION = $BUILD_NUMBER$" "$XCCONFIG"; then
  echo "==> [set-appicondesigner-version] 错误：CURRENT_PROJECT_VERSION 未写入 $XCCONFIG" >&2
  exit 1
fi

echo "==> [set-appicondesigner-version] 完成，已更新 Config/AppIconDesigner.xcconfig"
