#!/usr/bin/env python3
"""依赖规则护栏（docs/editor-kernel-plugin-rearchitecture-plan.md §6 / §27.4）。

扫描所有 Package.swift 与 Swift import，阻止依赖规则回退：
1. KernelLumi 不得 import EditorService / EditorSource / EditorKernel / EditorTextView / 任何插件模块。
2. EditorKernel 不得 import SwiftUI / AppKit / EditorService / 任何插件模块。
3. 非 Host 插件不得依赖 EditorService / EditorSource / EditorTextView / EditorKernel。
4. 插件之间不得互相依赖。

用法：python3 Scripts/check-editor-dependencies.py [--fix-hint]
退出码：0 = 通过；1 = 存在违规。
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PACKAGES_DIR = REPO_ROOT / "Packages"
PLUGINS_DIR = REPO_ROOT / "Plugins"

# 唯一允许依赖编辑器实现层的 Host 插件。
EDITOR_HOST_PLUGIN = "EditorHostPlugin"
# 允许依赖完整编辑器栈的非插件 Package（服务门面层自身）。
EDITOR_IMPL_PACKAGES = {"EditorService", "FactoryLumi", "FactoryLumi", "EditorChatInputKit"}
EDITOR_IMPL_MODULES = {"EditorService", "EditorSource", "EditorTextView", "EditorKernel", "EditorLanguageRuntime"}

PLUGIN_FORBIDDEN_MODULES = {"EditorService", "EditorSource", "EditorTextView", "EditorKernel"}
KERNEL_FORBIDDEN_MODULES = EDITOR_IMPL_MODULES | {"EditorChatInputKit"}
EDITOR_KERNEL_FORBIDDEN_MODULES = {"SwiftUI", "AppKit", "EditorService"}

IGNORED_DIRS = {".build", "Tests", "TestSupport", "ci_scripts", "docs", "Scripts"}


def local_package_names() -> set[str]:
    names = set()
    for pkg in list(PACKAGES_DIR.glob("*/Package.swift")) + list(PLUGINS_DIR.glob("*/Package.swift")):
        names.add(pkg.parent.name)
    return names


def package_dep_paths(package_swift: Path) -> list[str]:
    """提取 `.package(path: "...")` 中声明的本地依赖名。"""
    text = package_swift.read_text(encoding="utf-8")
    return re.findall(r'\.package\(\s*path:\s*"([^"]+)"', text)


def import_modules_in_sources(root: Path) -> set[str]:
    modules: set[str] = set()
    for swift in root.rglob("*.swift"):
        if any(part in IGNORED_DIRS for part in swift.parts):
            continue
        try:
            text = swift.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        for match in re.finditer(r'^\s*(?:@\w+\s+)?import\s+([A-Za-z_][A-Za-z0-9_]*)', text, re.M):
            modules.add(match.group(1))
    return modules


def main() -> int:
    all_local = local_package_names()
    violations: list[str] = []

    for pkg in sorted(PACKAGES_DIR.glob("*/Package.swift")) + sorted(PLUGINS_DIR.glob("*/Package.swift")):
        name = pkg.parent.name
        deps = [Path(d).name for d in package_dep_paths(pkg)]
        sources = pkg.parent / "Sources"
        imports = import_modules_in_sources(sources) if sources.exists() else set()

        def report(kind: str, detail: str) -> None:
            violations.append(f"[{kind}] {name}: {detail}")

        # 规则 3/4：插件依赖。
        if pkg.parent.parent == PLUGINS_DIR:
            for dep in deps:
                if dep in PLUGIN_FORBIDDEN_MODULES and name != EDITOR_HOST_PLUGIN:
                    report("plugin-dep", f"禁止依赖 {dep}（仅 {EDITOR_HOST_PLUGIN} 允许）")
                if (PLUGINS_DIR / dep).exists() and dep != name:
                    report("plugin-dep", f"禁止依赖其他插件 {dep}")
            for module in sorted(imports & PLUGIN_FORBIDDEN_MODULES):
                if name != EDITOR_HOST_PLUGIN:
                    report("plugin-import", f"禁止 import {module}（仅 {EDITOR_HOST_PLUGIN} 允许）")

        # 规则 1：KernelLumi。
        if name == "KernelLumi":
            for module in sorted(imports & KERNEL_FORBIDDEN_MODULES):
                report("kernel-import", f"KernelLumi 禁止 import {module}")
            for dep in deps:
                if dep in KERNEL_FORBIDDEN_MODULES:
                    report("kernel-dep", f"KernelLumi 禁止依赖 {dep}")

        # 规则 2：EditorKernel。
        if name == "EditorKernel":
            for module in sorted(imports & EDITOR_KERNEL_FORBIDDEN_MODULES):
                report("editorkernel-import", f"EditorKernel 禁止 import {module}")

        # 基础层不得依赖上层。
        if name in {"EditorTextView", "EditorLanguageRuntime"}:
            for module in sorted(imports & {"EditorService", "EditorSource", "EditorKernel"}):
                report("base-import", f"{name} 禁止 import {module}")

    if violations:
        print("依赖规则违规：", file=sys.stderr)
        for violation in violations:
            print(f"  {violation}", file=sys.stderr)
        print(f"\n共 {len(violations)} 处违规。见 docs/editor-kernel-plugin-rearchitecture-plan.md §6。", file=sys.stderr)
        return 1

    print(f"依赖规则检查通过（扫描 {len(all_local)} 个本地 Package）。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
