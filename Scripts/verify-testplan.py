#!/usr/bin/env python3
"""校验 TestPlan.md 与实际测试代码是否一致。

检查项:
  1. 用例表格的 ID 连续无缺号
  2. 覆盖率统计中的 P0/P1/P2 数字与表格实际行数一致
  3. 表格「测试方法」列的方法名与源码 @Test 函数名双向匹配
  4. 单元格内的竖线已转义（未转义的 `|` 会多切出一列，导致列错位）

用法:
    python3 Scripts/verify-testplan.py            # 校验全部包
    python3 Scripts/verify-testplan.py KitShell   # 校验指定包
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACKAGES = os.path.join(ROOT, "Packages")
EXTRACTOR = os.path.join(ROOT, "Scripts", "extract-testplan-metadata.py")

ROW_RE = re.compile(r'^\|\s*(\d+)\s*\|')
BACKTICK_RE = re.compile(r'`([^`]+)`')
IDENT_RE = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*$')
PRIORITIES = ("P0", "P1", "P2")
# 行首与行尾的 | 各切出一个空单元格：9 个内容列 + 2 个空格 = 11
EXPECTED_COLUMNS = 11

# 表格切分后的列下标：行首 '|' 会切出一个空首格
COL_PRIORITY = 7
COL_METHODS = 9


def split_row(line):
    """按未转义的 | 切分，忽略 \\| 转义。"""
    return [cell.strip() for cell in re.split(r'(?<!\\)\|', line)]


def load_meta():
    """复用提取脚本结果，避免两处解析逻辑漂移。"""
    out = subprocess.run(
        [sys.executable, EXTRACTOR, "--all"],
        capture_output=True, text=True, check=True,
    )
    return {x["name"]: x for x in json.loads(out.stdout)}


def parse_plan(plan_path):
    """返回 (rows, problems)；rows 为 [{id, prio, funcs}]。"""
    with open(plan_path, encoding="utf-8") as handle:
        lines = handle.read().splitlines()

    rows = []
    problems = []
    for line in lines:
        match = ROW_RE.match(line)
        if not match:
            continue
        cells = split_row(line)
        if len(cells) != EXPECTED_COLUMNS:
            # 列数不对几乎总是因为单元格里有未转义的竖线
            problems.append(
                f"ID {match.group(1)} 切出 {len(cells)} 列（应为 {EXPECTED_COLUMNS}）"
                f"—— 单元格内的 `|` 必须写成 `\\|`"
            )
            continue
        # 方法列常见 `` `a`、`b` `` 形式（顿号分隔多个方法名），
        # 反引号配对可能跨单元格边界，故先按未转义竖号切分，
        # 再取「方法列及其右侧」的反引号标识符，避免混入前几列的 API 名。
        tail = re.split(r'(?<!\\)\|', line)[COL_METHODS:]
        funcs = [
            token
            for cell in tail
            for token in BACKTICK_RE.findall(cell)
            if IDENT_RE.match(token)
        ]
        rows.append({
            "id": int(match.group(1)),
            "prio": cells[COL_PRIORITY],
            "funcs": funcs,
        })

    return rows, problems


def check_package(name, meta):
    """返回问题列表，空列表表示通过。"""
    plan_path = os.path.join(PACKAGES, name, "Tests", "TestPlan.md")
    if not os.path.isfile(plan_path):
        return [f"{name}: 缺少 Tests/TestPlan.md"]

    rows, problems = parse_plan(plan_path)
    if not rows:
        return [f"{name}: 未找到可解析的用例表格行"] + [
            f"{name}: {p}" for p in problems
        ]

    problems = [f"{name}: {p}" for p in problems]

    ids = [row["id"] for row in rows]
    if ids != list(range(1, len(ids) + 1)):
        problems.append(
            f"{name}: ID 不连续（{ids[0]}..{ids[-1]}，共 {len(ids)} 行）"
        )

    counts = {}
    for row in rows:
        if row["prio"] not in PRIORITIES:
            problems.append(
                f"{name}: ID {row['id']} 优先级列异常 -> {row['prio']!r}"
            )
            continue
        counts[row["prio"]] = counts.get(row["prio"], 0) + 1

    with open(plan_path, encoding="utf-8") as handle:
        lines = handle.read().splitlines()

    for prio, count in counts.items():
        pattern = rf'{prio}:\s*已覆盖\s*(\d+)\s*/\s*(\d+)'
        matched = False
        for line in lines:
            found = re.search(pattern, line)
            if not found:
                continue
            matched = True
            done, total = int(found.group(1)), int(found.group(2))
            if done != count or total != count:
                problems.append(
                    f"{name}: 统计「{prio}: 已覆盖 {done} / {total}」"
                    f"与表格实际 {count} 不符"
                )
        if not matched:
            problems.append(f"{name}: 覆盖率统计缺少 {prio} 行")

    if not any(re.search(r'\*\*合计:\s*\d+\s*/\s*\d+\*\*', line) for line in lines):
        problems.append(f"{name}: 覆盖率统计缺少合计行")

    entry = meta.get(name)
    if entry:
        plan_funcs = {f for row in rows for f in row["funcs"]}
        code_funcs = {t["func"] for t in entry["tests"] if t["func"]}

        only_plan = sorted(plan_funcs - code_funcs)
        only_code = sorted(code_funcs - plan_funcs)

        if only_plan:
            problems.append(
                f"{name}: {len(only_plan)} 个登记方法在源码不存在 -> {only_plan[:5]}"
            )
        if only_code:
            problems.append(
                f"{name}: {len(only_code)} 个源码用例未登记 -> {only_code[:5]}"
            )

    return problems


def main():
    args = sys.argv[1:]
    meta = load_meta()
    names = args or sorted(meta)

    problems = []
    checked = 0
    for name in names:
        if not os.path.isfile(os.path.join(PACKAGES, name, "Tests", "TestPlan.md")):
            continue
        checked += 1
        problems.extend(check_package(name, meta))

    print(f"已校验 {checked} 份 TestPlan.md")
    if problems:
        print(f"\n发现 {len(problems)} 个问题：\n")
        for problem in problems:
            print(f"  - {problem}")
        sys.exit(1)
    print("全部通过 ✅")


if __name__ == "__main__":
    main()
