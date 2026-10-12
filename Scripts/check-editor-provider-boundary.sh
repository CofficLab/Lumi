#!/usr/bin/env bash
set -euo pipefail

workspace_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
packages_root="$workspace_root/Packages"
provider_manifest="$packages_root/ProviderEditor/Package.swift"
provider_sources="$packages_root/ProviderEditor/Sources/EditorContracts"

failures=0

legacy_editor_packages=("$packages_root"/Editor*)
if [[ -e "${legacy_editor_packages[0]}" ]]; then
    printf '%s\n' "Editor packages must use Kit*, Provider*, or Plugin* package names; found legacy package directories:"
    printf '  %s\n' "${legacy_editor_packages[@]}"
    failures=1
fi

editor_packages=(
    ProviderEditor
    KitEditorKernel
    KitEditorLanguageRuntime
    KitEditorSource
    KitEditorTextView
    PluginCodeEditor
    PluginCodeEditorHost
    PluginCodeEditorLanguages
    PluginEditorPreview
)
for package_name in "${editor_packages[@]}"; do
    manifest="$packages_root/$package_name/Package.swift"
    if [[ ! -f "$manifest" ]]; then
        printf 'Expected editor package is missing or misclassified: %s\n' "$package_name"
        failures=1
        continue
    fi
    if ! rg -q --fixed-strings "name: \"$package_name\"" "$manifest"; then
        printf 'Editor package manifest name does not match its category: %s\n' "$package_name"
        failures=1
    fi
done

if [[ -f "$packages_root/EditorService/Package.swift" ]]; then
    printf '%s\n' "EditorService must be an internal target of PluginCodeEditorHost, not a standalone package."
    failures=1
fi

host_manifest="$packages_root/PluginCodeEditorHost/Package.swift"
if [[ -f "$host_manifest" ]] && ! rg -q --fixed-strings 'name: "EditorService"' "$host_manifest"; then
    printf '%s\n' "PluginCodeEditorHost must own the internal EditorService target."
    failures=1
fi

if [[ ! -f "$provider_manifest" ]]; then
    printf '%s\n' "ProviderEditor package manifest is missing."
    exit 1
fi

if rg -n --pcre2 '\.package\(\s*url:' "$provider_manifest"; then
    printf '%s\n' "ProviderEditor must not depend on remote packages."
    failures=1
fi

if rg -n --pcre2 '\.package\(\s*path:\s*"\.\./(?!Kit[^/]*")' "$provider_manifest"; then
    printf '%s\n' "ProviderEditor may only depend on Kit-prefixed local packages."
    failures=1
fi

if rg -n '^(import|@_exported import)\s+(EditorService|EditorSource|EditorKernel|LumiUI|Plugin[A-Z]|Provider[A-Z])\b' \
    "$provider_sources" --glob '*.swift'; then
    printf '%s\n' "ProviderEditor sources must not depend on implementations or business providers."
    failures=1
fi

for package_dir in "$packages_root"/Plugin*; do
    [[ -d "$package_dir" ]] || continue
    package_name="${package_dir##*/}"
    [[ "$package_name" == "PluginCodeEditorHost" ]] && continue
    source_dir="$package_dir/Sources"
    manifest="$package_dir/Package.swift"
    [[ -d "$source_dir" ]] || continue

    if rg -n '^(import|@_exported import)\s+(EditorService|EditorSource|EditorKernel|EditorTextView)\b' \
        "$source_dir" --glob '*.swift'; then
        printf 'Concrete editor implementation imported outside Host: %s\n' "$package_name"
        failures=1
    fi

    if [[ -f "$manifest" ]] && rg -n --pcre2 \
        '\.package\(\s*path:\s*"\.\./(EditorService|KitEditorSource|KitEditorKernel|KitEditorTextView)"|\.product\(name:\s*"(EditorService|EditorSource|EditorKernel|EditorTextView)"\s*,\s*package:\s*"(EditorService|KitEditorSource|KitEditorKernel|KitEditorTextView)"' \
        "$manifest"; then
        printf 'Concrete editor implementation dependency declared outside Host: %s\n' "$package_name"
        failures=1
    fi
done

if (( failures != 0 )); then
    exit 1
fi

printf '%s\n' "Editor provider dependency boundaries are clean."
