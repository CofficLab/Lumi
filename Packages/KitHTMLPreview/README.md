# KitHTMLPreview

A SwiftUI-based HTML preview component powered by `WKWebView`.

## Overview

`KitHTMLPreview` provides a ready-to-use `HTMLPreviewView` that renders HTML content inside a SwiftUI view hierarchy. It supports two loading modes:

- **File-based loading** — pass a `fileURL` to load a local `.html`/`.htm` file. Relative resources (CSS, JS, images) are resolved against the file's directory.
- **String-based loading** — pass an `htmlText` string directly. When a `fileURL` is also provided, relative resources are resolved against the file's parent directory as the base URL.

The view automatically detects whether the in-memory HTML string is still in sync with the on-disk file and loads the file URL directly when possible (better performance and resource resolution).

It can also expose an exact DOM element to the host app. When the element-reference callback is enabled, right-clicking an element shows a native macOS menu containing the hit element and a bounded list of ancestors. Selecting an item returns structured metadata and a compact HTML snapshot; no action is enabled unless the host explicitly opts in.

## Usage

```swift
import KitHTMLPreview
import SwiftUI

// Load from a local file (supports relative resources)
HTMLPreviewView(
    htmlText: htmlSource,
    fileURL: fileURL
)

// Load from a raw HTML string
HTMLPreviewView(
    htmlText: "<h1>Hello, World!</h1>"
)

// Get a reference to the underlying WKWebView (e.g. for screenshots)
HTMLPreviewView(
    htmlText: htmlSource,
    fileURL: fileURL,
    onWebViewResolved: { webView in
        // store reference for later use
    }
)

// Let the user send an exact element (or one of its ancestors) to the host.
HTMLPreviewView(
    htmlText: htmlSource,
    fileURL: fileURL,
    onElementReferenceSelected: { reference in
        // reference.selector, reference.outerHTML, reference.tagName, ...
    },
    isElementReferenceActionEnabled: true
)
```

`onElementReferenceSelected` is independent from the older `onBlockSelected` API. Existing integrations keep their original behavior and script bridge unless they opt in to element references.

## Features

| Feature | Description |
|---------|-------------|
| Live preview | Renders HTML in real time via `WKWebView` |
| File URL support | Loads local files with read access to the parent directory |
| Smart sync check | Detects if the in-memory string matches the file on disk and loads the file URL directly when possible |
| Pinch-to-zoom | `allowsMagnification` is enabled by default |
| Empty state | Displays a placeholder when no HTML content is provided |
| WebView callback | Optional `onWebViewResolved` closure to access the underlying `WKWebView` instance |
| Element references | Optional native context menu for selecting an exact DOM element or ancestor and returning a validated reference |
| Legacy compatibility | The original block-selection callback remains opt-in and independent from element references |

## Platform

- macOS 14.0+
- Swift 6.0+

## License

Private package — part of the Lumi project.
