#!/usr/bin/env python3
"""Regenerate EditorExtensionPluginRegistry imports and plugin list."""

from __future__ import annotations

import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLUGINS_DIR = os.path.join(ROOT, "Plugins")
REGISTRY = os.path.join(
    ROOT,
    "Packages/LumiPluginRegistry/Sources/LumiPluginRegistry/EditorExtensionPluginRegistry.swift",
)

# Non-language editor extension plugins (fixed order prefix)
INFRA_PLUGINS = [
    "EditorSwiftPlugin",
    "LSPServiceEditorPlugin",
    "LSPRealtimeSignalsPlugin",
    "LSPSheetsEditorPlugin",
    "LSPToolbarEditorPlugin",
    "LSPCodeActionEditorPlugin",
    "LSPCallHierarchyEditorPlugin",
    "LSPWorkspaceSymbolEditorPlugin",
    "LSPDocumentHighlightEditorPlugin",
    "LSPInlayHintEditorPlugin",
    "LSPSignatureHelpEditorPlugin",
    "LSPFoldingRangeEditorPlugin",
    "LSPDocumentColorEditorPlugin",
    "LSPDocumentLinkEditorPlugin",
    "LSPSelectionRangeEditorPlugin",
    "EditorLSPContextCommandsPlugin",
    "EditorChatIntegrationPlugin",
    "EditorMinimapContextMenuPlugin",
    "EditorMultiCursorCommandsPlugin",
]

# Rich language plugins
RICH_LANGUAGE_PLUGINS = [
    "EditorJSPlugin",
    "EditorGoPlugin",
    "EditorHTMLPlugin",
    "EditorCSSPlugin",
    "EditorMarkdownPlugin",
]

# Package name -> LumiEditorExtensionRegistering type when they differ
REGISTERING_TYPE_OVERRIDES: dict[str, str] = {
    "EditorSwiftPlugin": "EditorSwiftEditorPlugin",
}


def registering_type(package_name: str) -> str:
    return REGISTERING_TYPE_OVERRIDES.get(package_name, package_name)


# Highlight-only plugins (sorted)
HIGHLIGHT_PREFIX = "Editor"
HIGHLIGHT_SUFFIX = "Plugin"


def has_grammar_provider(sources_dir: str) -> bool:
    for _root, _dirs, files in os.walk(sources_dir):
        if any(f.endswith("GrammarProvider.swift") for f in files):
            return True
    return False


def discover_highlight_plugins() -> list[str]:
    result = []
    for name in sorted(os.listdir(PLUGINS_DIR)):
        if not name.startswith(HIGHLIGHT_PREFIX) or not name.endswith(HIGHLIGHT_SUFFIX):
            continue
        if name in INFRA_PLUGINS or name in RICH_LANGUAGE_PLUGINS:
            continue
        plugin_dir = os.path.join(PLUGINS_DIR, name)
        if not os.path.isdir(plugin_dir):
            continue
        sources = os.path.join(plugin_dir, "Sources")
        if os.path.isdir(sources) and has_grammar_provider(sources):
            result.append(name)
    return result


def main() -> None:
    all_plugins = INFRA_PLUGINS + RICH_LANGUAGE_PLUGINS + discover_highlight_plugins()
    imports = "\n".join(f"import {p}" for p in all_plugins)
    entries = "\n        ".join(f"{registering_type(p)}.self," for p in all_plugins)

    content = f"""{imports}
import LumiCoreKit

public enum EditorExtensionPluginRegistry {{
    public static let plugins: [any LumiEditorExtensionRegistering.Type] = [
        {entries}
    ]
}}
"""
    with open(REGISTRY, "w") as f:
        f.write(content)
    print(f"Updated registry with {len(all_plugins)} plugins")


if __name__ == "__main__":
    main()
