# Views Should Be Separated into Individual Files

## 规则

每个独立的视图组件应放在自己的 Swift 文件中，而不是作为大型视图文件的私有子视图。

## 原因

- 提高可读性：小文件更容易理解
- 提高可维护性：修改一个视图不会影响其他视图
- 提高可复用性：独立视图可以在其他地方复用
- 更好的 Xcode 预览：每个文件都可以有自己的 `#Preview`

## 示例

**不推荐**：将视图代码全部放在一个大文件中

```swift
struct MainView: View {
    var body: some View {
        // ...
    }
    
    private var subView: some View {
        // 大量子视图代码
    }
    
    private var anotherSubView: some View {
        // 更多代码
    }
}
```

**推荐**：将子视图提取到独立文件

```swift
// MainView.swift
struct MainView: View {
    var body: some View {
        SubView()
    }
}

// SubView.swift
struct SubView: View {
    var body: some View {
        // ...
    }
}
```

## 实际案例

- `EditorPanelView.swift` → 将 `emptyState` 提取为 `EditorEmptyStateView.swift`
