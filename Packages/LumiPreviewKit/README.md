# LumiPreviewKit

SwiftUI preview discovery, build planning, rendering, and host process support for Lumi.

`LumiPreviewKit` powers editor preview workflows. It scans Swift source for `#Preview`, plans and performs builds, starts a preview host process, exchanges render messages, and supports image and live preview display modes.

## Package

- Products:
  - `LumiPreviewKit`
  - `LumiPreviewHostApp`
- Platform: macOS 14+
- Swift tools: 6.0

## Source Layout

- `Sources/LumiPreviewKit`: preview discovery, build planning, compilers, host process management, refresh policies, session state, and display models.
- `Sources/LumiPreviewHostApp`: executable host app that renders preview entries and communicates over stdio.

## Main Concepts

- `PreviewScanner`: finds `#Preview` declarations.
- `BuildPlanner`: chooses SwiftPM or Xcode build strategy.
- `SPMCompiler` and `XcodeCompiler`: compile preview artifacts.
- `PreviewHostProcess`: manages the render host lifecycle.
- `LivePreviewEngine`: coordinates discovery, compile, launch, refresh, capture, and live preview updates.

## Testing

From this package directory:

```sh
swift test
```

The test suite covers build planning, compilers, preview scanning, host process behavior, refresh policy, display modes, file context caching, and live canvas services.

## App Integration

The app target should handle editor UI, plugin wiring, and user interactions. Keep preview planning, compilation, host messages, and runtime coordination in this package.
