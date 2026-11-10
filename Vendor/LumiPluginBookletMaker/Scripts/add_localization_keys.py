#!/usr/bin/env python3
"""Regenerate Localizable.xcstrings with new keys, in Xcode's exact format.

A String Catalog is JSON, but Xcode writes it in a specific style: `" : "`
separators, two-space indentation, keys in `localizedStandardCompare` order,
and no trailing newline. This script reproduces that style byte for byte, so
regenerating the catalog only changes the keys that actually changed.

Ordering is delegated to Foundation (via a small Swift helper), because
`localizedStandardCompare` is locale aware and does not agree with plain
string comparison for punctuation and digits.

Usage:
    scripts/add_localization_keys.py <payload.json>

The payload is a JSON object mapping a key to its translations, e.g.:

    {
      "Merge PDFs": {
        "en": "Merge PDFs",
        "zh-Hans": "合并 PDF",
        "zh-Hant": "合併 PDF",
        "zh-HK": "合併 PDF",
        "zh-TW": "合併 PDF"
      }
    }
"""
import json
import subprocess
import sys
from collections import OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Resources" / "Localizable.xcstrings"
LOCALES = ["en", "zh-Hans", "zh-Hant", "zh-HK", "zh-TW"]

SORT_HELPER = """
import Foundation
let path = CommandLine.arguments[1]
let data = try! Data(contentsOf: URL(fileURLWithPath: path))
let obj = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
let keys = (obj["strings"] as! [String: Any]).keys.sorted { a, b in
    (a as NSString).localizedStandardCompare(b as String) == .orderedAscending
}
for key in keys { print(key) }
"""


def sort_keys(keys):
    """Sort keys the way Xcode does, via Foundation's localizedStandardCompare."""
    script = ROOT / "Scripts" / ".localized_sort_helper.swift"
    binary = ROOT / "Scripts" / ".localized_sort_helper"
    scratch = ROOT / "Scripts" / ".localized_sort_input.json"
    script.write_text(SORT_HELPER, encoding="utf-8")
    try:
        subprocess.run(
            ["swiftc", "-O", str(script), "-o", str(binary)],
            check=True,
            capture_output=True,
        )
        scratch.write_text(
            json.dumps({"strings": {k: {} for k in keys}}, ensure_ascii=False),
            encoding="utf-8",
        )
        result = subprocess.run(
            [str(binary), str(scratch)],
            check=True,
            capture_output=True,
            text=True,
        )
        return [line for line in result.stdout.splitlines() if line]
    finally:
        for path in (script, binary, scratch):
            path.unlink(missing_ok=True)


def render(catalog):
    """Render the catalog in Xcode's String Catalog style."""
    lines = ['{', f'  "sourceLanguage" : {json.dumps(catalog["sourceLanguage"])},', '  "strings" : {']
    blocks = []
    for key, entry in catalog["strings"].items():
        block = [f"    {json.dumps(key, ensure_ascii=False)} : {{"]
        if "extractionState" in entry:
            block.append(f'      "extractionState" : {json.dumps(entry["extractionState"])},')
        block.append('      "localizations" : {')
        locales = []
        for locale in LOCALES:
            unit = entry["localizations"][locale]["stringUnit"]
            locales.append(
                f'        "{locale}" : {{\n'
                '          "stringUnit" : {\n'
                f'            "state" : {json.dumps(unit["state"])},\n'
                f'            "value" : {json.dumps(unit["value"], ensure_ascii=False)}\n'
                "          }\n"
                "        }"
            )
        block.append(",\n".join(locales))
        block.append("      }")
        block.append("    }")
        blocks.append("\n".join(block))
    lines.append(",\n".join(blocks))
    lines.append("  },")
    lines.append(f'  "version" : {json.dumps(catalog.get("version", "1.0"))}')
    lines.append("}")
    return "\n".join(lines)  # Xcode writes no trailing newline


def main():
    if len(sys.argv) < 2:
        print("usage: add_localization_keys.py <payload.json>", file=sys.stderr)
        return 1
    payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))

    raw = CATALOG.read_text(encoding="utf-8")
    catalog = json.loads(raw, object_pairs_hook=OrderedDict)
    strings = catalog["strings"]

    added = []
    for key, values in payload.items():
        if key in strings:
            print(f"skip (exists): {key}")
            continue
        missing = [locale for locale in LOCALES if locale not in values]
        if missing:
            raise SystemExit(f"missing locales for {key!r}: {missing}")
        strings[key] = OrderedDict([
            ("localizations", OrderedDict([
                (locale, OrderedDict([
                    ("stringUnit", OrderedDict([
                        ("state", "translated"),
                        ("value", values[locale]),
                    ])),
                ]))
                for locale in LOCALES
            ])),
        ])
        added.append(key)

    if not added:
        print("nothing to add")
        return 0

    # Re-sort the whole catalog: Xcode keeps the keys ordered, and a new key
    # belongs wherever its position lands.
    ordered = sort_keys(list(strings.keys()))
    catalog["strings"] = OrderedDict((key, strings[key]) for key in ordered)

    CATALOG.write_text(render(catalog), encoding="utf-8")
    print(f"added {len(added)} keys; total {len(strings)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
