# FilePreviewKit

可复用的 macOS 文件预览 SwiftUI 组件包。支持图片、PDF 与 Quick Look 预览。

## Package

- Product: `FilePreviewKit`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

- 根据文件类型自动选择预览方式（图片 / PDF / Quick Look）
- SwiftUI `FilePreviewView` 组件，供宿主嵌入使用

## 依赖与集成

```swift
dependencies: [
    .package(path: "../FilePreviewKit"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["FilePreviewKit"]),
]
```

## 基本用法

```swift
import SwiftUI
import FilePreviewKit

struct PreviewScreen: View {
    let fileURL: URL

    var body: some View {
        FilePreviewView(fileURL: fileURL)
    }
}
```
