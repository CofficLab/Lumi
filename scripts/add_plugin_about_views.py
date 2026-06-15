#!/usr/bin/env python3
"""Add aboutView to non-alwaysOn LumiPlugin implementations."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLUGINS_DIR = ROOT / "Plugins"

ABOUT_METHOD_MARKER = "func aboutView"


def swift_escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def extract_string_literal(source: str, key: str) -> str | None:
    patterns = [
        rf'{key}:\s*LumiPluginLocalization\.string\("([^"]+)"',
        rf'{key}:\s*\w+Localization\.string\("([^"]+)"',
        rf'{key}:\s*"([^"]+)"',
        rf'static let {key}\s*=\s*"([^"]+)"',
        rf'static let {key}:\s*String\s*=\s*LumiPluginLocalization\.string\("([^"]+)"',
        rf'static let {key}:\s*String\s*=\s*"([^"]+)"',
        rf'static var {key}:\s*String\s*\{{\s*info\.{key}\s*\}}',
    ]
    for pattern in patterns:
        match = re.search(pattern, source)
        if match:
            return match.group(1)
    if key == "displayName":
        match = re.search(r'static let displayName\s*=\s*"([^"]+)"', source)
        if match:
            return match.group(1)
    if key == "description":
        match = re.search(r'static let description\s*=\s*"([^"]+)"', source)
        if match:
            return match.group(1)
    return None


def extract_icon(source: str) -> str:
    match = re.search(r'iconName\s*=\s*"([^"]+)"', source)
    if match:
        return match.group(1)
    match = re.search(r'iconName:\s*String\s*=\s*"([^"]+)"', source)
    if match:
        return match.group(1)
    return "puzzlepiece.extension"


def plugin_kind(path: Path, source: str) -> str:
    name = path.parent.parent.name
    if "OpenIn" in name or "open-in" in source:
        return "open_in"
    if name.startswith("EditorBottom"):
        return "editor_bottom"
    if name.startswith("EditorRail"):
        return "editor_rail"
    if name.startswith("Editor"):
        return "editor"
    if name.endswith("ManagerPlugin"):
        return "manager"
    if "Theme" in name:
        return "theme"
    if "LLMProvider" in name:
        return "llm_provider"
    return "general"


def content_for(kind: str, display_name: str, description: str, icon: str) -> tuple[list[tuple[str, str, str]], list[str], list[str]]:
    desc = description or f"Provides {display_name} capabilities in Lumi."

    if kind == "open_in":
        features = [
            (icon, display_name, desc),
            ("arrow.up.right.square", "Quick Access", "Adds a status bar action to open the current project externally"),
            ("folder", "Project Aware", "Uses the active project path from the current workspace"),
        ]
        steps = [
            "Enable the plugin in plugin settings",
            "Open a project in Lumi",
            "Use the status bar button to launch the external app",
        ]
        tips = [
            "Make sure the target application is installed on your Mac",
            "The action uses the currently opened project path",
        ]
        return features, steps, tips

    if kind == "editor_bottom":
        features = [
            (icon, display_name, desc),
            ("rectangle.bottomhalf.inset.filled", "Bottom Panel", "Adds a tab to the editor bottom panel"),
            ("doc.text.magnifyingglass", "Editor Context", "Works with the file currently open in the editor"),
        ]
        steps = [
            "Enable the plugin in plugin settings",
            "Open a file in the code editor",
            "Open the bottom panel tab provided by this plugin",
        ]
        tips = [
            "Use the status bar shortcut when available",
            "Disable the plugin if you prefer a cleaner editor layout",
        ]
        return features, steps, tips

    if kind == "editor_rail":
        features = [
            (icon, display_name, desc),
            ("sidebar.left", "Side Rail", "Adds a panel to the editor side rail"),
            ("doc.text", "File Context", "Shows information related to the active editor file"),
        ]
        steps = [
            "Enable the plugin in plugin settings",
            "Open a file in the code editor",
            "Select the rail tab provided by this plugin",
        ]
        tips = [
            "Collapse the rail when you need more editor space",
            "Combine with other rail plugins for a richer workflow",
        ]
        return features, steps, tips

    if kind == "editor":
        features = [
            (icon, display_name, desc),
            ("chevron.left.forwardslash.chevron.right", "Editor Extension", "Extends the built-in code editor"),
            ("paintbrush", "Language Support", "Improves editing for specific file types"),
        ]
        steps = [
            "Enable the plugin in plugin settings",
            "Open a supported file in the editor",
            "Use the editor features provided by this plugin",
        ]
        tips = [
            "Keep only the editor extensions you actively use enabled",
            "Some features depend on language tooling being available",
        ]
        return features, steps, tips

    if kind == "manager":
        features = [
            (icon, display_name, desc),
            ("slider.horizontal.3", "Management UI", "Provides a dedicated management view in Lumi"),
            ("gearshape", "Configurable", "Can be enabled or disabled from plugin settings"),
        ]
        steps = [
            "Enable the plugin in plugin settings",
            "Open the plugin view from the sidebar or view container",
            "Manage resources directly inside Lumi",
        ]
        tips = [
            "Review permissions if the plugin accesses system resources",
            "Disable the plugin when you do not need this workflow",
        ]
        return features, steps, tips

    features = [
        (icon, display_name, desc),
        ("puzzlepiece.extension", "Lumi Integration", f"Integrates {display_name} into the Lumi workspace"),
        ("gearshape", "Configurable", "Enable or disable from plugin settings"),
    ]
    steps = [
        f"Enable {display_name} in plugin settings",
        "The plugin registers its contributions when enabled",
        "Use the features provided in the Lumi workspace",
    ]
    tips = [
        "Toggle the plugin off if you do not need this feature",
        "Check plugin settings for additional options",
    ]
    return features, steps, tips


def render_about_method(features: list[tuple[str, str, str]], steps: list[str], tips: list[str]) -> str:
    feature_lines = ",\n                ".join(
        f'.init(icon: "{swift_escape(icon)}", title: "{swift_escape(title)}", description: "{swift_escape(description)}")'
        for icon, title, description in features
    )
    step_lines = ",\n                ".join(f'"{swift_escape(step)}"' for step in steps)
    tip_lines = ",\n                ".join(f'"{swift_escape(tip)}"' for tip in tips)
    return f"""
    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {{
        pluginAboutView(
            features: [
                {feature_lines}
            ],
            steps: [
                {step_lines}
            ],
            tips: [
                {tip_lines}
            ]
        )
    }}
"""


def ensure_imports(source: str) -> str:
    if "import SwiftUI" not in source:
        if "import LumiCoreKit" in source:
            source = source.replace("import LumiCoreKit", "import LumiCoreKit\nimport SwiftUI", 1)
        else:
            source = "import SwiftUI\n" + source
    return source


def insert_about_method(source: str, method: str) -> str:
  # Insert before final closing brace of the primary plugin type.
    enum_match = re.search(r"(?:public )?enum \w+:[^{]*\bLumiPlugin\b[^{]*\{", source)
    if not enum_match:
        return source
    start = enum_match.end()
    depth = 1
    index = start
    while index < len(source) and depth > 0:
        char = source[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
        index += 1
    end = index - 1
    return source[:end] + method + "\n" + source[end:]


def process_file(path: Path) -> bool:
    source = path.read_text()
    if ABOUT_METHOD_MARKER in source:
        return False
    if "LumiPlugin" not in source:
        return False
    if not re.search(r"(?:public )?enum \w+:[^{]*\bLumiPlugin\b", source):
        return False
    policy_match = re.search(r"policy.*?=\s*\.(\w+)", source)
    if not policy_match or policy_match.group(1) == "alwaysOn":
        return False

    display_name = extract_string_literal(source, "displayName") or path.parent.parent.name.replace("Plugin", "")
    description = extract_string_literal(source, "description") or ""
    icon = extract_icon(source)
    kind = plugin_kind(path, source)
    features, steps, tips = content_for(kind, display_name, description, icon)
    method = render_about_method(features, steps, tips)
    updated = ensure_imports(source)
    updated = insert_about_method(updated, method)
    path.write_text(updated)
    return True


def main() -> None:
    changed: list[str] = []
    for path in sorted(PLUGINS_DIR.glob("*/Sources/**/*.swift")):
        if process_file(path):
            changed.append(str(path.relative_to(ROOT)))
    print(f"Updated {len(changed)} plugin files")
    for item in changed:
        print(item)


if __name__ == "__main__":
    main()
