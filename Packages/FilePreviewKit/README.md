# FilePreviewKit

Lumi 内部的文件预览组件（SwiftPM 包）。

## 提供什么

- **按文件类型选择预览方式**：图片、PDF 等走原生渲染，其他类型可回退到系统 Quick Look。
- **SwiftUI 预览视图封装**：对上层提供可复用的预览 View。

## 使用方式

在其他 SwiftPM 包的 `Package.swift` 中添加依赖：

```swift
.package(path: "../FilePreviewKit")
```

然后在目标依赖中引入：

```swift
.product(name: "FilePreviewKit", package: "FilePreviewKit")
```

## 运行测试

```bash
cd Packages/FilePreviewKit
swift test
```

