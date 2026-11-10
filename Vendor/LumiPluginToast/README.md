# LumiPluginToast

`LumiPluginToast` is the shared Toast implementation for Lumi-family apps.
It turns the `ProviderToast` contract into a reusable UI plugin that works on
macOS and iOS.

## Capabilities

- replacement-style Toast display with configurable duration;
- automatic dismissal with a three-second default;
- top-level root overlay mounting through `ProviderRootView`;
- persistent error notices with scrolling, text selection, copying, and an
  explicit close action;
- optional Docs/about-page registration through `ProviderDocsView`;
- LumiUI theme, motion, spacing, and status-banner integration;
- English-first package localization with LumiLocalization fallback.

The plugin remains independent of any application-specific root layout. If a
host does not register `RootViewProviding`, it still receives the functional
`ToastProviding` implementation; only automatic UI mounting is skipped.

## Usage

Add the package and register `ToastSuperPlugin` in the host's plugin factory:

```swift
.package(url: "https://github.com/CofficLab/LumiPluginToast.git", from: "1.0.0")
```

```swift
import PluginToast

ToastSuperPlugin()
```

Application plugins should depend on `ProviderToast`, not on this UI plugin.
They can then call `show`, `presentError`, and `dismissError` through the
provider contract without coupling to the renderer.

## Development

```sh
swift test
```
