#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

TARGET_DIR="${1:-LumiApp}"
TOP_LIMIT="${TOP_LIMIT:-12}"

if ! command -v rg >/dev/null 2>&1; then
    echo "error: ripgrep (rg) is required" >&2
    exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo "error: target directory does not exist: $TARGET_DIR" >&2
    exit 1
fi

declare -a CHECK_NAMES=(
    "Color.adaptive"
    "Color(hex:)"
    ".font(.system...)"
    "RoundedRectangle"
    ".cornerRadius(...)"
    "activeChromeTheme workspace colors"
    "Native foregroundColor"
    "Native background"
)

declare -a CHECK_PATTERNS=(
    'Color\.adaptive'
    'Color\(hex:'
    '\.font\(\.system'
    'RoundedRectangle'
    '\.cornerRadius\('
    'activeChromeTheme\.[A-Za-z0-9_]*Color\('
    '\.foregroundColor\('
    '\.background\('
)

count_hits() {
    local pattern="$1"
    rg -n "$pattern" "$TARGET_DIR" \
        --glob '*.swift' \
        --glob '!**/Marketing/**' \
        --glob '!**/ThirdParty/**' \
        --glob '!**/Plugins/Theme*Plugin/*Theme.swift' \
        --glob '!*.generated.swift' \
        2>/dev/null | wc -l | tr -d ' '
}

count_files() {
    local pattern="$1"
    rg -l "$pattern" "$TARGET_DIR" \
        --glob '*.swift' \
        --glob '!**/Marketing/**' \
        --glob '!**/ThirdParty/**' \
        --glob '!**/Plugins/Theme*Plugin/*Theme.swift' \
        --glob '!*.generated.swift' \
        2>/dev/null | wc -l | tr -d ' '
}

top_files() {
    local pattern="$1"
    rg -n "$pattern" "$TARGET_DIR" \
        --glob '*.swift' \
        --glob '!**/Marketing/**' \
        --glob '!**/ThirdParty/**' \
        --glob '!**/Plugins/Theme*Plugin/*Theme.swift' \
        --glob '!*.generated.swift' \
        2>/dev/null \
        | cut -d: -f1 \
        | sort \
        | uniq -c \
        | sort -nr \
        | head -n "$TOP_LIMIT" \
        | awk '{count=$1; $1=""; sub(/^ /, ""); printf "- `%s` - %s\n", $0, count}'
}

category_for_path() {
    local path="$1"

    case "$path" in
        LumiApp/Core/Views/Layout/*) echo "Core Layout" ;;
        LumiApp/Core/Views/Settings/*) echo "Core Settings" ;;
        LumiApp/Core/Views/*) echo "Core Views" ;;
        LumiApp/Plugins/AgentMessageRendererPlugin/*|LumiApp/Plugins/ChatMessagesPlugin/*|LumiApp/Plugins/ChatAttachmentPlugin/*|LumiApp/Plugins/ChatPendingMessagesPlugin/*) echo "Chat" ;;
        LumiApp/Plugins/*StatusBarPlugin/*|LumiApp/Plugins/*/Views/*StatusBar*|LumiApp/Plugins/*/Views/*MenuBar*) echo "Status/Menu Bar" ;;
        LumiApp/Plugins/*EditorPlugin/*|LumiApp/Plugins/Editor*Plugin/*|LumiApp/Plugins/LSP*EditorPlugin/*) echo "Editor Plugins" ;;
        LumiApp/Plugins/*) echo "Other Plugins" ;;
        *) echo "Other" ;;
    esac
}

category_summary() {
    local pattern="$1"

    rg -n "$pattern" "$TARGET_DIR" \
        --glob '*.swift' \
        --glob '!**/Marketing/**' \
        --glob '!**/ThirdParty/**' \
        --glob '!**/Plugins/Theme*Plugin/*Theme.swift' \
        --glob '!*.generated.swift' \
        2>/dev/null \
        | cut -d: -f1 \
        | while IFS= read -r path; do category_for_path "$path"; done \
        | sort \
        | uniq -c \
        | sort -nr \
        | awk '{count=$1; $1=""; sub(/^ /, ""); printf "- %s: %s\n", $0, count}'
}

swift_file_count=$(find "$TARGET_DIR" -name '*.swift' \
    -not -path '*/Marketing/*' \
    -not -path '*/ThirdParty/*' \
    -not -path '*/Plugins/Theme*Plugin/*Theme.swift' \
    -not -name '*.generated.swift' \
    | wc -l | tr -d ' ')

lumiui_import_count=$(rg -l '^import LumiUI' "$TARGET_DIR" \
    --glob '*.swift' \
    --glob '!**/Marketing/**' \
    --glob '!**/ThirdParty/**' \
    --glob '!**/Plugins/Theme*Plugin/*Theme.swift' \
    --glob '!*.generated.swift' \
    2>/dev/null | wc -l | tr -d ' ')

echo "# LumiUI Style Audit"
echo
echo "- Target: \`$TARGET_DIR\`"
echo "- Swift files scanned: $swift_file_count"
echo "- Files importing \`LumiUI\`: $lumiui_import_count"
echo "- Excluded: \`**/Marketing/**\`, \`**/ThirdParty/**\`, \`**/Plugins/Theme*Plugin/*Theme.swift\`, \`*.generated.swift\`"
echo
echo "## Summary"
echo
echo "| Check | Hits | Files |"
echo "| --- | ---: | ---: |"

for i in "${!CHECK_NAMES[@]}"; do
    name="${CHECK_NAMES[$i]}"
    pattern="${CHECK_PATTERNS[$i]}"
    echo "| $name | $(count_hits "$pattern") | $(count_files "$pattern") |"
done

echo
echo "## Category Summary"

for i in "${!CHECK_NAMES[@]}"; do
    name="${CHECK_NAMES[$i]}"
    pattern="${CHECK_PATTERNS[$i]}"
    echo
    echo "### $name"
    category_summary "$pattern"
done

echo
echo "## Top Files"

for i in "${!CHECK_NAMES[@]}"; do
    name="${CHECK_NAMES[$i]}"
    pattern="${CHECK_PATTERNS[$i]}"
    echo
    echo "### $name"
    top_files "$pattern"
done
