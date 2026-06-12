#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGINS="$ROOT/Plugins"

python3 - "$ROOT" <<'PY'
import pathlib
import re
import shutil
import sys

root = pathlib.Path(sys.argv[1])
plugins = root / "Plugins"

package_patterns = [
    (
        re.compile(
            r'path:\s*"\.",\s*\n\s*exclude:\s*\[[^\]]*\],\s*\n\s*sources:\s*\["Sources"\],\s*\n\s*resources:\s*\[\s*\n\s*\.process\("Resources"\)\s*\n\s*\]',
            re.MULTILINE,
        ),
        'path: "Sources",\n            resources: [\n                .process("Localizable.xcstrings")\n            ]',
    ),
    (
        re.compile(
            r'path:\s*"\.",\s*\n\s*sources:\s*\["Sources"\],\s*\n\s*resources:\s*\[\s*\n\s*\.process\("Resources"\)\s*\n\s*\]',
            re.MULTILINE,
        ),
        'path: "Sources",\n            resources: [\n                .process("Localizable.xcstrings")\n            ]',
    ),
    (
        re.compile(
            r'path:\s*"\.",\s*\n\s*sources:\s*\["Sources"\],\s*\n\s*resources:\s*\[\s*\.process\("Resources"\)\s*\]',
            re.MULTILINE,
        ),
        'path: "Sources",\n            resources: [\n                .process("Localizable.xcstrings")\n            ]',
    ),
    (
        re.compile(r'\.process\("\.\./Resources"\)'),
        '.process("Localizable.xcstrings")',
    ),
]

swift_replacements = [
    (
        re.compile(
            r'String\(localized:\s*"((?:\\.|[^"\\])*)"\s*,\s*table:\s*"([^"]+)"\s*,\s*bundle:\s*\.module(?:\s*,\s*comment:\s*"")?\s*\)'
        ),
        r'LumiPluginLocalization.string("\1", bundle: .module, table: "\2")',
    ),
    (
        re.compile(
            r'String\(localized:\s*"((?:\\.|[^"\\])*)"\s*,\s*bundle:\s*\.module(?:\s*,\s*comment:\s*"")?\s*\)'
        ),
        r'LumiPluginLocalization.string("\1", bundle: .module)',
    ),
    (
        re.compile(
            r'String\(localized:\s*String\.LocalizationValue\(([^)]+)\)\s*,\s*table:\s*"([^"]+)"\s*,\s*bundle:\s*([^,\)]+)(?:\s*,\s*comment:\s*"")?\s*\)'
        ),
        r'LumiPluginLocalization.string(\1, bundle: \3, table: "\2")',
    ),
    (
        re.compile(
            r'String\(localized:\s*String\.LocalizationValue\(([^)]+)\)\s*,\s*bundle:\s*([^,\)]+)(?:\s*,\s*comment:\s*"")?\s*\)'
        ),
        r'LumiPluginLocalization.string(\1, bundle: \2)',
    ),
    (
        re.compile(r'Text\("((?:\\.|[^"\\])*)"\s*,\s*bundle:\s*\.module\)'),
        r'Text(verbatim: LumiPluginLocalization.string("\1", bundle: .module))',
    ),
    (
        re.compile(r'DisplayControlLocalization\.string\(([^)]+)\)'),
        r'LumiPluginLocalization.string(\1, bundle: .module)',
    ),
]

wrapper_body = re.compile(
    r'(enum\s+\w+Localization\s*\{[\s\S]*?static func string\(_ key: String[^)]*\)\s*->\s*String\s*\{)\s*[\s\S]*?(\n\s*\})',
    re.MULTILINE,
)

def migrate_package(plugin_dir: pathlib.Path) -> bool:
    package_file = plugin_dir / "Package.swift"
    resources = plugin_dir / "Resources" / "Localizable.xcstrings"
    sources_catalog = plugin_dir / "Sources" / "Localizable.xcstrings"

    changed = False
    if resources.exists() and not sources_catalog.exists():
        shutil.move(str(resources), str(sources_catalog))
        resources.parent.rmdir()
        changed = True

    if not package_file.exists():
        return changed

    text = package_file.read_text()
    original = text
    for pattern, replacement in package_patterns:
        text = pattern.sub(replacement, text)
    if text != original:
        package_file.write_text(text)
        changed = True
    return changed

def ensure_import_lumi_core_kit(text: str) -> str:
    if "LumiPluginLocalization" not in text:
        return text
    if "import LumiCoreKit" in text:
        return text

    lines = text.splitlines()
    insert_at = 0
    for index, line in enumerate(lines):
        if line.startswith("import "):
            insert_at = index + 1
    lines.insert(insert_at, "import LumiCoreKit")
    return "\n".join(lines) + ("\n" if text.endswith("\n") else "")

def migrate_swift(swift_file: pathlib.Path) -> bool:
    text = swift_file.read_text()
    original = text

    for pattern, replacement in swift_replacements:
        text = pattern.sub(replacement, text)

    # Update plugin-specific localization wrappers.
    def replace_wrapper(match: re.Match[str]) -> str:
        header = match.group(1)
        closing = match.group(2)
        enum_block = match.group(0)
        table = "Localizable"
        bundle = ".module"
        table_match = re.search(r'static let table = "([^"]+)"', enum_block)
        bundle_match = re.search(r'static let bundle = ([^\n]+)', enum_block)
        if table_match:
            table = table_match.group(1)
        if bundle_match:
            bundle = bundle_match.group(1).strip()
        body = (
            f"\n        LumiPluginLocalization.string(key, bundle: {bundle}, table: \"{table}\")"
        )
        return f"{header}{body}{closing}"

    text = wrapper_body.sub(replace_wrapper, text)
    text = ensure_import_lumi_core_kit(text)

    if text != original:
        swift_file.write_text(text)
        return True
    return False

changed_packages = 0
changed_swift = 0
for plugin_dir in sorted(plugins.iterdir()):
    if not plugin_dir.is_dir():
        continue
    if migrate_package(plugin_dir):
        changed_packages += 1

    for swift_file in plugin_dir.rglob("*.swift"):
        if ".build" in swift_file.parts:
            continue
        if migrate_swift(swift_file):
            changed_swift += 1

print(f"Updated Package.swift in {changed_packages} plugins")
print(f"Updated {changed_swift} Swift files")
PY
