# LumiSettings

Shared settings provider contracts and SwiftUI navigation for Coffic applications.

`ProviderSettingView` provides:

- `SettingViewProviding` and `DefaultSettingViewProviding` for registering settings entries.
- A shared macOS settings sidebar and detail shell styled with LumiUI.
- `IOSSettingsNavigationView` for iOS settings navigation. The app host presents it in its window or sheet.
- `ProjectDetailSectionItem` for settings sections contributed by plugins.

Add the package and product dependency:

```swift
.package(url: "https://github.com/CofficLab/LumiSettings.git", from: "1.0.0")
```

```swift
.product(name: "ProviderSettingView", package: "LumiSettings")
```

The package depends on [LumiUI](https://github.com/CofficLab/LumiUI) for shared visual components. Window creation, app navigation bars, and app-specific settings pages remain in the host application.
