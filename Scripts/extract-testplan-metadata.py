#!/usr/bin/env python3
"""提取 Packages 下各包测试元数据，为生成 TestPlan.md 提供素材。

用法:
    python3 Scripts/extract-testplan-metadata.py KitLLM KitMarkdown
    python3 Scripts/extract-testplan-metadata.py --all     # 全部包，输出 JSON
    python3 Scripts/extract-testplan-metadata.py --missing # 只列缺 TestPlan.md 的包名
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACKAGES = os.path.join(ROOT, "Packages")

# 顶层自由函数：@Test [("显示名")] [其他属性...] func name(...) {
ATTR_TEST_INLINE_RE = re.compile(
    r'^\s*@Test\b(?:\s*\(\s*"([^"]*)"\s*\))?'
    r'(?:[\s,]*@\w+(?:\([^)]*\))?)*'
    r'\s*func\s+(\w+)\s*(?:<[^>]*>)?\s*\('
)
# @Test 起始行（struct 内写法，或参数化测试的起始）。捕获显示名。
ATTR_TEST_START_RE = re.compile(r'^\s*@Test\b\s*(?:\(\s*"([^"]*)"\s*)?')
# 仅确认是 @Test 起始行（本行不以 func 结尾）
ATTR_TEST_ONLY_RE = re.compile(r'^\s*@Test\b')
DECL_RE = re.compile(
    r'^\s*(?:@\w+(?:\([^)]*\))?\s+)*'
    r'(?:public\s+|internal\s+|private\s+|fileprivate\s+|static\s+|final\s+|mutating\s+)*'
    r'func\s+(\w+)\s*(?:<[^>]*>)?\s*\('
)
TYPE_RE = re.compile(
    r'^\s*(?:public\s+|internal\s+|private\s+|final\s+)*'
    r'(?:struct|class|enum|extension|actor)\s+(\w+)'
)
ATTR_SUITE_LINE_RE = re.compile(r'^\s*@Suite\b\s*(?:\(\s*(?:"([^"]*)")?\s*\))?\s*$')
XCTest_FUNC_RE = re.compile(r'^\s*func\s+(test\w*)\s*\(')


def platform_of(pkg_dir):
    """从 Package.swift 抓 platforms 声明。"""
    manifest = os.path.join(pkg_dir, "Package.swift")
    if not os.path.isfile(manifest):
        return ""
    with open(manifest, encoding="utf-8") as handle:
        text = handle.read()
    found = re.findall(r'\.(macOS|iOS|tvOS|watchOS)\s*:\s*"([\d.]+)"', text)
    return ", ".join(f"{name} {ver}+" for name, ver in found)


def readme_head(pkg_dir, limit=700):
    readme = os.path.join(pkg_dir, "README.md")
    if not os.path.isfile(readme):
        return ""
    with open(readme, encoding="utf-8") as handle:
        text = handle.read()
    text = re.sub(r'^---\n.*?\n---\n', '', text, flags=re.S)
    return re.sub(r'\s+', ' ', text).strip()[:limit]


def count_swift(directory):
    total = 0
    for _, _, files in os.walk(directory):
        total += sum(1 for name in files if name.endswith(".swift"))
    return total


def sources_tree(pkg_dir):
    src = os.path.join(pkg_dir, "Sources")
    if not os.path.isdir(src):
        return []
    out = []
    for entry in sorted(os.listdir(src)):
        full = os.path.join(src, entry)
        if not os.path.isdir(full):
            continue
        subs = sorted(
            d for d in os.listdir(full)
            if os.path.isdir(os.path.join(full, d)) and not d.startswith(".")
        )
        out.append({
            "wrapper": entry,
            "subdirs": subs,
            "rootFiles": sorted(f for f in os.listdir(full) if f.endswith(".swift")),
            "swiftCount": count_swift(full),
        })
    return out


def test_files(pkg_dir):
    tests = os.path.join(pkg_dir, "Tests")
    out = []
    for base, _, files in os.walk(tests):
        for name in sorted(files):
            if name.endswith(".swift"):
                out.append(os.path.relpath(os.path.join(base, name), pkg_dir))
    return sorted(out)


def parse_test_file(path):
    """返回 (suites, tests)；tests 为 [(显示名|None, 函数名, suite|None)]。

    项目里的用例写法：
      1. 顶层自由函数   @Test @MainActor func foo() {
      2. struct 内方法   struct S { @Test("…") / @Test \n func foo() }
      3. 参数化测试     @Test("…", arguments: [...]) 可跨多行

    不做花括号配平 —— 字符串字面量里的 '{' / '}' 会让深度计数失真。
    改为顺序扫描：@Test 起始行记下显示名并跳过未闭合的括号参数，
    随后遇到的第一个 func 即其宿主。
    """
    with open(path, encoding="utf-8") as handle:
        lines = handle.readlines()

    suites = []
    tests = []
    current_suite = None
    pending_display = None
    pending_active = False
    pending_suite = None

    index = 0
    while index < len(lines):
        line = lines[index]

        suite_attr = ATTR_SUITE_LINE_RE.match(line)
        if suite_attr:
            pending_suite = suite_attr.group(1)
            index += 1
            continue

        type_match = TYPE_RE.match(line)
        if type_match:
            current_suite = pending_suite or type_match.group(1)
            if pending_suite and pending_suite not in suites:
                suites.append(pending_suite)
            pending_suite = None
            pending_active = False
            index += 1
            continue

        # 写法 1：@Test 与 func 同行
        inline = ATTR_TEST_INLINE_RE.match(line)
        if inline:
            tests.append((inline.group(1), inline.group(2), current_suite))
            index += 1
            continue

        # 写法 2/3：@Test 独占起始行，先吸收可能跨行的括号参数
        if ATTR_TEST_ONLY_RE.match(line):
            start = ATTR_TEST_START_RE.match(line)
            display = start.group(1) if start else None
            consumed = 1
            if line.count("(") > line.count(")"):
                while index + consumed < len(lines):
                    nxt = lines[index + consumed]
                    consumed += 1
                    if nxt.count(")") >= nxt.count("("):
                        break
            pending_display = display
            pending_active = True
            index += consumed
            continue

        func = DECL_RE.match(line)
        if func:
            if pending_active:
                tests.append((pending_display, func.group(1), current_suite))
                pending_active = False
                pending_display = None
            index += 1
            continue

        xctest = XCTest_FUNC_RE.match(line)
        if xctest:
            tests.append((None, xctest.group(1), current_suite))

        index += 1

    return suites, tests


def suites_and_tests(pkg_dir):
    tests_dir = os.path.join(pkg_dir, "Tests")
    suites, tests = [], []
    if not os.path.isdir(tests_dir):
        return suites, tests
    for rel in test_files(pkg_dir):
        file_suites, found = parse_test_file(os.path.join(pkg_dir, rel))
        suites.extend(s for s in file_suites if s not in suites)
        for display, func, suite in found:
            tests.append({
                "display": display,
                "func": func,
                "suite": suite,
                "file": rel,
            })
    return suites, tests


def has_testplan(pkg_dir):
    return os.path.isfile(os.path.join(pkg_dir, "Tests", "TestPlan.md"))


def all_packages():
    return sorted(
        name for name in os.listdir(PACKAGES)
        if os.path.isdir(os.path.join(PACKAGES, name, "Tests"))
    )


def collect(name):
    pkg_dir = os.path.join(PACKAGES, name)
    suites, tests = suites_and_tests(pkg_dir)
    return {
        "name": name,
        "hasTestPlan": has_testplan(pkg_dir),
        "platforms": platform_of(pkg_dir),
        "readme": readme_head(pkg_dir),
        "sources": sources_tree(pkg_dir),
        "testFiles": test_files(pkg_dir),
        "suites": suites,
        "tests": tests,
        "testCount": len(tests),
    }


def main():
    args = sys.argv[1:]
    if args and args[0] == "--missing":
        for name in all_packages():
            if not has_testplan(os.path.join(PACKAGES, name)):
                print(name)
        return
    if args and args[0] == "--all":
        print(json.dumps([collect(n) for n in all_packages()], ensure_ascii=False, indent=2))
        return
    for name in (args or all_packages()):
        print(json.dumps(collect(name), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
