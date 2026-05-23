# Settings UI (LumiUI)

All settings surfaces (core tabs, plugin `addSettingsView()`, and editor settings rows) must use LumiUI semantic components for consistent chrome and theme tokens.

## Page layout

Use this structure (see `GeneralSettingView`, `PluginSettingsScaffold`):

```swift
PluginSettingsScaffold("Title", subtitle: "…") {
    AppCard {
        AppSettingsSection(title: "Section") {
            AppSettingsToggleRow("Option", isOn: $flag)
        }
    }
}
```

Core tabs without `PluginSettingsScaffold` should still follow: fixed header `AppCard` + `ScrollView` with `AppCard` sections.

## Row components

| Control | Component |
|---------|-----------|
| Toggle | `AppSettingsToggleRow` |
| Stepper | `AppSettingsStepperRow` |
| Menu picker | `AppSettingsPickerRow` |
| Segmented picker | `AppSettingsSegmentedPickerRow` |
| Read-only badge | `AppSettingsReadOnlyRow` |
| Secret / token field | `AppSettingsSecureFieldRow` |
| Custom content | `AppSettingsRow { … }` |

Do **not** use `AppToggleRow` on settings pages (use `AppSettingsToggleRow`).

## Avoid

- `Form { }` / macOS `Section` in settings views
- `Color(hex:)` / `Color.adaptive` for text or backgrounds
- `.font(.system(size: …))` for settings copy (use `.appBody`, `.appCaption`, etc.)
- Bare `List` for settings rows (prefer `AppSettingsRow` in `AppCard`)

## Editor kernel

`EditorService` setting rows (`EditorToggleSettingRow`, etc.) delegate to LumiUI `AppSettings*` rows. New editor extension settings should return `AppSettingsToggleRow` (or siblings) in `EditorSettingsItemSuggestion.content`.

## Plugin settings

Implement `addSettingsView()` with `PluginSettingsScaffold` + `import LumiUI`. Register via `SuperPlugin.addSettingsView()`.
