# Issue #002: 大量使用 @unchecked Sendable 导致并发安全隐患

## 🔴 严重级别：High

## 📋 问题描述

项目中存在大量的 `@unchecked Sendable` 使用，这是一个严重的并发安全隐患。

### 统计数据

- **总数**: 421 处使用 `@unchecked Sendable`
- **项目代码**: LumiApp 目录中约 30+ 个文件使用
- **第三方依赖**: 部分来自 MagicKit、swift-nio 等依赖包

### 影响范围

核心服务类几乎全部使用了 `@unchecked Sendable`：

```
./LumiApp/Core/Services/Tools/ToolService.swift:61
./LumiApp/Core/Services/LLM/LLMService.swift:37
./LumiApp/Core/Services/LLM/ProviderRegistry.swift:28
./LumiApp/Core/Services/LLM/LLMAPIService.swift:9
./LumiApp/Core/Services/ChatHistoryService.swift:52
./LumiApp/Plugins/AgentCoreToolsPlugin/Services/ShellService.swift:107
./LumiApp/Plugins/AppManagerPlugin/AppService.swift:8
./LumiApp/Plugins/TerminalPlugin/Core/PseudoTerminal.swift:8
./LumiApp/Plugins/AgentMCPToolsPlugin/MCPService.swift:8
./LumiApp/Plugins/NettoPlugin/Bridge/IPCConnection.swift:13
./LumiApp/Plugins/NettoPlugin/Services/FirewallService.swift:17
./LumiApp/Plugins/DeviceInfoPlugin/Services/SystemMonitorService.swift:5
... (更多)
```

## ⚠️ 风险分析

### 1. 数据竞争 (Data Race)

`@unchecked Sendable` 告诉编译器"相信我，这个类型是线程安全的"，但实际上：
- 没有编译器检查来保证线程安全
- 可变状态可能在多个并发任务间共享
- 可能导致难以调试的竞态条件

### 2. 真实案例

在 `ChatHistoryService` 中：
```swift
final class ChatHistoryService: SuperLog, @unchecked Sendable {
    private let modelContext: ModelContext  // SwiftData 的 ModelContext 不是线程安全的
    private let storageQueue = DispatchQueue(...)  // 有单独的队列但 @unchecked 绕过了检查
}
```

`ModelContext` 本身不是线程安全的，但使用 `@unchecked Sendable` 后可以在任意线程访问，容易导致数据损坏。

在 `LLMService` 中：
```swift
class LLMService: SuperLog, @unchecked Sendable {
    // 可能同时处理多个流式请求
    // 状态管理没有明确的线程边界
}
```

### 3. 维护风险

- 新开发者可能不理解为什么使用 `@unchecked`
- 添加新属性时容易忘记考虑线程安全
- 重构时可能引入并发 bug
- 并发问题难以复现和调试

## 🔍 根本原因

1. **Swift 并发迁移不完整**: 项目从传统并发模型迁移到 async/await，但为了快速通过编译器检查而大量使用 `@unchecked`

2. **第三方依赖限制**: 某些依赖（如 SwiftData 的 `ModelContext`）本身不是 `Sendable` 的

3. **Actor 边界不清晰**: 没有清晰地定义哪些状态应该在 Actor 内管理

4. **开发效率优先**: 为了快速迭代，选择了绕过编译器检查而非正确实现线程安全

## ✅ 建议解决方案

### 短期方案（缓解风险）

#### 1. 添加文档说明
为每个使用 `@unchecked Sendable` 的类添加注释，说明为什么是线程安全的：

```swift
/// 使用 @unchecked Sendable 的原因：
/// - 所有可变状态通过 storageQueue 串行访问
/// - modelContext 仅在 storageQueue 上使用
final class ChatHistoryService: SuperLog, @unchecked Sendable {
    ...
}
```

#### 2. 收敛使用范围
- 优先修复核心业务逻辑类
- 保持工具类/插件类现状

### 长期方案（彻底解决）

#### 1. 使用 Actor 重构
```swift
// 替代方案：使用 actor
actor ChatHistoryService: SuperLog {
    private let modelContext: ModelContext
    // actor 自动保证隔离，不需要 @unchecked
    
    func saveConversation(_ conversation: Conversation) async {
        // 自动串行化
    }
}
```

#### 2. 使用 Thread-Safe 包装器
```swift
// 替代方案：显式使用锁或队列
final class ChatHistoryService: SuperLog, Sendable {
    private let context: ModelContext
    private let lock = NSLock()
    
    func saveConversation(_ conversation: Conversation) {
        lock.withLock {
            // 线程安全的操作
        }
    }
}
```

#### 3. 使用值类型和不可变状态
```swift
// 替代方案：使用值类型
struct ChatHistoryService: Sendable {
    private let context: ModelContext  // 通过封装保证安全
}
```

#### 4. 分阶段迁移计划

| 阶段 | 任务 | 预计时间 |
|------|------|----------|
| 1 | 审计所有 @unchecked Sendable 使用 | 1 周 |
| 2 | 为核心服务添加线程安全文档 | 1 周 |
| 3 | 将关键服务转换为 actor | 2-3 周 |
| 4 | 逐步迁移剩余类 | 持续 |

## 🎯 优先级

**优先级: 🔴 High**

理由：
- 并发 bug 难以复现和调试
- 可能在生产环境导致数据损坏
- 随着项目增长，风险呈指数级增加
- 影响所有核心服务（聊天历史、LLM 调用、工具执行）
- 是其他潜在并发问题的根源

## 📁 相关文件

- `LumiApp/Core/Services/ChatHistoryService.swift`
- `LumiApp/Core/Services/LLM/LLMService.swift`
- `LumiApp/Core/Services/Tools/ToolService.swift`
- `LumiApp/Core/Services/LLM/ProviderRegistry.swift`
- `LumiApp/Core/Services/LLM/LLMAPIService.swift`
- `LumiApp/Core/ViewModels/AgentProvider.swift`
- `LumiApp/Core/Middleware/MessageSendMiddleware.swift`

## 🔍 验证命令

```bash
# 统计 @unchecked Sendable 使用数量
grep -r "@unchecked Sendable" LumiApp --include="*.swift" | wc -l

# 列出所有使用 @unchecked Sendable 的文件
grep -rn "@unchecked Sendable" LumiApp --include="*.swift" | cut -d: -f1 | sort -u
```

## 📚 参考资源

- [Swift Concurrency - Sendable](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Sendable)
- [WWDC21: Protect mutable state](https://developer.apple.com/videos/play/wwdc2021/10133/)
- [Swift.org: Sendable and @unchecked Sendable](https://www.swift.org/documentation/concurrency/)

---

**Issue ID**: #002  
**创建日期**: 2026-03-12  
**创建者**: DevAssistant  
**严重级别**: High  
**状态**: Open  
**标签**: concurrency, safety, tech-debt, architecture
