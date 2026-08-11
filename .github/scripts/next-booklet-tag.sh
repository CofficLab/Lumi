#!/bin/bash
#
# next-booklet-tag.sh - 根据 Conventional Commits 计算下一个 booklet-v* tag
#
# 只把 scope 属于 Bookletmaker 的 commit 纳入计算，支持的 scope 见 SCOPES。
#   feat(booklet): / fix(bookletmaker): / feat(bookletmakerapp)!: ...
#
# 递增规则：
#   - 含 (scope)! 的 breaking                                                    → major
#   - 含 feat(scope):                                                            → minor
#   - 其他（fix(scope): / chore(scope): 等任意支持的 scope）                       → patch
#
# 自上个 booklet tag 以来没有任何相关 commit 时：
#   退出码 1，stdout 无输出，供 workflow 判断"本次不打 tag"。
#
# 仓库里还没有 booklet-v* tag 时，从 booklet-v1.0.0 起步（仅当存在 booklet commit）。
#
# Usage:   next-booklet-tag.sh
# Output:  booklet-v1.2.3 (stdout)        成功
#          exit 1                          本次无 Bookletmaker 相关 commit，不打 tag
#          exit 2                          解析失败
#

set -euo pipefail

# Bookletmaker 相关的 scope 列表。新增产品线/别名只需改这里。
SCOPES="booklet bookletmaker bookletmakerapp"

# 把 scope 列表编译成 grep 扩展正则分支：booklet|bookletmaker|bookletmakerapp
SCOPE_RE=$(echo "$SCOPES" | tr ' ' '|')

# 完整匹配行：type(scope)!?: ...
# ERE 里 () 是分组，字面括号要写成 \( \)。内层再用一个分组 () 把分支括起来，
# 否则 | 最低优先级会把整行切成 3 段。
# 例：^[a-zA-Z]+\((booklet|bookletmaker)\)!?:
SCOPE_LINE_RE="^[a-zA-Z]+\\(($SCOPE_RE)\\)!?:"

# 拉取远端最新 tag，确保读到上一次本 workflow 推上去的 tag
git fetch --tags --force 2>/dev/null || true

# 取数值最大的 booklet-v* tag（与 commit 历史可达性无关）
LAST=$(git tag -l 'booklet-v*' --sort=-v:refname | head -n1 || true)

# 自上个 tag（或仓库起点）以来的全部 commit message
RANGE="${LAST:+${LAST}..}HEAD"
ALL_COMMITS=$(git log "$RANGE" --pretty=format:%s 2>/dev/null || echo "")

# 只保留 scope 属于 SCOPES 的 commit
BOOKLET_COMMITS=$(echo "$ALL_COMMITS" | grep -E "$SCOPE_LINE_RE" || true)

# 没有 booklet 相关 commit → 本次不打 tag
if [ -z "$BOOKLET_COMMITS" ]; then
  echo "No Bookletmaker commit ($SCOPES) since ${LAST:-start}; skipping tag." >&2
  exit 1
fi

# 仓库起步：第一个 booklet commit → booklet-v1.0.0
if [ -z "$LAST" ]; then
  echo "booklet-v1.0.0"
  echo "First Bookletmaker commit, starting at booklet-v1.0.0" >&2
  exit 0
fi

# 决定递增级别
if echo "$BOOKLET_COMMITS" | grep -qE "\\(($SCOPE_RE)\\)!:"; then
  INC="major"
elif echo "$BOOKLET_COMMITS" | grep -qE "^feat\\(($SCOPE_RE)\\):"; then
  INC="minor"
else
  INC="patch"
fi

VER="${LAST#booklet-v}"
IFS='.' read -r MAJOR MINOR PATCH <<< "$VER"
MAJOR=${MAJOR:-0}
MINOR=${MINOR:-0}
PATCH=${PATCH:-0}

case "$INC" in
  major) NEXT="booklet-v$((MAJOR + 1)).0.0" ;;
  minor) NEXT="booklet-v${MAJOR}.$((MINOR + 1)).0" ;;
  patch) NEXT="booklet-v${MAJOR}.${MINOR}.$((PATCH + 1))" ;;
esac

echo "Base:       $LAST"            >&2
echo "Increment:  $INC"             >&2
echo "Booklet commits:"             >&2
echo "$BOOKLET_COMMITS" | sed 's/^/  - /' >&2

echo "$NEXT"
