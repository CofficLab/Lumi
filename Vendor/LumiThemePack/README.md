# LumiThemePack

Shared theme catalog and theme settings interface for CofficLab applications.

The package depends only on `LumiUI` and the `ProviderTheme` capability from `LumiProviders`. Host apps keep their own Kernel plugin metadata, lifecycle policy, and optional command or documentation contributions.

```swift
import LumiThemePack

LumiThemeRegistration.register(in: themeProvider)
ThemeSettingsDetailView(theme: themeProvider)
let chromeTheme = LumiPaletteChromeTheme(theme: selectedTheme, colorScheme: .dark)
```

To remove the shared themes when a plugin shuts down:

```swift
LumiThemeRegistration.unregister(from: themeProvider)
```
