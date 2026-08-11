#!/bin/bash
#
# set-booklet-version.sh — 把 BookletMaker 的版本号写进工程文件
#
# 设计要点：
#   1. 版本号来源是 git tag（由 GitHub Actions 的 booklet-tag.yml 推上来），
#      通过 Xcode Cloud 注入的 CI_TAG 环境变量读取，格式 booklet-v1.2.3。
#      版本号不进 git 历史，只改 CI 临时 checkout 的工程副本。
#   2. 单工程多 app 结构（Lumi / BookletMaker / AppIconDesigner 共用一个
#      Lumi.xcodeproj），因此不能用 agvtool new-marketing-version（它会
#      同时改所有 target，污染 Lumi 的 5.8.4 等版本）。这里用 awk 精确
#      定位 BookletMaker 的 build config block（ID 前缀 BM），只改这两个。
#   3. MARKETING_VERSION = tag 解析出的语义版本（如 1.2.3）。
#      CURRENT_PROJECT_VERSION = CI 构建号（CI_BUILD_NUMBER），保证同版本
#      下 TestFlight build 号单调递增（App Store Connect 硬性要求）。
#
# Usage: set-booklet-version.sh
#   依赖环境变量：
#     CI_TAG          Xcode Cloud 注入的触发 tag（booklet-v1.2.3）
#     CI_BUILD_NUMBER Xcode Cloud 构建号（用于 CURRENT_PROJECT_VERSION）
#   在仓库根目录执行。
#

set -euo pipefail

# -----------------------------------------------------------------------------
# 1. 解析版本号
# -----------------------------------------------------------------------------
TAG="${CI_TAG:-}"
if [ -z "$TAG" ]; then
  echo "==> [set-booklet-version] CI_TAG 未设置，跳过版本写入（非 tag 触发的构建）。"
  exit 0
fi

# 只认 booklet-v* 前缀的 tag；其他 tag（如 Lumi 的 v5.8.4）直接跳过，
# 避免在 Lumi 发版时误改 BookletMaker 版本。
case "$TAG" in
  booklet-v*) ;;
  *)
    echo "==> [set-booklet-version] CI_TAG='$TAG' 不是 booklet-v*，跳过。"
    exit 0
    ;;
esac

VERSION="${TAG#booklet-v}"
# 校验是 x.y.z 形式，防止脏 tag 写进工程文件
if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "==> [set-booklet-version] 错误：'$TAG' 解析出的版本 '$VERSION' 不是 x.y.z" >&2
  exit 1
fi

BUILD_NUMBER="${CI_BUILD_NUMBER:-1}"

PBXPROJ="Lumi.xcodeproj/project.pbxproj"
if [ ! -f "$PBXPROJ" ]; then
  echo "==> [set-booklet-version] 错误：找不到 $PBXPROJ" >&2
  exit 1
fi

echo "==> [set-booklet-version] 写入 BookletMaker 版本"
echo "    tag:              $TAG"
echo "    MARKETING_VERSION → $VERSION"
echo "    CURRENT_PROJECT_VERSION → $BUILD_NUMBER"

# -----------------------------------------------------------------------------
# 2. 精确改 BookletMaker 的 build config（ID 前缀 BM）
#
# project.pbxproj 里每个 build config 形如：
#     BM000000000000000000000D /* Debug */ = {
#         isa = XCBuildConfiguration;
#         buildSettings = {
#             ...
#             MARKETING_VERSION = 1.0.0;
#             CURRENT_PROJECT_VERSION = 1;
#             ...
#         };
#         name = Debug;
#     };
#
# 策略：用状态机遍历。进入 ID 以 "BM" 开头的 config block 时打开开关，
# 退出 block（行首 "};\n\t\t};"）时关闭。仅在开关打开期间替换两行。
# 这样 Lumi (LU)、AppIconDesigner (AI) 等其他 target 完全不被触碰。
# -----------------------------------------------------------------------------
STATE="outside"          # outside | in-booklet
BM_LINES_CHANGED=0

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

awk -v mv="$VERSION" -v cpv="$BUILD_NUMBER" '
  # 进入一个 build config block：行匹配 /^\t\t<24位ID> \/\* (Debug|Release) \*\/ = {/
  /^\t\t[A-Z0-9]{24} \/\* (Debug|Release) \*\/ = \{/ {
    if (substr($0, 3, 2) == "BM") {
      state = "in-booklet"
    } else {
      state = "in-other"
    }
    print
    next
  }
  # block 结束：单独成行的 };
  state == "in-booklet" && /^\t\t\};$/ {
    state = "outside"
    print
    next
  }
  # block 内：替换版本字段（仅 BookletMaker）
  state == "in-booklet" && /^\t\t\t\tMARKETING_VERSION = / {
    printf "\t\t\t\tMARKETING_VERSION = %s;\n", mv
    next
  }
  state == "in-booklet" && /^\t\t\t\tCURRENT_PROJECT_VERSION = / {
    printf "\t\t\t\tCURRENT_PROJECT_VERSION = %s;\n", cpv
    next
  }
  { print }
' "$PBXPROJ" > "$TMP"

# -----------------------------------------------------------------------------
# 3. 落盘 + 校验改动命中数
# -----------------------------------------------------------------------------
# BookletMaker 有 Debug + Release 两个 config，每个改 2 行 → 期望 4 处变动
# 注意：diff 有差异时退出码是 1，配合 set -euo pipefail 会让管道失败、
# 触发 || CHANGED=0，导致计数永远为 0。用 || true 吞掉 diff 的退出码。
DIFF_OUT=$(diff "$PBXPROJ" "$TMP" || true)
CHANGED=$(echo "$DIFF_OUT" | grep -cE '^[<>]')
# diff 每处改动产生一对 < 和 > 行，4 处 = 8 行 diff
if [ "$CHANGED" -ne 8 ]; then
  echo "==> [set-booklet-version] 警告：期望改 4 处（8 行 diff），实际 diff 行数=$CHANGED" >&2
  echo "    可能是 BookletMaker 的 build config 结构有变，请检查脚本。" >&2
  echo "$DIFF_OUT" | head -30 >&2
  exit 1
fi

mv "$TMP" "$PBXPROJ"
trap - EXIT

echo "==> [set-booklet-version] 完成，已改 $((CHANGED / 2)) 处。"
