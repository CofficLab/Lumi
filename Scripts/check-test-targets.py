#!/usr/bin/env python3
"""体检：检测 Packages 下各包测试目标能否编译。

生成 TestPlan 前必须知道用例是否真能跑——否则覆盖率是编造的。
逐包执行 `swift build --build-tests`，把结果归类为：
  ok       编译通过
  broken   编译失败（测试引用了不存在的类型等）
  skip     非本包自身的编译错误（如依赖包先挂），需复查

用法:
    python3 Scripts/check-test-targets.py            # 全量体检
    python3 Scripts/check-test-targets.py KitShell    # 指定包
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACKAGES = os.path.join(ROOT, "Packages")
REPORT = os.path.join(ROOT, "Scripts", "test-target-health.json")

ERROR_RE = r'^(?P<file>[^\s:]+\.swift):(?P<line>\d+):\d+: error: (?P<msg>.*)$'


def packages_with_tests():
    return sorted(
        name for name in os.listdir(PACKAGES)
        if os.path.isdir(os.path.join(PACKAGES, name, "Tests"))
    )


def has_testplan(name):
    return os.path.isfile(os.path.join(PACKAGES, name, "Tests", "TestPlan.md"))


def strip_ansi(text):
    import re
    return re.sub(r'\x1b\[[0-9;]*m', '', text)


def check(name):
    """返回 (status, [错误摘要])。"""
    cwd = os.path.join(PACKAGES, name)
    try:
        proc = subprocess.run(
            ["swift", "build", "--build-tests"],
            cwd=cwd, capture_output=True, text=True, timeout=1800,
        )
    except subprocess.TimeoutExpired:
        return "timeout", []

    output = strip_ansi(proc.stdout + proc.stderr)
    if proc.returncode == 0:
        return "ok", []

    errors = []
    for line in output.splitlines():
        if "error:" not in line:
            continue
        cleaned = line.strip()
        # 只记录本包自身 Tests/Sources 的错误，过滤依赖包的报错
        if f"Packages/{name}/" in cleaned or cleaned.startswith("error:"):
            errors.append(cleaned[:220])

    return ("broken" if errors else "skip"), errors[:12]


def main():
    args = sys.argv[1:]
    names = args or packages_with_tests()

    results = {}
    if os.path.isfile(REPORT):
        with open(REPORT, encoding="utf-8") as handle:
            results = json.load(handle)

    for index, name in enumerate(names, 1):
        if not args and name in results:
            continue
        print(f"[{index}/{len(names)}] {name} ...", flush=True)
        status, errors = check(name)
        results[name] = {
            "status": status,
            "errors": errors,
            "hasTestPlan": has_testplan(name),
        }

    with open(REPORT, "w", encoding="utf-8") as handle:
        json.dump(results, handle, ensure_ascii=False, indent=2)

    summary = {}
    for value in results.values():
        summary[value["status"]] = summary.get(value["status"], 0) + 1

    print(f"\n共 {len(results)} 个包")
    for status, count in sorted(summary.items()):
        print(f"  {status}: {count}")

    broken = [k for k, v in results.items() if v["status"] == "broken"]
    if broken:
        print(f"\n破损包（{len(broken)}）:")
        for name in broken:
            first = results[name]["errors"][0] if results[name]["errors"] else ""
            print(f"  - {name}: {first[:150]}")


if __name__ == "__main__":
    main()
