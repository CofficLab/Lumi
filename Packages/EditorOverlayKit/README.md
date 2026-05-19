# EditorOverlayKit

可复用的 SwiftUI 编辑器浮层组件包。提供悬停卡片、Code Action、Peek、行内重命名、装订线装饰、表面高亮、辅助光标与行内展示等 overlay 视图。

## Package

- Product: `EditorOverlayKit`
- Platform: macOS 14+
- Swift tools: 6.0
- Local dependencies: `EditorService`, `EditorKernel`, `MarkdownKit`, `LumiUI`

## Source Layout

- `EditorHoverOverlayView`
- `EditorCodeActionOverlayView`
- `EditorPeekOverlayView`
- `EditorInlineRenameOverlayView`
- `EditorGutterDecorationsOverlayView`
- `EditorSurfaceHighlightsOverlayView`
- `EditorSecondaryCursorOverlayView`
- `EditorInlinePresentationsOverlayView`

## Host integration

This package is UI-focused. It depends on editor state and reusable UI packages, but does not own host-level plugin registration, command routing, or persistence.

## Testing

There is currently no package test target. For future changes, prefer extracting placement and sizing logic into small pure helpers that can be unit tested without rendering SwiftUI views.
