#!/usr/bin/env python3
"""Add bundle: .module to plugin Swift localization call sites."""

from __future__ import annotations

import re
import sys
from pathlib import Path

DISPLAY_NAME_RE = re.compile(
    r'(?P<prefix>displayName:\s*)"(?P<value>(?:\\.|[^"\\])*)"(?!\s*,\s*bundle:)'
)
DESCRIPTION_RE = re.compile(
    r'(?P<prefix>description:\s*)"(?P<value>(?:\\.|[^"\\])*)"(?!\s*,\s*bundle:)'
)
STATIC_DISPLAY_NAME_RE = re.compile(
    r'(?P<prefix>static let displayName(?:\s*:\s*String)?\s*=\s*)"(?P<value>(?:\\.|[^"\\])*)"(?!\s*,\s*bundle:)'
)
STATIC_DESCRIPTION_RE = re.compile(
    r'(?P<prefix>static let description(?:\s*:\s*String)?\s*=\s*)"(?P<value>(?:\\.|[^"\\])*)"(?!\s*,\s*bundle:)'
)
STRING_LOCALIZED_RE = re.compile(
    r'String\(localized:\s*"(?P<value>(?:\\.|[^"\\])*)"\)(?!\s*,\s*bundle:)'
)
TEXT_LITERAL_RE = re.compile(
    r'\bText\("(?P<value>(?:\\.|[^"\\])*)"\)(?!\s*,\s*bundle:)'
)
LABEL_TITLE_RE = re.compile(
    r'\bLabel\("(?P<value>(?:\\.|[^"\\])*)",\s*systemImage:'
)
# Only localize static Label titles (no interpolation).
BUTTON_RE = re.compile(
    r'\bButton\("(?P<value>(?:\\.|[^"\\])*)"\)(?!\s*,\s*bundle:)'
)
HELP_RE = re.compile(
    r'\.help\("(?P<value>(?:\\.|[^"\\])*)"\)(?!\s*,\s*bundle:)'
)

SKIP_PATH_PARTS = {".build", "Tests", "DerivedData"}


def should_process(path: Path) -> bool:
    if path.suffix != ".swift":
        return False
    if any(part in SKIP_PATH_PARTS for part in path.parts):
        return False
    return True


def replace_display_name(match: re.Match[str]) -> str:
    value = match.group("value")
    return f'{match.group("prefix")}String(localized: "{value}", bundle: .module)'


def replace_description(match: re.Match[str]) -> str:
    value = match.group("value")
    return f'{match.group("prefix")}String(localized: "{value}", bundle: .module)'


def replace_string_localized(match: re.Match[str]) -> str:
    value = match.group("value")
    return f'String(localized: "{value}", bundle: .module)'


def replace_text_literal(match: re.Match[str]) -> str:
    value = match.group("value")
    if "\\(" in value:
        return match.group(0)
    return f'Text("{value}", bundle: .module)'


def replace_label(match: re.Match[str]) -> str:
    value = match.group("value")
    if "\\(" in value:
        return match.group(0)
    return f'Label("{value}", bundle: .module, systemImage:'


def replace_button(match: re.Match[str]) -> str:
    value = match.group("value")
    return f'Button("{value}", bundle: .module)'


def replace_help(match: re.Match[str]) -> str:
    value = match.group("value")
    return f'.help(String(localized: "{value}", bundle: .module))'


def process_file(path: Path) -> bool:
    original = path.read_text(encoding="utf-8")
    updated = original

    for pattern, repl in (
        (DISPLAY_NAME_RE, replace_display_name),
        (DESCRIPTION_RE, replace_description),
        (STATIC_DISPLAY_NAME_RE, replace_display_name),
        (STATIC_DESCRIPTION_RE, replace_description),
        (STRING_LOCALIZED_RE, replace_string_localized),
        (TEXT_LITERAL_RE, replace_text_literal),
        (LABEL_TITLE_RE, replace_label),
        (BUTTON_RE, replace_button),
        (HELP_RE, replace_help),
    ):
        updated = pattern.sub(repl, updated)

    if updated != original:
        path.write_text(updated, encoding="utf-8")
        return True
    return False


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("Plugins")
    changed = 0
    for path in sorted(root.rglob("*.swift")):
        if not should_process(path):
            continue
        if process_file(path):
            changed += 1
            print(path)
    print(f"Updated {changed} Swift files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
