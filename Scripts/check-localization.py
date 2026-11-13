#!/usr/bin/env python3
"""闸门：整个 App 以英语为默认/回退语言，同时支持多语言。

检查项：
  1. 每个 String Catalog 的 `sourceLanguage` 必须是 `en`。
  2. 英文译文（`en`）不得仍是中文 —— 否则英文系统会显示中文。
  3. `Package.swift` 的 `defaultLocalization` 必须声明为 `en`（资源 bundle 的回退语言）。
  4. 各 App / 扩展的 `CFBundleLocalizations` 必须声明完整的 5 种语言。
  5. `project.xcproj` 的 development 必须是 `en`，supported 必须覆盖除 `en`
     之外的 4 种语言（`en` 由 development 保证，Xcode 不重复列入 knownRegions）。
  6. UI 构造器（`Text` / `Button` / `Label` / `Window` / `.help` 等）的首参
     不得直接写中文字符串字面量 —— 必须走本地化 helper 或主 bundle 的英文 key。

跳过：
  * 注释行、Tests、build / SourcePackages / temp / .build / Vendor 等生成物。
  * 已通过 `L("...")` / `xxxLocalization.string("...")` 包装的中文 key（合法）。

用法：
    python3 Scripts/check-localization.py
"""
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LANGS = ["en", "zh-Hans", "zh-Hant", "zh-HK", "zh-TW"]
CJK = re.compile(r"[\u4e00-\u9fff]")
SKIP_DIRS = {"build", "SourcePackages", "temp", ".build", "Tests", "Vendor", "DerivedData"}
SCAN_ROOTS = [
    "Packages", "LumiApp", "LumiACPApp", "AppIconDesignerApp",
    "CADDesignerApp", "NettoExtension",
]
APP_PLISTS = [
    "LumiApp/Lumi-Info.plist",
    "LumiACPApp/LumiACP-Info.plist",
    "AppIconDesignerApp/AppIconDesigner-Info.plist",
    "CADDesignerApp/CADDesigner-Info.plist",
    "Packages/PluginRClick/FinderExtension/Info.plist",
    "NettoExtension/Info.plist",
]
UI_PATTERN = re.compile(
    r'(?<![\w])(Text|Label|Button|Toggle|Picker|TextField|SecureField|Menu|'
    r'Section|Link|Window|navigationTitle|help|alert)\s*\(\s*'
    r'(?:[a-zA-Z]+:\s*)?"([^"\\]*(?:\\.[^"\\]*)*)"'
)
STRING_LITERAL = re.compile(r'"([^"\\]*(?:\\.[^"\\]*)*)"')


def source_files(ext):
    for root in SCAN_ROOTS:
        base = ROOT / root
        if not base.exists():
            continue
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
            for name in filenames:
                if name.endswith(ext):
                    yield Path(dirpath) / name


def rel(path):
    return str(path.relative_to(ROOT))


def check_catalogs(errors):
    for path in sorted(source_files(".xcstrings")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (ValueError, OSError) as exc:
            errors.append(f"{rel(path)}: invalid String Catalog: {exc}")
            continue
        if data.get("sourceLanguage") != "en":
            errors.append(f"{rel(path)}: sourceLanguage is {data.get('sourceLanguage')!r}, expected 'en'")
        for key, entry in data.get("strings", {}).items():
            locs = entry.get("localizations", {}) if isinstance(entry, dict) else {}
            en = locs.get("en", {})
            unit = en.get("stringUnit", {}) if isinstance(en, dict) else {}
            value = unit.get("value", "") if isinstance(unit, dict) else ""
            if CJK.search(value):
                errors.append(f"{rel(path)}: English translation for {key!r} is still Chinese: {value!r}")


def check_manifests(errors):
    for path in sorted(source_files("Package.swift")):
        text = path.read_text(encoding="utf-8")
        match = re.search(r'defaultLocalization\s*:\s*"([^"]+)"', text)
        if match and match.group(1) != "en":
            errors.append(f"{rel(path)}: defaultLocalization is {match.group(1)!r}, expected 'en'")


def check_plists(errors):
    for name in APP_PLISTS:
        path = ROOT / name
        if not path.exists():
            errors.append(f"{name}: missing Info.plist")
            continue
        text = path.read_text(encoding="utf-8")
        match = re.search(r"<key>CFBundleLocalizations</key>\s*<array>(.*?)</array>", text, re.S)
        if not match:
            errors.append(f"{name}: missing CFBundleLocalizations")
            continue
        found = re.findall(r"<string>([^<]+)</string>", match.group(1))
        missing = [lang for lang in LANGS if lang not in found]
        if missing:
            errors.append(f"{name}: CFBundleLocalizations missing {', '.join(missing)}")


def check_project(errors):
    path = ROOT / "Lumi.xcodeproj" / "project.xcproj"
    if not path.exists():
        errors.append("Lumi.xcodeproj/project.xcproj: missing")
        return
    text = path.read_text(encoding="utf-8")
    dev = re.search(r'"development"\s*:\s*"([^"]+)"', text)
    if not dev or dev.group(1) != "en":
        errors.append("Lumi.xcodeproj/project.xcproj: development language is not 'en'")
    supported = re.search(r'"supported"\s*:\s*\[(.*?)\]', text, re.S)
    if not supported:
        errors.append("Lumi.xcodeproj/project.xcproj: missing localizations.supported")
        return
    found = re.findall(r'"([^"]+)"', supported.group(1))
    missing = [lang for lang in LANGS if lang != "en" and lang not in found]
    if missing:
        errors.append(
            f"Lumi.xcodeproj/project.xcproj: supported localizations missing {', '.join(missing)}"
        )


def check_ui_literals(errors):
    for path in sorted(source_files(".swift")):
        for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            stripped = line.strip()
            if stripped.startswith(("//", "///", "*", "*/")):
                continue
            for match in UI_PATTERN.finditer(line):
                value = match.group(2)
                if CJK.search(value):
                    errors.append(
                        f"{rel(path)}:{lineno}: hard-coded Chinese UI string: {value!r}"
                    )
                    break


def main():
    errors = []
    check_catalogs(errors)
    check_manifests(errors)
    check_plists(errors)
    check_project(errors)
    check_ui_literals(errors)
    if errors:
        for item in errors:
            print(item)
        print(f"\n{len(errors)} localization issue(s) found.", file=sys.stderr)
        return 1
    print("Localization check passed: English default + 5 supported languages.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
