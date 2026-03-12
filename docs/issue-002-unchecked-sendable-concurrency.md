# Issue: 系统性并发安全隐患 - 过度使用 @unchecked Sendable

## 📋 问题概述

项目中存在 **20 处** 过度使用 `@unchecked Sendable` 的情况，这绕过了 Swift 严格的并发安全检查，构成严重的潜在并发 bug 风险。与单一 `try!` 崩溃问题相比，这是一个**系统性的架构级风险**。

---

## 🔴 严重程度：Critical (最高级别)

**风险等级**: ⚠️ 可能导致：
- 数据竞争 (Data Race)
- 内存损坏
- 难以复现的间歇性崩溃
- 状态不一致

---

## 📍 问题位置

### 受影响的文件（20 处）：

| 文件 | 类名 | 风险级别 |
|------|------|----------|
| `LumiApp/Core/Services/LLM/LLMService.swift` | `LLMService` | 🔴 高 |
| `LumiApp/Core/Services/LLM/LLMAPIService.swift` | `LLMAPIService` | 🔴 高 |
| `LumiApp/Core/Services/LLM/ProviderRegistry.swift` | `ProviderRegistry` | 🔴 高 |
| `LumiApp/Core/Services/ChatHistoryService.swift` | `ChatHistoryService` | 🔴 高 |
| `LumiApp/Core/Services/Tools/ToolService.swift` | `ToolService` | 🔴 高 |
| `LumiApp/Core/Services/Tools/AgentTool.swift` | `ToolArgument` | 🟡 中 |
| `LumiApp/Plugins/AgentCoreToolsPlugin/Services/ShellService.swift` | `ShellService` | 🔴 高 |
| `LumiApp/Plugins/AppManagerPlugin/AppModel.swift` | `AppModel` | 🟡 中 |
| `LumiApp/Plugins/AppManagerPlugin/AppService.swift` | `AppService` | 🔴 高 |
| `LumiApp/Plugins/TerminalPlugin/Core/PseudoTerminal.swift` | `PseudoTerminal` | 🔴 高 |
| `LumiApp/Plugins/DiskManagerPlugin/Services/DiskService.swift` | `ProgressCounter` | 🟡 中 |
| `LumiApp/Plugins/NettoPlugin/Bridge/IPCConnection.swift` | `IPCConnection` | 🔴 高 |
| `LumiApp/Plugins/NettoPlugin/Services/FirewallService.swift` | `FirewallService` | 🔴 高 |
| `LumiApp/Plugins/NettoPlugin/Services/AppSettingRepo.swift` | `AppSettingRepo` | 🔴 高 |
| `LumiApp/Plugins/AgentMCPToolsPlugin/MCPService.swift` | `MCPService` | 🔴 高 |
| `LumiApp/Plugins/AgentMCPToolsPlugin/MCPToolAdapter.swift` | `MCPToolAdapter` | 🟡 中 |
| `LumiApp/Plugins/DeviceInfoPlugin/DeviceData.swift` | `TimerHolder` | 🟡 中 |
| `LumiApp/Plugins/DeviceInfoPlugin/Services/SystemMonitorService.swift` | `MonitorState` | 🟡 中 |
| `LumiTests/MultiAgentCollaborationTests.swift` | `MockWorkerToolService` | 🟢 测试 |

---

## 🐛 问题分析

### 为什么 @unchecked Sendable 是严重问题？

#### 1. **绕过并发安全检查**
```swift
// ❌ 危险：告诉编译器"我保证是线程安全的"，但实际可能不是
class LLMService: SuperLog, @unchecked Sendable {
    private var registry: ProviderRegistry  // 可能被多线程访问
    private var llmAPI: LLMAPIService
}
```

#### 2. **数据竞争风险**
当多个并发任务同时访问非线程安全的属性时：
- 读写顺序不确定
- 可能导致状态损坏
- 调试困难（难以复现）

#### 3. **与 Swift 6 不兼容**
Swift 6 将引入严格的并发检查，现有的 `@unchecked Sendable` 代码可能导致：
- 编译失败
- 需要大规模重构

### 典型风险案例

**案例 1: LLMService（高风险）**
```swift
class LLMService: SuperLog, @unchecked Sendable {
    private nonisolated let registry: ProviderRegistry
    private nonisolated let llmAPI: LLMAPIService
    
    // 问题：ProviderRegistry 内部可能包含非线程安全的可变状态
    // 多个 async 任务同时调用 sendMessage 可能导致数据竞争
}
```

**案例 2: ChatHistoryService（高风险）**
```swift
final class ChatHistoryService: SuperLog, @unchecked Sendable {
    // 可能涉及 SwiftData 上下文访问，非线程安全
}
```

**案例 3: ShellService（高风险）**
```swift
extension ShellService: @unchecked Sendable {
    // 执行系统命令的服务可能被并发调用
}
```

---

## ✅ 建议修复方案

### 方案 1: 使用 Actor 隔离状态（推荐）

```swift
// ✅ 正确：使用 Actor 提供线程安全的状态隔离
actor ProviderRegistry {
    private var providers: [String: LLMProvider] = [:]
    
    func register(_ provider: LLMProvider) {
        providers[provider.id] = provider
    }
    
    func getProvider(id: String) -> LLMProvider? {
        providers[id]
    }
}
```

### 方案 2: 使用 Sendable 符合类型

```swift
// ✅ 正确：确保所有存储属性都是 Sendable
final class AgentTool: Sendable {
    let name: String
    let description: String
    // 使用值类型或已验证线程安全的类型
}
```

### 方案 3: 使用 @MainActor 标记 UI 相关类

```swift
// ✅ 正确：UI 层使用 @MainActor
@MainActor
class ConversationViewModel: ObservableObject {
    // UI 状态自动在主线程访问
}
```

### 方案 4: 逐步迁移策略

1. **Phase 1 - 审计**：标记所有高风险位置
2. **Phase 2 - 分类**：确定哪些应该用 Actor、哪些用 @MainActor、哪些真正不可变
3. **Phase 3 - 修复**：按优先级逐步迁移
4. **Phase 4 - 验证**：添加并发测试

---

## 🎯 影响范围

### 直接影响：
- 所有 LLM API 调用路径
- 聊天历史存储/加载
- 工具服务调用
- 插件系统交互
- Shell 命令执行

### 间接影响：
- 用户可能遇到间歇性崩溃
- 数据一致性无法保证
- 内存泄漏风险

---

## 📝 修复优先级

- [ ] **P0 - 立即审计**: 对高风险类进行线程安全分析
- [ ] **P1 - 核心服务**: 优先修复 LLMService、ChatHistoryService、LLMAPIService
- [ ] **P2 - 插件系统**: 修复所有插件中的 @unchecked Sendable
- [ ] **P3 - 兼容性**: 准备 Swift 6 迁移

---

## 🔍 检查命令

```bash
# 统计当前 @unchecked Sendable 数量
grep -rn "@unchecked Sendable" --include="*.swift" LumiApp/ | wc -l

# 列出所有使用位置
grep -rn "@unchecked Sendable" --include="*.swift" LumiApp/

# 查找可能的并发问题（非线程安全属性）
grep -rn "private var\|private let" --include="*.swift" LumiApp/Core/Services/
```

---

## 📚 参考资源

- [Swift Concurrency Deep Dive](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [Sendable Protocol](https://github.com/apple/swift-evolution/blob/main/proposals/0302-sendable-protocol.md)
- [Actor Isolation](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Actor-isolation)

---

**创建日期**: 2026-03-12  
**创建者**: DevAssistant  
**标签**: `concurrency`, `thread-safety`, `critical`, `architecture`  
**相关问题**: issue-001-chatmessage-try-crash.md