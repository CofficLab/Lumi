# Settings UI (LumiUI)

All settings surfaces — built-in core tabs, plugin-contributed sidebar tabs, and editor settings rows — must use LumiUI semantic components for consistent chrome and theme tokens.

## Page layout

Use this structure (see `PluginSettingsScaffold`):

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

## Plugin-contributed settings tabs

Plugins can extend the **Settings window sidebar** with their own tabs by returning `settingsTabItems(kernel:)` from the `LumiPlugin` protocol. Hosted at:

`Packages/LumiKernel/Sources/LumiKernel/Contracts/LumiPlugin.swift`

Plugin-contributed tabs are **rendered flat after the four built-in tabs** (General / Appearance / Plugins / About) and registered through `kernel.settings?.registerSettingsTabItem(_:)`. The host view (`SettingsView`) re-renders on register/unregister via the kernel's observable forwarding.

### Template

```swift
import LumiKernel
import LumiUI
import SwiftUI

public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] {
    [
        SettingsTabItem(
            id: "com.mycompany.myplugin.main",
            title: LumiLocalization.string("My Plugin", bundle: .module),
            systemImage: "puzzlepiece.extension",
            content: {
                PluginSettingsScaffold(
                    LumiLocalization.string("My Plugin", bundle: .module),
                    subtitle: LumiLocalization.string(
                        "Configure integration options.", bundle: .module
                    )
                ) {
                    AppCard {
                        AppSettingsSection(
                            title: LumiLocalization.string("General", bundle: .module)
                        ) {
                            AppSettingsToggleRow(
                                LumiLocalization.string("Enable sync", bundle: .module),
                                isOn: $syncEnabled
                            )
                            AppSettingsPickerRow(
                                LumiLocalization.string("Theme", bundle: .module),
                                selection: $themeChoice,
                                options: [
                                    LumiLocalization.string("Light", bundle: .module),
                                    LumiLocalization.string("Dark", bundle: .module),
                                    LumiLocalization.string("Auto", bundle: .module),
                                ]
                            )
                        }
                    }
                }
            }
        )
    ]
}
```

### Rules

- **`id` must be globally unique** within `kernel.settings?.allSettingsTabItems`. Use a reverse-DNS namespace (e.g. `com.mycompany.myplugin.main`). Collisions are last-wins.
- **`title` is shown as-is** in the sidebar — wrap it with `LumiLocalization.string(_:bundle: .module)` so it respects the existing xcstrings catalog.
- **`systemImage` must be a SF Symbol name** (e.g. `"puzzlepiece.extension"`, `"wand.and.stars"`).
- The `content` closure runs on the MainActor; capture `@State` / bindings via the closure (the closure is invoked lazily inside the host view's tab body).
- `pluginAboutView(kernel:)` is still consumed separately inside the **Plugins** built-in tab as a per-plugin detail panel. Use it for "about / author info" rather than duplicating the main settings tab's content.
- `addSettingsView(kernel:) -> [AnyView]` is **not currently consumed by the host UI** — it is reserved for future expansion. New plugins should use `settingsTabItems` instead.

### Reusing `PluginSettingsScaffold`

`PluginSettingsScaffold` (LumiUI) is the recommended wrapper for any plugin-contributed settings tab. It pairs a sticky header card (title + subtitle) with a scrollable content area and keeps your content visually consistent with other plugin tabs.

Do **not** wrap your content in `Form { }` or macOS `Section` — see the "Avoid" list above.
