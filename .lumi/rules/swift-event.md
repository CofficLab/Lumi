# Swift 事件处理规范

> 本规范定义了 Lumi 项目中 Swift 代码的事件处理和状态管理规范。

---

## 核心原则

**事件处理清晰，状态管理一致，避免内存泄漏和竞态条件。**

---

## 事件处理模式

### Combine 框架

```swift
import Combine

class ViewModel: ObservableObject {
    @Published var data: [Item] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 订阅
        dataService.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.data = items
            }
            .store(in: &cancellables)
    }
}
```

### async/await

```swift
@MainActor
class ViewModel: ObservableObject {
    @Published var data: [Item] = []
    
    func loadData() async {
        do {
            data = try await dataService.fetchItems()
        } catch {
            handleError(error)
        }
    }
}
```

---

## 状态管理

### ObservableObject

```swift
@MainActor
class ViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: Error?
    @Published var items: [Item] = []
}
```

### State/Binding (SwiftUI)

```swift
struct MyView: View {
    @State private var searchText = ""
    @StateObject private var viewModel = ViewModel()
    @Binding var isSelected: Bool
    
    var body: some View {
        // 视图内容
    }
}
```

---

## 内存管理

### 弱引用

```swift
// ✅ 好：避免循环引用
Task { [weak self] in
    self?.updateUI()
}

// ✅ 好：在闭包中
buttonAction = { [weak self] in
    self?.handleTap()
}
```

### 取消订阅

```swift
class ViewModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    
    deinit {
        // Combine 订阅会自动清理，但明确清理是好习惯
        cancellables.removeAll()
    }
}
```

---

## 错误处理

```swift
do {
    try await performTask()
} catch let error as MyError {
    handleError(error)
} catch {
    handleGenericError(error)
}
```

---

## 相关规范

- [代码组织规范](./swift-code-organization.md)
- [日志记录规范](./swift-log.md)
- [最少功能原则](./minimal-functionality.md)
