# Swift 注释规范

> 本规范定义了 Lumi 项目中 Swift 代码的注释编写方式和标准。

---

## 核心原则

**注释应当简洁、清晰、有用，解释"为什么"而不是"是什么"。**

---

## 文档注释

### 类型注释

```swift
/// 类型名称
///
/// 类型的功能描述，可以跨多行。
/// 支持 *Markdown* 格式。
///
/// ## 使用示例
///
/// ```swift
/// let instance = TypeName()
/// ```
///
/// - Note: 重要说明
/// - Warning: 警告信息
/// - SeeAlso: 相关类型
class TypeName {
}
```

### 函数注释

```swift
/// 函数功能描述
///
/// 详细说明函数的行为和用途。
///
/// - Parameters:
///   - param1: 参数 1 描述
///   - param2: 参数 2 描述
///
/// - Returns: 返回值描述
///
/// - Throws: 可能抛出的错误
///
/// - Note: 重要说明
func functionName(param1: Type, param2: Type) throws -> ReturnType {
}
```

### 属性注释

```swift
/// 属性描述
var propertyName: Type
```

---

## 行内注释

### 使用规则

```swift
// ✅ 好：解释为什么
if user.isLoggedIn {
    showDashboard()  // 已登录用户显示仪表板
}

// ❌ 避免：重复代码
user.isLoggedIn  // 检查用户是否登录
```

### 待办事项

```swift
// TODO: 实现缓存逻辑
// FIXME: 修复内存泄漏
// NOTE: 这是一个临时解决方案
// HACK: 临时变通方案
```

---

## MARK 注释

用于代码分段组织：

```swift
// MARK: - 初始化

init() {
}

// MARK: - 公开方法

func publicMethod() {
}

// MARK: - 私有方法

private func privateMethod() {
}
```

---

## 相关规范

- [代码组织规范](./swift-code-organization.md)
- [日志记录规范](./swift-log.md)
