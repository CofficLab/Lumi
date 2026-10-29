# Swift 标记规范

> 本规范定义了 Lumi 项目中 Swift 代码的标记（MARK）使用方式和标准。

---

## 核心原则

**使用 MARK 注释组织代码结构，提高代码可读性和导航效率。**

---

## MARK 语法

### 带分隔线的 MARK

```swift
// MARK: - 初始化
// MARK: - 公开方法
// MARK: - 私有方法
```

### 不带分隔线的 MARK

```swift
// MARK: 数据加载
// MARK: 事件处理
```

---

## 标准分段顺序

### 类/结构体/Actor

```swift
class MyClass {
    
    // MARK: - 常量/静态属性
    
    // MARK: - 单例
    
    // MARK: - 属性
    
    // MARK: - 初始化
    
    // MARK: - 生命周期
    
    // MARK: - 公开方法
    
    // MARK: - 内部方法
    
    // MARK: - 私有方法
    
    // MARK: - 计算属性
    
    // MARK: - 数据源方法
    
    // MARK: - 代理方法
    
    // MARK: - 通知处理
}
```

### 扩展

```swift
// MARK: - UITableViewDataSource

extension MyViewController: UITableViewDataSource {
}

// MARK: - UITableViewDelegate

extension MyViewController: UITableViewDelegate {
}
```

---

## 使用规则

### ✅ 推荐

- 每个主要功能块使用 `// MARK: - 标题`
- 相关方法之间可用 `// MARK:` 分组
- 分段之间保留一个空行
- 使用有意义的标题名称

### ❌ 避免

- 过度细分（每个方法都用 MARK）
- 标题不明确
- 忘记添加空行

---

## 常见 MARK 标题

| 标题 | 用途 |
|------|------|
| `// MARK: - 初始化` | 初始化方法 |
| `// MARK: - 公开方法` | Public 方法 |
| `// MARK: - 私有方法` | Private 方法 |
| `// MARK: - 属性` | 属性定义 |
| `// MARK: - 计算属性` | Computed Properties |
| `// MARK: - 代理方法` | Delegate Methods |
| `// MARK: - 数据源方法` | DataSource Methods |
| `// MARK: - 通知处理` | Notification Handlers |
| `// MARK: - 预览` | #Preview |

---

## 示例

```swift
class UserManager: ObservableObject {
    
    // MARK: - 单例
    
    static let shared = UserManager()
    
    // MARK: - 属性
    
    @Published var users: [User] = []
    
    // MARK: - 初始化
    
    private init() {
        loadUsers()
    }
    
    // MARK: - 公开方法
    
    func addUser(_ user: User) {
        // ...
    }
    
    // MARK: - 私有方法
    
    private func loadUsers() {
        // ...
    }
    
    // MARK: - 计算属性
    
    private var userCount: Int {
        users.count
    }
}

// MARK: - 预览

#Preview {
    UserListView()
}
```

---

## 相关规范

- [代码组织规范](./swift-code-organization.md)
- [注释规范](./swift-comment.md)
