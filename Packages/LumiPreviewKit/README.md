# LumiPreviewKit

SwiftUI 预览发现、构建规划、渲染与宿主进程支持库。扫描 `#Preview`、规划并执行构建、启动预览宿主进程、交换渲染消息，并支持图片与实时预览显示模式。

## Package

- Products:
  - `LumiPreviewKit` (library)
  - `LumiPreviewHostApp` (executable)
- Platform: macOS 14+
- Swift tools: 6.0

## Source Layout

- `Sources/LumiPreviewKit/Core`: shared preview models, errors, session protocol, and render configuration.
- `Sources/LumiPreviewKit/Scanner`: Swift source scanning for `#Preview`.
- `Sources/LumiPreviewKit/Compiler`: SwiftPM and Xcode compiler adapters plus build planning.
- `Sources/LumiPreviewKit/Build`: preview entry generation, incremental build pipeline, syntax checks, and build caches.
- `Sources/LumiPreviewKit/Host`: preview host process management and host protocol messages.
- `Sources/LumiPreviewKit/Frames`: image loading, frame transport, and shared-memory frame storage.
- `Sources/LumiPreviewKit/LiveCanvas`: live canvas window/frame coordination helpers.
- `Sources/LumiPreviewKit/Runtime`: preview engine orchestration and prewarm ranking.
- `Sources/LumiPreviewKit`: embedded inline preview surface, session, host connection, and input forwarding.
- `Sources/LumiPreviewHostApp`: executable preview host app for embedded live rendering.

## Main Concepts

- `PreviewScanner`: finds `#Preview` declarations.
- `BuildPlanner`: chooses SwiftPM or Xcode build strategy.
- `SPMCompiler` and `XcodeCompiler`: compile preview artifacts.
- `HotPreviewHostProcess`: manages the preview host lifecycle.
- `HotPreviewEngine`: coordinates discovery, compile, launch, refresh, capture, and live preview updates.

## Testing

From this package directory:

```sh
swift test
```

Tests cover build planning, compilers, preview scanning, host process behavior, refresh policy, display modes, file context caching, live canvas services, and inline preview behavior.

## Host integration

The host app should handle editor UI, plugin wiring, and user interactions. Keep preview planning, compilation, host messages, and runtime coordination in this package.

## Embedding the Preview Host Binary

This package ships a `scripts/embed-inline-preview-host.sh` build script that compiles `LumiPreviewHostApp` and embeds it into the host app bundle at `Contents/Helpers/LumiPreviewHostApp`.

**To add it to your Xcode project:**

1. Select the **Lumi** target → **Build Phases**
2. Click **+** → **New Run Script Phase**
3. Name it `Embed Inline Preview Host`
4. Set the script to:

   ```
   "${SRCROOT}/Packages/LumiPreviewKit/scripts/embed-inline-preview-host.sh"
   ```

5. Drag the new phase **after** the `Resources` phase
6. In the phase settings, add this to **Output Files**:

   ```
   $(TARGET_BUILD_DIR)/$(CONTENTS_FOLDER_PATH)/Helpers/LumiPreviewHostApp
   ```

7. Check **Run script: Based on dependency analysis** so it only re-runs when needed
