# View 阴影扩展使用示例

## 基本用法

```swift
// 为任意 View 添加阴影
Text("Hello")
    .shadowMd()

// 链式调用
VStack {
    Text("Content")
}
.padding()
.background(Color.white)
.cornerRadius(8)
.shadowLg()
```

## 所有可用的阴影级别

```swift
view.shadowNone()   // 无阴影
view.shadowXs()     // 极轻微
view.shadowSm()     // 轻微
view.shadowMd()     // 中等
view.shadowLg()     // 较强
view.shadowXl()     // 强
view.shadowXxl()    // 极强
view.shadowXxxl()   // 超强
```

## 在 AppToolbarContainer 中使用

之前的用法（已废弃）：

```swift
AppToolbarContainer(bottomShadowLevel: .md) {
    Text("Content")
}
```

现在的用法：

```swift
AppToolbarContainer {
    Text("Content")
}
.shadowMd()
```

## 优势

1. **通用性**：可以用于任何 SwiftUI View
2. **灵活性**：不再局限于特定组件
3. **一致性**：统一的阴影标准，整个应用保持视觉一致
4. **易用性**：简洁的链式调用语法
