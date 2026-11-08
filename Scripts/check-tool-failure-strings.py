#!/usr/bin/env python3
"""闸门：工具不得用字符串字面量表达失败。

`SuperAgentTool.execute` 返回的字符串会被 `ToolCallResult` 当成成功内容
（`isError == false`）。把 "Error: ..." / "失败：..." 写进返回值，对上层
是成功语义，模型无法据此判断工具失败。失败必须 `throw ToolExecutionError`，
由 `ToolExecutionManager` 统一标记 `isError = true`。

扫描范围:
    Packages/**/Sources/**/*.swift 中声明了 `SuperAgentTool` 的文件。

跳过:
  * 注释行
  * `errorDescription` / `failureReason` / `recoverySuggestion` 的实现块
    （Error 的本地化文案本身就是字符串，属于合法用法）

白名单:
    `EMPTY_RESULT_PATTERNS` 只允许真正的空结果文案（如 "No projects found."）。
    失败文案不得豁免；确需例外时在评审中先修代码，而不是往白名单里加。

用法:
    python3 Scripts/check-tool-failure-strings.py
    python3 Scripts/check-tool-failure-strings.py Packages/PluginGit/Sources/PluginGit/Tools/GitLogTool.swift
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACKAGES = os.path.join(ROOT, "Packages")
SKIP_DIRS = {".build", "Tests", "DerivedData", ".swiftpm"}

# 只挑真正声明了 SuperAgentTool 的类型/扩展（允许跨行的一致性列表）。
TOOL_DECL_RE = re.compile(
    r'^\s*(?:@\w+(?:\([^)]*\))?\s*)*'
    r'(?:public\s+|internal\s+|private\s+|fileprivate\s+|final\s+)*'
    r'(?:struct|class|actor|extension)\s+\w+[^{]*:\s*[^{]*\bSuperAgentTool\b',
    re.MULTILINE,
)

RETURN_RE = re.compile(r'\breturn\s+(.+)$')
ERROR_PROPERTY_RE = re.compile(
    r'\b(?:var|func)\s+(?:errorDescription|failureReason|recoverySuggestion)\s*:'
)
SINGLE_STRING_RE = re.compile(r'"((?:[^"\\]|\\.)*)"')
COMMENT_RE = re.compile(r'^\s*(?://|/\*|\*)')

# 「以字符串字面量表达失败」的判据。
# 英文只认行首前缀，中文额外允许「……失败：」这种把主语放在前面的写法。
FAILURE_PATTERNS = (
    re.compile(
        r'^\s*(?:Error|Failed|Failure|Invalid|Unable|Cannot|Can\'t|Missing|'
        r'Unsupported|Not found)\b'
    ),
    re.compile(r'^\s*(?:错误|失败|无法|缺少|不支持|未找到|找不到|非法)'),
    re.compile(r'(?:失败|错误|无法|缺少|不支持|未找到|找不到|非法)[：:]'),
    re.compile(r'❌'),
)

# 白名单：真正的空结果文案。命中即视为合法的「成功但为空」。
EMPTY_RESULT_PATTERNS = (
    re.compile(r'^No\s'),        # "No projects found."
    re.compile(r'^暂无'),         # "暂无提交记录"
    re.compile(r'^✅\s*没有'),    # "✅ 没有变更"
    re.compile(r'^没有'),         # "没有变更"
)


def tool_source_files(paths):
    """返回声明了 SuperAgentTool 的 Swift 源码文件。"""
    if paths:
        return [os.path.abspath(path) for path in paths if os.path.isfile(path)]

    found = []
    for dirpath, dirnames, filenames in os.walk(PACKAGES):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            if name.endswith(".swift"):
                found.append(os.path.join(dirpath, name))
    return sorted(found)


def is_tool_source(text):
    return TOOL_DECL_RE.search(text) is not None


def collect_return_literals(lines, index):
    """收集 `index` 行 return 语句里的字符串字面量。

    返回 (literals, consumed, expression)：`consumed` 是多行字面量额外吃掉的行数。
    """
    match = RETURN_RE.search(lines[index])
    if not match:
        return [], 0, ""

    # 跳过行尾注释里的 `return "..."`。
    comment_index = lines[index].find("//")
    if comment_index != -1 and match.start() > comment_index:
        return [], 0, ""

    expression = match.group(1)
    if not expression.startswith('"""'):
        return SINGLE_STRING_RE.findall(expression), 0, expression

    parts = []
    rest = expression[3:]
    cursor = index
    while True:
        if '"""' in rest:
            parts.append(rest.split('"""', 1)[0])
            break
        parts.append(rest)
        cursor += 1
        if cursor >= len(lines):
            break
        rest = lines[cursor]
    return ["\n".join(parts)], cursor - index, expression


def is_failure_copy(literal):
    if any(pattern.search(literal) for pattern in EMPTY_RESULT_PATTERNS):
        return False
    return any(pattern.search(literal) for pattern in FAILURE_PATTERNS)


def first_content_line(literal):
    """多行文案只看第一行非空内容。

    状态块式的多行文案常把 ✅/❌ 放在标题行；正文里出现 "failed" 之类的
    统计字样不代表工具失败，因此不对整块做匹配。
    """
    for line in literal.splitlines():
        stripped = line.strip()
        if stripped:
            return stripped
    return ""


def scan_file(path):
    """返回 [(行号, 内容)]，即文件中所有失败字符串。"""
    with open(path, encoding="utf-8") as handle:
        lines = handle.read().splitlines()

    violations = []
    error_property_depth = 0
    index = 0
    while index < len(lines):
        line = lines[index]

        if error_property_depth > 0:
            error_property_depth += line.count("{") - line.count("}")
            index += 1
            continue

        if ERROR_PROPERTY_RE.search(line):
            # 单行写法 `var errorDescription: String? { "..." }` 也按块处理。
            error_property_depth += line.count("{") - line.count("}")
            index += 1
            continue

        if COMMENT_RE.match(line):
            index += 1
            continue

        literals, consumed, expression = collect_return_literals(lines, index)
        # 只有直接返回字符串字面量才算「用返回字符串表达失败」。
        # `return .executionFailed(...)` / `return ToolCallResult(..., isError: true)`
        # 都不是字符串返回，不在此列。
        if expression.startswith('"') and any(
            is_failure_copy(first_content_line(literal)) for literal in literals
        ):
            violations.append((index + 1, line.strip()))

        index += consumed + 1

    return violations


def main():
    candidates = tool_source_files(sys.argv[1:])
    scanned = 0
    problems = []

    for path in candidates:
        try:
            with open(path, encoding="utf-8") as handle:
                text = handle.read()
        except (OSError, UnicodeDecodeError):
            continue
        if not is_tool_source(text):
            continue

        scanned += 1
        for lineno, content in scan_file(path):
            problems.append(
                f"{os.path.relpath(path, ROOT)}:{lineno}: {content}"
            )

    print(f"已扫描 {scanned} 个工具源码文件")
    if problems:
        print(f"\n发现 {len(problems)} 处以字符串字面量表达失败：\n")
        for problem in problems:
            print(f"  {problem}")
        print("\n失败必须 `throw ToolExecutionError`，让包装层标记 isError。")
        sys.exit(1)
    print("全部通过 ✅")


if __name__ == "__main__":
    main()
