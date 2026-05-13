# EditorOverlayKit

SwiftUI overlay components for Lumi editor surfaces.

`EditorOverlayKit` contains reusable editor overlay views that render hover cards, code actions, peek panels, inline rename controls, gutter decorations, surface highlights, secondary cursors, and inline presentations.

## Package

- Product: `EditorOverlayKit`
- Platform: macOS 14+
- Swift tools: 6.0
- Local dependencies: `EditorService`, `EditorKernelCore`, `MarkdownKit`, `LumiUI`
- Remote dependency: `MagicKit`

## Source Layout

- `EditorHoverOverlayView`
- `EditorCodeActionOverlayView`
- `EditorPeekOverlayView`
- `EditorInlineRenameOverlayView`
- `EditorGutterDecorationsOverlayView`
- `EditorSurfaceHighlightsOverlayView`
- `EditorSecondaryCursorOverlayView`
- `EditorInlinePresentationsOverlayView`

## App Integration

This package is UI-focused. It should depend on editor state and reusable UI packages, but it should not own app-level plugin registration, command routing, or persistence.

## Testing

There is currently no package test target. For future changes, prefer extracting placement and sizing logic into small pure helpers that can be unit tested without rendering SwiftUI views.
