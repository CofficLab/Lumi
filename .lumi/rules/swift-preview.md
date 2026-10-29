# Swift 预览规范

> 本规范定义了 Lumi 项目中 Swift 代码的预览（#Preview）编写方式和标准。

---

## 核心原则

**每个可预览的视图都应提供预览，便于开发和视觉验证。**

---

## 预览语法

### 基础预览

```swift
#Preview("Preview Name") {
    MyView()
        .frame(width: 300, height: 200)
}
```

### 带环境的预览

```swift
#Preview("With Environment") {
    MyView()
        .environmentObject(GlobalVM())
        .environment(\.colorScheme, .dark)
}
```

### 多个预览

```swift
#Preview("Light Mode") {
    MyView()
}

#Preview("Dark Mode") {
    MyView()
}
.environment(\.colorScheme, .dark)
```

---

## 预览组织

### 在文件末尾

```swift
// MARK: - 预览

#Preview("Preview Name") {
    PreviewContent()
}
```

### 复杂预览

```swift
#Preview("Complex") {
    ContentView()
        .withMockData()
        .frame(minWidth: 600, minHeight: 400)
}
```

---

## 预览辅助

### Mock 数据

```swift
extension MyView {
    static var previewData: [Item] {
        [
            Item(id: 1, name: "Item 1"),
            Item(id: 2, name: "Item 2")
        ]
    }
}

#Preview {
    MyView(items: MyView.previewData)
}
```

### 预览修饰符

```swift
extension View {
    func withMockData() -> some View {
        self
            .environmentObject(MockViewModel())
    }
}
```

---

## 最佳实践

### ✅ 推荐

- 提供有意义的预览名称
- 覆盖常见使用场景
- 使用 Mock 数据而非真实数据
- 保持预览代码简洁

### ❌ 避免

- 预览中调用网络请求
- 预览依赖外部资源
- 过于复杂的预览设置

---

## 相关规范

- [代码组织规范](./swift-code-organization.md)
- [最少功能原则](./minimal-functionality.md)
