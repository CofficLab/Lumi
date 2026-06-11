#!/usr/bin/env python3
"""Create Localizable.xcstrings and wire resources for plugins missing them."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

KEY_RE = re.compile(r'String\(localized:\s*"(?P<value>(?:\\.|[^"\\])*)"\s*,\s*bundle:\s*\.module\)')
TEXT_RE = re.compile(r'Text\("(?P<value>(?:\\.|[^"\\])*)"\s*,\s*bundle:\s*\.module\)')

THEME_PLUGINS = {"ThemeSkyPlugin", "ThemeLumiPlugin"}


def collect_keys(plugin_dir: Path) -> set[str]:
    keys: set[str] = set()
    for swift in plugin_dir.rglob("*.swift"):
        if ".build" in swift.parts or "Tests" in swift.parts:
            continue
        text = swift.read_text(encoding="utf-8")
        for pattern in (KEY_RE, TEXT_RE):
            keys.update(m.group("value") for m in pattern.finditer(text))
    return keys


def xcstrings_path(plugin_dir: Path) -> Path:
    if plugin_dir.name in THEME_PLUGINS:
        return plugin_dir / "Sources" / "Localizable.xcstrings"
    return plugin_dir / "Resources" / "Localizable.xcstrings"


def write_xcstrings(path: Path, keys: set[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    strings = {key: {} for key in sorted(keys)}
    data = {"sourceLanguage": "en", "strings": strings, "version": "1.0"}
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def patch_package_swift(plugin_dir: Path) -> bool:
    package_file = plugin_dir / "Package.swift"
    text = package_file.read_text(encoding="utf-8")
    original = text
    name = plugin_dir.name

    if 'defaultLocalization: "en"' not in text:
        text = text.replace(
            "let package = Package(\n    name:",
            'let package = Package(\n    name:',
            1,
        )
        text = re.sub(
            r"let package = Package\(\n    name: \"[^\"]+\"",
            lambda m: m.group(0) + ',\n    defaultLocalization: "en"',
            text,
            count=1,
        )

    if name in THEME_PLUGINS:
        resource_line = '                .process("Localizable.xcstrings")'
        if resource_line not in text:
            text = re.sub(
                r"(path: \"Sources\",\n)(\s+)(linkerSettings:|swiftSettings:|\))",
                r'\1\2resources: [\n\2    .process("Localizable.xcstrings")\n\2],\n\2\3',
                text,
                count=1,
            )
    else:
        resource_line = '                .process("../Resources")'
        if resource_line not in text and '.process("Resources")' not in text:
            if 'path: "Sources"' in text:
                text = re.sub(
                    r'(path: "Sources",\n)(\s+)(linkerSettings:|swiftSettings:|\))',
                    r'\1\2resources: [\n\2    .process("../Resources")\n\2],\n\2\3',
                    text,
                    count=1,
                )
            elif name == "ProjectsPlugin":
                text = re.sub(
                    r'(name: "ProjectsPlugin",\n\s+dependencies: \[[^\]]+\],)\n(\s+)\)',
                    r'\1\n\2path: ".",\n\2sources: ["Sources"],\n\2resources: [\n\2    .process("Resources")\n\2]\n\2)',
                    text,
                    count=1,
                )

    if text != original:
        package_file.write_text(text, encoding="utf-8")
        return True
    return False


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("Plugins")
    created = 0
    for plugin_dir in sorted(root.iterdir()):
        if not plugin_dir.is_dir() or not (plugin_dir / "Package.swift").exists():
            continue
        existing = [p for p in plugin_dir.rglob("Localizable.xcstrings") if ".build" not in p.parts]
        if existing:
            continue
        keys = collect_keys(plugin_dir)
        if not keys:
            print(f"SKIP {plugin_dir.name}: no localization keys found")
            continue
        path = xcstrings_path(plugin_dir)
        write_xcstrings(path, keys)
        patched = patch_package_swift(plugin_dir)
        created += 1
        print(f"CREATED {plugin_dir.name}: {len(keys)} keys, package patched={patched}")
    print(f"Bootstrapped {created} plugins.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
