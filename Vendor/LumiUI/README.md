# LumiUI

<div align="center">

**✨ A polished SwiftUI design system for macOS, iOS and visionOS applications**

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-macOS%2014%2B%20%7C%20iOS%2017%2B%20%7C%20visionOS%201%2B-blue.svg)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

📖 English | [中文](README_zh.md)

[Features](#-features) • [Getting Started](#-getting-started) • [Components](#-components) • [Design System](#-design-system) • [Development](#-development)

</div>

---

LumiUI is a standalone Swift Package containing reusable SwiftUI design tokens, components, charts, themes, and supporting views. It has no dependency on the Lumi application or any local package, so it can be integrated into independent macOS, iOS and visionOS projects.

## 🌟 Features

### 🎨 A cohesive design system

- Design tokens for colors, typography, spacing, corner radii, materials, shadows, and animation durations
- Light and dark appearance support with adaptive colors
- A consistent glass-inspired visual language
- Customizable themes through `LumiUITheme`
- Motion preferences and accessibility-conscious defaults

## 🧩 Components

### Reusable components

The package provides 30+ ready-to-use SwiftUI components, including:

| Category | Components |
| --- | --- |
| Controls | `AppButton`, `AppIconButton`, `AppCircularIconButton`, `AppInputField`, `AppSearchBar`, `AppSegmentedControl`, `AppPlaybackProgressBar` |
| Identity and labels | `AppAvatar`, `AppTag`, `AppRoleBadge`, `AppSizeLabel`, `GlassBadge` |
| Cards and surfaces | `AppCard`, `GlassInfoCard`, `GlassSelectionCard`, `AppDisclosureCard`, `AppSurface` |
| Lists and settings | `AppListRow`, `AppToggleRow`, `AppSettingRow`, `AppSettingSection`, `AppSidebarRow` |
| Feedback and layout | `AppEmptyState`, `AppErrorBanner`, `AppLoadingOverlay`, `AppSkeletonBlock`, `AppSkeletonText`, `AppDivider`, `AppLabeledDivider`, `AppTooltip` |
| Content and charts | `AppHTTPResponseView`, `AppImagePreviewGrid`, `AppLineChart`, `AppBarChart`, `AppActivityHeatmap`, `MessageBubble` |
| Media and utilities | `AppPlaybackControlButtonStyle`, `AppResponsivePlayerLayoutMetrics`, `AppDebugBadgeModifier` |
| Product scaffolding | Settings, onboarding, landing-page, menu-bar, and status-bar building blocks |

### Media controls

LumiUI includes reusable playback controls for apps that need a seek bar and responsive player sizing:

```swift
AppPlaybackProgressBar(currentTime: $currentTime, duration: duration) { time in
    player.seek(to: time)
}

Image(systemName: "play.fill")
    .appPlaybackControlButton(accessibilityLabel: "Play") {
        player.play()
    }

let layout = AppResponsivePlayerLayoutMetrics()
let showSecondaryColumn = layout.shouldShowSecondaryColumn(width: windowWidth)
```

`AppPlaybackProgress` exposes the same finite-value normalization, seeking, and time-formatting rules independently of the slider. `appDebugBadge(_:)` adds a deterministic label and outline in debug builds and has no visual effect in release builds.

### Symbols and view utilities

`AppSymbol` names the SF Symbols the library uses most, so a glyph is declared once instead of being retyped as a string literal at every call site. The `Image` extension offers ready-made accessors for the common ones.

```swift
Image(systemName: AppSymbol.musicLibrary)
Image.appClose
```

A small set of view modifiers covers the layout and interaction boilerplate that otherwise repeats across every feature package:

```swift
content
    .appIf(isSelected)
    .appRoundedMedium()
    .appHoverScale(1.05)

VStack { AppButton("Play") { player.play() } }
    .appFillAvailableSpace()
```

| Modifier | Purpose |
| --- | --- |
| `appIf(_:)` | Render conditionally; also has `otherwise:` and `transform:` forms |
| `appFillAvailableSpace()` / `appFillAvailableHeight()` | Expand into the space the parent offers |
| `appVStackCenter()` / `appHStackCenter()` | Center within the parent axis |
| `appRounded(radius:)` / `appRoundedMedium()` / `appRoundedLarge()` | Clip to a token-driven radius |
| `appPlainButton(_:)` | Wrap a view as a borderless button |
| `appHoverScale(_:duration:)` | Grow on hover, honoring reduced motion (macOS) |
| `appScrollView(axes:showsIndicators:contentInsets:)` | Scrollable container with optional content insets |
| `appShadow(_:)` and `shadowNone()`…`shadowXxxl()` | Shadow levels from `AppShadowLevel` |

### Loading placeholders

Compose placeholders to match the shape of the content being loaded. `AppSkeletonBlock` supports rectangle, rounded rectangle, capsule, and circle silhouettes; `AppSkeletonText` takes line-width ratios. Both use the current theme and LumiUI's motion-aware shimmer.

```swift
VStack(alignment: .leading, spacing: 8) {
    AppSkeletonBlock(width: 28, height: 28, shape: .circle)
    AppSkeletonText(lineWidths: [1, 0.68])
}
```

### Activity heatmaps

Pass daily activity levels and a visible date range. Missing dates render at level zero; aggregation and level selection stay in the feature that owns the data.

```swift
AppActivityHeatmap(
    days: dailyActivity.map { day in
        AppActivityHeatmapDay(date: day.date, level: day.level, accessibilityLabel: day.label)
    },
    range: startDate...endDate,
    calendar: calendar,
    showsWeekdayLabels: true,
    showsLegend: true
)
```

## 🚀 Getting Started

### Requirements

- macOS 14 or later
- iOS 17 or later
- visionOS 1 or later
- Swift 6.0 or later
- Xcode with Swift 6 support

### Add the package in Swift Package Manager

Add LumiUI to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1")
]
```

Then add `LumiUI` to the target that uses it:

```swift
targets: [
    .target(
        name: "MyApp",
        dependencies: ["LumiUI"]
    )
]
```

In Xcode, you can also choose **File > Add Package Dependencies** and enter the repository URL.

### Basic usage

```swift
import LumiUI
import SwiftUI

struct ContentView: View {
    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Text("Hello, LumiUI")
                    .font(DesignTokens.Typography.title1)

                AppButton(
                    "Continue",
                    systemImage: "arrow.right",
                    style: .primary
                ) {
                    // Handle the action
                }
            }
        }
        .padding()
    }
}
```

## 🎭 Design System

### Design tokens

Use the shared tokens to keep spacing and visual hierarchy consistent:

```swift
VStack(spacing: DesignTokens.Spacing.lg) {
    Text("A consistent interface")
        .font(DesignTokens.Typography.headline)
}
```

Available token groups include `Spacing`, `Radius`, `Typography`, `Material`, `Shadow`, and `Duration`. They are available through `DesignTokens` and the `AppUI` shorthand namespace. Color tokens adapt to the current color scheme and are available through `ColorTokens`.

### Themes

Use the built-in theme or provide a custom `LumiUITheme` to a view hierarchy:

```swift
struct ThemedView: View {
    @LumiTheme private var theme

    var body: some View {
        Text("Themed content")
            .foregroundStyle(theme.textPrimary)
    }
}
```

`LumiDefaultTheme` is used by default. Themes can be updated with `setTheme(_:)` when an application needs its own visual identity.

### Localization

LumiUI includes its localization resources and runtime support through `LumiUILocalization`. The package can be used independently without the Lumi application's localization package.

## 🗂 Project Structure

```text
Sources/
├── Charts/          # Chart primitives and visualizations
├── Components/      # Reusable SwiftUI components
├── DesignSystem/    # Tokens, colors, materials, and motion
├── Support/         # Localization and package support
└── Theme/           # Theme definitions and environment support
Tests/               # Package tests
Resources/           # Localization resources
```

## 🛠 Development

Clone the repository and run the package checks:

```bash
git clone https://github.com/CofficLab/LumiUI.git
cd LumiUI
swift package dump-package
swift test
```

When adding a component, prefer the existing design tokens and theme environment so new views remain consistent with the rest of the package.

## 🤝 Contributing

Issues and pull requests are welcome. Please keep public APIs documented, add or update tests for behavior changes, and preserve macOS, iOS and visionOS compatibility where applicable.

## 📄 License

LumiUI is released under the [MIT License](LICENSE).

## 🚀 Projects Using LumiUI

- [Lumi](https://github.com/CofficLab/Lumi) — an AI-powered personal desktop assistant for macOS.
- [GitOK](https://github.com/CofficLab/GitOK) — a macOS project and Git management tool.

## 🔗 Links

- [LumiUI on GitHub](https://github.com/CofficLab/LumiUI)
- [Lumi — the host application](https://github.com/CofficLab/Lumi)

<div align="center">

Made with ❤️ by [CofficLab](https://github.com/CofficLab)

</div>
