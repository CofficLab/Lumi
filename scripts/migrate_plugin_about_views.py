#!/usr/bin/env python3
"""Migrate plugin aboutView calls to localized template API."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLUGINS_DIR = ROOT / "Plugins"

KIND_MAP = {
    "general": ".general",
    "manager": ".manager",
    "editor_bottom": ".editorBottom",
    "editor_rail": ".editorRail",
    "editor": ".editor",
    "open_in": ".openIn",
}


def plugin_kind(path: Path) -> str:
    name = path.parent.parent.name
    if "OpenIn" in name or "open-in" in path.read_text():
        return "open_in"
    if name.startswith("EditorBottom"):
        return "editor_bottom"
    if name.startswith("EditorRail"):
        return "editor_rail"
    if name.startswith("Editor"):
        return "editor"
    if name.endswith("ManagerPlugin"):
        return "manager"
    return "general"


def replace_about_view(path: Path) -> bool:
    source = path.read_text()
    if "pluginAboutView(" not in source:
        return False

    kind = plugin_kind(path)
    new_method = f"""    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {{
        pluginAboutView(
            icon: iconName,
            displayName: info.displayName,
            description: info.description,
            kind: {KIND_MAP[kind]}
        )
    }}"""

    updated = re.sub(
        r"@MainActor\s+public static func aboutView\(context: LumiPluginContext\) -> AnyView\? \{.*?\n    \}\n",
        new_method + "\n",
        source,
        count=1,
        flags=re.DOTALL,
    )
    if updated == source:
        return False
    path.write_text(updated)
    return True


def main() -> None:
    changed = []
    for path in sorted(PLUGINS_DIR.glob("*/Sources/**/*.swift")):
        if replace_about_view(path):
            changed.append(str(path.relative_to(ROOT)))
    print(f"Updated {len(changed)} files")
    for item in changed:
        print(item)


if __name__ == "__main__":
    main()
