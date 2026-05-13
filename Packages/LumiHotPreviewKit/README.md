# LumiHotPreviewKit

`LumiHotPreviewKit` is the experimental hot-preview layer for Lumi's SwiftUI preview workflow.

The package is intentionally separate from `LumiPreviewKit`. The stable preview engine remains the fallback path while hot-preview features are added behind a new API surface.

## Goals

- Keep `LumiPreviewKit` unchanged and available as the reliable fallback.
- Provide a new integration point for `EditorRemotePreviewPlugin`.
- Add Phase 1 performance improvements first:
  - warm and reusable host process management
  - syntax preflight before expensive builds
  - file-based PNG frame loading as a faster alternative to Base64 JSON payloads
  - a hot host bridge that proxies `LumiPreviewHostApp` and rewrites PNG payloads to file paths
  - response models that can later carry shared-memory frame metadata
- Leave Phase 2/3 features, such as single-file incremental compilation and interposing, behind explicit future types instead of mixing them into the initial scaffold.

## Package Layout

```text
Sources/
  LumiHotPreviewKit/
    LumiHotPreviewPackage.swift
    HotPreviewEngine.swift
    HostProcessManager.swift
    HotRenderResponse.swift
    ImageFileLoader.swift
    SyntaxChecker.swift
  LumiHotPreviewHostApp/
    main.swift
Tests/
  LumiHotPreviewKitTests/
```

## Public API

### `HotPreviewEngine`

A facade over `LumiPreviewKit.LivePreviewEngine`. This lets the app switch to the hot-preview package without losing the existing preview behavior.

### `HostProcessManager`

An actor that owns reusable host-process connections. It supports warmup, acquire, release, and shutdown.

### `HotRenderResponse`

A compatibility response that wraps `LumiPreviewKit.RenderResponse` and adds fields for file and shared-memory frame transports.

### `HotPreviewHostProcess`

Launches `LumiHotPreviewHostApp` and speaks the same request protocol as `LumiPreviewKit`, but decodes `HotRenderResponse`.

### `FrameFileStore`

Writes Base64-encoded PNG payloads to temporary files. The current hot host uses this to proxy legacy host responses into file-based frame delivery.

### `ImageFileLoader`

Loads PNG frames from disk with a small LRU cache and cleanup helpers for temporary frame files.

### `SyntaxChecker`

Runs `swiftc -parse` as a fast preflight before launching an expensive preview rebuild.

## Current Status

This package now includes a working bridge host. `LumiHotPreviewHostApp` proxies requests to `LumiPreviewHostApp`, persists any PNG frame payload to a temp file, and returns `imageFilePath` in `HotRenderResponse`.

The package still does not have its own renderer or incremental build pipeline. `HotPreviewEngine` is still a facade over `LumiPreviewKit.LivePreviewEngine`, and the plugin is not wired to use the bridge host yet.

## Testing

Run from this package directory:

```sh
swift test
```
