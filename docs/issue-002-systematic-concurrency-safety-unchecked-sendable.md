# Issue #002: 系统性并发安全隐患 - 过度使用 @unchecked Sendable

## 📋 问题概述

项目中存在 **19 处** 核心代码过度使用 `@unchecked Sendable` 的情况，这绕过了 Swift 严格的并发安全检查，构成严重的潜在并发 bug 风险。

> **整合说明**: 此 issue 整合了原有的 `issue-002-unchecked-sendable-concurrency.md` 和 `issue-002-concurrency-safety-unchecked-sendable.md`

---

## 🔴 严重程度：Critical (最高级别)

**风险等级**: ⚠️ 可能导致：
- 数据竞争 (Data Race)
- 内存损坏
- 难以复现的间歇性崩溃
- 状态不一致
- Swift 6 升级时编译失败

**优先级**: P0 - 需要立即审计和修复

---

## 📍 问题位置

### 受影响的文件（19 处核心代码）：

| # | 文件路径 | 类名 | 风险级别 | 说明 |
|---|----------|------|----------|------|
| 1 | `LumiApp/Core/Services/LLM/LLMService.swift` | `LLMService` | 🔴 高 | 核心 LLM 服务，处理所有 AI 请求 |
| 2 | `LumiApp/Core/Services/LLM/LLMAPIService.swift` | `LLMAPIService` | 🔴 高 | API 通信层，网络请求 |
| 3 | `LumiApp/Core/Services/LLM/ProviderRegistry.swift` | `ProviderRegistry` | 🔴 高 | 提供者注册表，状态管理 |
| 4 | `LumiApp/Core/Services/ChatHistoryService.swift` | `ChatHistoryService` | 🔴 高 | 聊天历史存储，SwiftData 访问 |
| 5 | `LumiApp/Core/Services/Tools/ToolService.swift` | `ToolService` | 🔴 高 | 工具调用服务 |
| 6 | `LumiApp/Core/Services/Tools/AgentTool.swift` | `ToolArgument` | 🟡 中 | 工具参数结构体 |
| 7 | `LumiApp/Plugins/AgentCoreToolsPlugin/Services/ShellService.swift` | `ShellService` | 🔴 高 | Shell 命令执行 |
| 8 | `LumiApp/Plugins/AppManagerPlugin/AppModel.swift` | `AppModel` | 🟡 中 | 应用模型 |
| 9 | `LumiApp/Plugins/AppManagerPlugin/AppService.swift` | `AppService` | 🔴 高 | 应用管理服务 |
| 10 | `LumiApp/Plugins/TerminalPlugin/Core/PseudoTerminal.swift` | `PseudoTerminal` | 🔴 高 | 伪终端模拟 |
| 11 | `LumiApp/Plugins/DiskManagerPlugin/Services/DiskService.swift` | `ProgressCounter` | 🟡 中 | 进度计数器 |
| 12 | `LumiApp/Plugins/NettoPlugin/Bridge/IPCConnection.swift` | `IPCConnection` | 🔴 高 | IPC 进程间通信 |
| 13 | `LumiApp/Plugins/NettoPlugin/Services/FirewallService.swift` | `FirewallService` | 🔴 高 | 防火墙服务 |
| 14 | `LumiApp/Plugins/NettoPlugin/Services/AppSettingRepo.swift` | `AppSettingRepo` | 🔴 高 | 应用设置存储 |
| 15 | `LumiApp/Plugins/AgentMCPToolsPlugin/MCPService.swift` | `MCPService` | 🔴 高 | MCP 工具服务 |
| 16 | `LumiApp/Plugins/AgentMCPToolsPlugin/MCPToolAdapter.swift` | `MCPToolAdapter` | 🟡 中 | MCP 工具适配器 |
| 17 | `LumiApp/Plugins/DeviceInfoPlugin/DeviceData.swift` | `TimerHolder` | 🟡 中 | 定时器持有者 |
| 18 | `LumiApp/Plugins/DeviceInfoPlugin/Services/SystemMonitorService.swift` | `MonitorState` | 🟡 中 | 系统监控状态 |
| 19 | `LumiTests/MultiAgentCollaborationTests.swift` | `MockWorkerToolService` | 🟢 测试 | 测试代码（低优先级） |

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

编译器不再检查这些类是否真正线程安全，开发者需要手动保证。

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

#### 案例 1: LLMService（高风险）
```swift
class LLMService: SuperLog, @unchecked Sendable {
    private nonisolated let registry: ProviderRegistry
    private nonisolated let llmAPI: LLMAPIService
    
    // 问题：ProviderRegistry 内部可能包含非线程安全的可变状态
    // 多个 async 任务同时调用 sendMessage 可能导致数据竞争
}
```

**风险场景**:
- 用户快速连续发送多条消息
- 多个 Agent 同时调用 LLM
- 流式响应过程中取消请求

#### 案例 2: ChatHistoryService（高风险）
```swift
final class ChatHistoryService: SuperLog, @unchecked Sendable {
    // 可能涉及 SwiftData 上下文访问，非线程安全
    // SwiftData 的 ModelContext 不是线程安全的
}
```

**风险场景**:
- 同时在后台保存和前台加载聊天记录
- 多窗口同时访问同一对话

#### 案例 3: ShellService（高风险）
```swift
extension ShellService: @unchecked Sendable {
    // 执行系统命令的服务可能被并发调用
    // 文件描述符和进程状态可能被竞争访问
}
```

**风险场景**:
- 多个终端标签页同时执行命令
- 命令执行过程中取消操作

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

### 方案 4: 使用锁机制（适用于简单场景）

```swift
// ✅ 正确：使用 OSAllocatedUnfairLock 保护可变状态
final class SafeCounter: Sendable {
    private final class State {
        var count = 0
    }
    private let state = State()
    private let lock = OSAllocatedUnfairLock()
    
    func increment() {
        lock.withLock {
            state.count += 1
        }
    }
}
```

### 方案 5: 逐步迁移策略

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

| 优先级 | 任务 | 预计工作量 |
|--------|------|-----------|
| **P0** | 对高风险类进行线程安全审计 | 2-3 天 |
| **P1** | 核心服务层修复（LLM、ChatHistory、Shell） | 5-7 天 |
| **P2** | 插件系统修复 | 3-5 天 |
| **P3** | 测试代码修复 | 1-2 天 |
| **P4** | 添加并发测试验证 | 2-3 天 |

**总预计工作量**: 2-3 周

---

## 🔍 检测方法

### 查找所有 @unchecked Sendable 使用：
```bash
grep -rn "@unchecked Sendable" --include="*.swift" LumiApp/
```

### 使用 Swift Concurrency Analyzer：
```bash
swift build -Xswiftc -strict-concurrency=complete
```

---

## 📚 参考资源

- [Swift Concurrency - Sendable](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Sendable)
- [Swift 6 Concurrency](https://www.swift.org/swift-6/)
- [Actor Isolation](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Actors)
- [Data Race Detection](https://developer.apple.com/documentation/xcode/detecting-data-races-in-your-app)

---

## 📋 修复进度追踪

| # | 文件 | 状态 | 修复日期 | 负责人 |
|---|------|------|----------|--------|
| 1 | LLMService.swift | ⏳ 待修复 | - | - |
| 2 | LLMAPIService.swift | ⏳ 待修复 | - | - |
| 3 | ProviderRegistry.swift | ⏳ 待修复 | - | - |
| 4 | ChatHistoryService.swift | ⏳ 待修复 | - | - |
| 5 | ToolService.swift | ⏳ 待修复 | - | - |
| 6 | AgentTool.swift | ⏳ 待修复 | - | - |
| 7 | ShellService.swift | ⏳ 待修复 | - | - |
| 8 | AppModel.swift | ⏳ 待修复 | - | - |
| 9 | AppService.swift | ⏳ 待修复 | - | - |
| 10 | PseudoTerminal.swift | ⏳ 待修复 | - | - |
| 11 | DiskService.swift | ⏳ 待修复 | - | - |
| 12 | IPCConnection.swift | ⏳ 待修复 | - | - |
| 13 | FirewallService.swift | ⏳ 待修复 | - | - |
| 14 | AppSettingRepo.swift | ⏳ 待修复 | - | - |
| 15 | MCPService.swift | ⏳ 待修复 | - | - |
| 16 | MCPToolAdapter.swift | ⏳ 待修复 | - | - |
| 17 | DeviceData.swift | ⏳ 待修复 | - | - |
| 18 | SystemMonitorService.swift | ⏳ 待修复 | - | - |

---

## 🔄 相关 Issue

- **Issue #001**: ChatMessageEntity 中使用 try! 强制解包
- **Issue #003**: TurnContexts 内存泄漏问题

---

**创建日期**: 2026-03-12
**更新日期**: 2026-03-12
**创建者**: DevAssistant (自动分析生成)
**整合来源**: 
- issue-002-unchecked-sendable-concurrency.md
- issue-002-concurrency-safety-unchecked-sendable.md
**标签**: `bug`, `concurrency`, `critical`, `architecture`, `swift6`