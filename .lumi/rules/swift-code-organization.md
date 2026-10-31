# Swift 代码组织规范

> 本规范定义了 Lumi 项目中 Swift 文件的代码组织方式和结构约定。

---

## 核心原则

**代码组织清晰，遵循统一的层次结构，便于维护和扩展。**

---

## 文件结构模板

```swift
import Foundation
import SwiftUI

/// 类型名称
///
/// 类型的功能描述
class/struct/actor TypeName {
    
    // MARK: - 常量/静态属性
    
    static let constantName: Type = value
    
    // MARK: - 单例
    
    static let shared = TypeName()
    
    // MARK: - 属性
    
    @Published var propertyName: Type
    
    // MARK: - 初始化
    
    init() {
        // 初始化逻辑
    }
    
    // MARK: - 公开方法
    
    func publicMethod() {
        // 实现
    }
    
    // MARK: - 私有方法
    
    private func privateMethod() {
        // 实现
    }
    
    // MARK: - 计算属性
    
    private var calculatedProperty: Type {
        // 计算逻辑
    }
}

// MARK: - 扩展

extension TypeName: ProtocolName {
    // 协议实现
}

// MARK: - 预览

#Preview("Preview Name") {
    PreviewContent()
}
```

---

## MARK 注释规范

### 标准分段顺序

1. `// MARK: - 常量/静态属性`
2. `// MARK: - 单例`
3. `// MARK: - 属性`
4. `// MARK: - 初始化`
5. `// MARK: - 公开方法`
6. `// MARK: - 私有方法`
7. `// MARK: - 计算属性`
8. `// MARK: - 扩展`
9. `// MARK: - 预览`

### 使用规则

- 每个主要分段使用 `// MARK: - 标题`
- 相关方法之间可用 `// MARK:` 分组（无标题）
- 分段之间保留一个空行

---

## 相关规范

- [最少功能原则](./minimal-functionality.md)
- [日志记录规范](./swift-log.md)
