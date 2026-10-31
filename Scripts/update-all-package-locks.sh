#!/bin/bash
# 刷新所有含远程依赖的 Package 的 Package.resolved
ROOT="/Users/angel/Code/Coffic/Lumi"
OUT="$ROOT/.update-logs"
mkdir -p "$OUT"
rm -f "$OUT"/*.log "$OUT"/*.rc "$OUT"/FAILED.txt "$OUT"/pkgs.txt

cd "$ROOT/Packages" || exit 1
for f in */Package.swift; do
  grep -q "github.com" "$f" && echo "${f%/Package.swift}"
done | sort -u > "$OUT/pkgs.txt"

TOTAL=$(wc -l < "$OUT/pkgs.txt" | tr -d ' ')
echo "共 $TOTAL 个含远程依赖的包，并发 6 更新"

xargs -P 6 -I{} sh -c '
  p="$1"; out="$2"; root="$3"
  cd "$root/Packages/$p" 2>/dev/null || { echo "NO_DIR" > "$out/$p.log"; echo 98 > "$out/$p.rc"; exit; }
  swift package update > "$out/$p.log" 2>&1
  echo $? > "$out/$p.rc"
' _ {} "$OUT" "$ROOT" < "$OUT/pkgs.txt"

: > "$OUT/FAILED.txt"
while read -r p; do
  rc=$(cat "$OUT/$p.rc" 2>/dev/null || echo 99)
  [ "$rc" = "0" ] || echo "$p (rc=$rc)" >> "$OUT/FAILED.txt"
done < "$OUT/pkgs.txt"

PASSED=$((TOTAL - $(wc -l < "$OUT/FAILED.txt" | tr -d ' ')))
FAILED=$(wc -l < "$OUT/FAILED.txt" | tr -d ' ')
echo "===== 更新汇总 ====="
echo "总计: $TOTAL  成功: $PASSED  失败: $FAILED"
[ "$FAILED" != "0" ] && cat "$OUT/FAILED.txt"
exit 0
