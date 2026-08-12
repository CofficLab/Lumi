#!/bin/bash
#
# next-appicondesigner-tag.sh - 根据 Conventional Commits 计算下一个 appicondesigner-v* tag
#
# 只把 scope 属于 AppIconDesigner 的 commit 纳入计算，支持的 scope 见 SCOPES。
#   feat(appicondesigner): / fix(appicondesignerapp): / feat(appicondesignerapp)!: ...
#
# 递增规则：
#   - 含 (scope)! 的 breaking                                                    → major
#   - 含 feat(scope):                                                            → minor
#   - 其他（fix(scope): / chore(scope): 等任意支持的 scope）                       → patch
#
# 自上个 appicondesigner tag 以来没有任何相关 commit 时：
#   退出码 1，stdout 无输出，供 workflow 判断"本次不打 tag"。
#
# 仓库里还没有 appicondesigner-v* tag 时，从 appicondesigner-v1.0.0 起步（仅当存在相关 commit）。
#
# Usage:   next-appicondesigner-tag.sh
# Output:  appicondesigner-v1.2.3 (stdout)        成功
#          exit 1                                  本次无 AppIconDesigner 相关 commit，不打 tag
#          exit 2                                  解析失败
#

set -euo pipefail

# AppIconDesigner 相关的 scope 列表。新增别名只需改这里。
SCOPES="appicondesigner appicondesignerapp"

# 把 scope 列表编译成 grep 扩展正则分支：appicondesigner|appicondesignerapp
SCOPE_RE=$(echo "$SCOPES" | tr ' ' '|')

# 完整匹配行：type(scope)!?: ...
SCOPE_LINE_RE="^[a-zA-Z]+\\(($SCOPE_RE)\\)!?:"

# 拉取远端最新 tag，确保读到上一次本 workflow 推上去的 tag
git fetch --tags --force 2>/dev/null || true

# 取数值最大的 appicondesigner-v* tag（与 commit 历史可达性无关）
LAST=$(git tag -l 'appicondesigner-v*' --sort=-v:refname | head -n1 || true)

# 自上个 tag（或仓库起点）以来的全部 commit message
RANGE="${LAST:+${LAST}..}HEAD"
ALL_COMMITS=$(git log "$RANGE" --pretty=format:%s 2>/dev/null || echo "")

# 只保留 scope 属于 SCOPES 的 commit
APP_COMMITS=$(echo "$ALL_COMMITS" | grep -E "$SCOPE_LINE_RE" || true)

# 没有相关 commit → 本次不打 tag
if [ -z "$APP_COMMITS" ]; then
  echo "No AppIconDesigner commit ($SCOPES) since ${LAST:-start}; skipping tag." >&2
  exit 1
fi

# 仓库起步：第一个 commit → appicondesigner-v1.0.0
if [ -z "$LAST" ]; then
  echo "appicondesigner-v1.0.0"
  echo "First AppIconDesigner commit, starting at appicondesigner-v1.0.0" >&2
  exit 0
fi

# 决定递增级别
if echo "$APP_COMMITS" | grep -qE "\\(($SCOPE_RE)\\)!:"; then
  INC="major"
elif echo "$APP_COMMITS" | grep -qE "^feat\\(($SCOPE_RE)\\):"; then
  INC="minor"
else
  INC="patch"
fi

VER="${LAST#appicondesigner-v}"
IFS='.' read -r MAJOR MINOR PATCH <<< "$VER"
MAJOR=${MAJOR:-0}
MINOR=${MINOR:-0}
PATCH=${PATCH:-0}

case "$INC" in
  major) NEXT="appicondesigner-v$((MAJOR + 1)).0.0" ;;
  minor) NEXT="appicondesigner-v${MAJOR}.$((MINOR + 1)).0" ;;
  patch) NEXT="appicondesigner-v${MAJOR}.${MINOR}.$((PATCH + 1))" ;;
esac

echo "Base:       $LAST"            >&2
echo "Increment:  $INC"             >&2
echo "AppIconDesigner commits:"     >&2
echo "$APP_COMMITS" | sed 's/^/  - /' >&2

echo "$NEXT"
