# LumiPreviewKit

SwiftUI preview discovery, build planning, rendering, and host process support for Lumi.

`LumiPreviewKit` powers editor preview workflows. It scans Swift source for `#Preview`, plans and performs builds, starts a preview host process, exchanges render messages, and supports image and live preview display modes.

## Package

- Products:
  - `LumiPreviewKit`
  - `LumiInlinePreviewKit`
  - `LumiHotPreviewHostApp`
  - `LumiInlinePreviewHostApp`
- Platform: macOS 14+
- Swift tools: 6.0

## Source Layout

- `Sources/LumiPreviewKit/Core`: shared preview models, errors, session protocol, and render configuration.
- `Sources/LumiPreviewKit/Scanner`: Swift source scanning for `#Preview`.
- `Sources/LumiPreviewKit/Compiler`: SwiftPM and Xcode compiler adapters plus build planning.
- `Sources/LumiPreviewKit/Build`: preview entry generation, incremental build pipeline, syntax checks, and build caches.
- `Sources/LumiPreviewKit/Host`: hot preview host process management and host protocol messages.
- `Sources/LumiPreviewKit/Frames`: image loading, frame transport, and shared-memory frame storage.
- `Sources/LumiPreviewKit/LiveCanvas`: live canvas window/frame coordination helpers.
- `Sources/LumiPreviewKit/Runtime`: `HotPreviewEngine` runtime orchestration and prewarm ranking.
- `Sources/LumiInlinePreviewKit`: embedded inline preview surface, session, host connection, and input forwarding support.
- `Sources/LumiHotPreviewHostApp`: executable hot preview host app that renders preview entries and communicates over stdio.
- `Sources/LumiInlinePreviewHostApp`: executable inline preview host app for embedded live rendering.

## Main Concepts

- `PreviewScanner`: finds `#Preview` declarations.
- `BuildPlanner`: chooses SwiftPM or Xcode build strategy.
- `SPMCompiler` and `XcodeCompiler`: compile preview artifacts.
- `HotPreviewHostProcess`: manages the hot preview host lifecycle.
- `HotPreviewEngine`: coordinates discovery, compile, launch, refresh, capture, and live preview updates.

## Testing

From this package directory:

```sh
swift test
```

The test suite covers build planning, compilers, preview scanning, host process behavior, refresh policy, display modes, file context caching, live canvas services, and inline preview behavior.

## App Integration

The app target should handle editor UI, plugin wiring, and user interactions. Keep preview planning, compilation, host messages, and runtime coordination in this package.
