# Issue #012: 中 - IPCConnection 中 delegate 循环引用风险

## 📋 问题概述

`IPCConnection` 类同时持有 `delegate` 的强引用和 `exportedObject`，而 `delegate` 本身也持有 `IPCConnection` 的引用，形成了潜在的循环引用。虽然一端使用了 `weak var delegate`，但另一端的 `exportedObject` 仍然保持强引用，可能导致内存泄漏。

---

## 🟡 严重程度：Medium (中)

**风险等级**: ⚠️ 可能导致：
- IPCConnection 释放时 delegate 无法被释放
- XPC 连接对象无法正确清理
- 长期运行后内存占用增加

**优先级**: P2 - 建议在近期修复

---

## 📍 问题位置

### 文件: `LumiApp/Plugins/NettoPlugin/Bridge/IPCConnection.swift`

| 行号 | 问题代码 |
|------|----------|
| 19 | `weak var delegate: AppCommunication?` |
| 46 | `newListener.delegate = self` |
| 53 | `self.delegate = delegate` |
| 62 | `newConnection.exportedObject = delegate` |

---

## 🐛 问题分析

### 问题代码

```swift
class IPCConnection: NSObject, @unchecked Sendable {
    static let shared = IPCConnection()
    
    var listener: NSXPCListener?
    var currentConnection: NSXPCConnection?
    weak var delegate: AppCommunication?  // ✅ 弱引用
    
    func register(withExtension bundle: Bundle, delegate: AppCommunication, completionHandler: @escaping (Bool) -> Void) {
        self.delegate = delegate  // 存储 delegate 引用
        
        // ...
        
        newConnection.exportedObject = delegate  // ❌ 问题：exportedObject 保持强引用
    }
}
```

### 引用关系分析

```
AppCommunication (如 NettoPlugin)
    ↓ 强引用
    IPCConnection.shared
        ↓ 强引用
        currentConnection (NSXPCConnection)
            ↓ 强引用 (exportedObject)
            AppCommunication
                ↓ 强引用
                ... (可能包含对 IPCConnection 的引用)
```

### 问题场景

虽然 `delegate` 被声明为 `weak`，但：

1. **`exportedObject` 保持强引用**：`NSXPCConnection.exportedObject` 保持对 delegate 的强引用
2. **delegate 可能持有 connection**：如果 AppCommunication 实现类也持有对 IPCConnection 的引用，会形成循环
3. **XPC 生命周期特殊**：NSXPCConnection 的释放时机不确定，可能延迟到应用终止

---

## ✅ 修复方案

### 方案 1: 显式清理连接（推荐）

在适当的时机显式断开连接并清理：

```swift
func cleanup() {
    if let connection = currentConnection {
        connection.invalidate()
    }
    currentConnection = nil
    delegate = nil
}
```

### 方案 2: 使用弱引用包装 delegate

创建一个弱引用包装类：

```swift
class WeakDelegateWrapper {
    weak var delegate: AppCommunication?
}

class IPCConnection: NSObject {
    private var delegateWrapper = WeakDelegateWrapper()
    
    func register(delegate: AppCommunication) {
        delegateWrapper.delegate = delegate
        newConnection.exportedObject = delegateWrapper
    }
}
```

### 方案 3: 确保 delegate 实现类不持有 IPCConnection

审计 delegate 实现类，确保它们不持有 IPCConnection 的强引用。

---

## 📝 修复优先级

| 优先级 | 任务 | 预计工作量 |
|--------|------|-----------|
| **P2** | 审计 AppCommunication 实现类的引用关系 | 2 小时 |
| **P2** | 添加 cleanup 方法并确保调用 | 1 小时 |
| **P3** | 考虑使用弱引用包装 | 2 小时 |

---

## 🔍 审计命令

```bash
# 查找 delegate 实现类
grep -rn "class.*:.*AppCommunication" --include="*.swift" LumiApp/

# 查找持有 IPCConnection 的代码
grep -rn "IPCConnection" --include="*.swift" LumiApp/Plugins/NettoPlugin/
```

---

## 🔄 相关 Issue

- **Issue #005**: NotificationCenter 观察者内存泄漏
- **Issue #010**: Coordinator Task 泄漏

---

**创建日期**: 2026-03-12
**更新日期**: 2026-03-12
**创建者**: DevAssistant (自动分析生成)
**标签**: `bug`, `memory-leak`, `delegate`, `xpc`