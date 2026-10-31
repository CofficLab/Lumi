#!/bin/bash
# 并行运行 Packages/ 下所有包的单元测试，汇总失败项
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/.test-logs"
mkdir -p "$OUT"
rm -f "$OUT"/*.log "$OUT"/*.rc "$OUT"/FAILED.txt "$OUT"/summary.txt

cd "$ROOT/Packages" || exit 1
ls -d */Tests 2>/dev/null | sed 's#/Tests##' | sort -u > "$OUT/pkgs.txt"
TOTAL=$(wc -l < "$OUT/pkgs.txt" | tr -d ' ')
echo "共 $TOTAL 个包待测试，并发 8"

xargs -P 8 -I{} sh -c '
  p="$1"
  out="$2"
  cd "$3/Packages/$p" 2>/dev/null || { echo "NO_DIR" > "$out/$p.log"; echo 98 > "$out/$p.rc"; exit; }
  swift test > "$out/$p.log" 2>&1
  echo $? > "$out/$p.rc"
' _ {} "$OUT" "$ROOT" < "$OUT/pkgs.txt"

: > "$OUT/FAILED.txt"
for p in $(cat "$OUT/pkgs.txt"); do
  rc=$(cat "$OUT/$p.rc" 2>/dev/null || echo 99)
  [ "$rc" = "0" ] || echo "$p (rc=$rc)" >> "$OUT/FAILED.txt"
done
PASSED=$((TOTAL - $(wc -l < "$OUT/FAILED.txt" | tr -d ' ')))
FAILED=$(wc -l < "$OUT/FAILED.txt" | tr -d ' ')

{
  echo "===== 测试汇总 ====="
  echo "总包数: $TOTAL / 通过: $PASSED / 失败: $FAILED"
  echo ""
  echo "----- 失败列表 -----"
  cat "$OUT/FAILED.txt"
} > "$OUT/summary.txt"

cat "$OUT/summary.txt"
