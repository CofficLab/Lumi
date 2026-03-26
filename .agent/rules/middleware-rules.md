# 中间件开发规范

> 本规范定义 Lumi 中所有中间件的开发约束，确保中间件的独立性、可测试性和可维护性。

---

## 核心原则

**中间件必须通过上下文（Context）获取依赖，禁止引入任何外部依赖，尤其是全局单例。**

中间件作为插件的一部分，应该是自包含、可测试、可复用的组件。所有需要的能力都必须通过上下文对象注入，而不是直接访问全局状态。

---

## 规则一：禁止访问全局依赖

### ❌ 禁止的做法

```swift
// ❌ 禁止：访问全局单例
let languagePreference = await MainActor.run {
    RootViewContainer.shared.projectVM.languagePreference
}

// ❌ 禁止：直接访问静态单例
let config = LLMVM.shared.getCurrentConfig()

// ❌ 禁止：访问全局状态管理器
let state = AppStateManager.shared.currentState
```

### ✅ 正确的做法

```swift
// ✅ 正确：通过上下文获取
let languagePreference = ctx.agentSessionConfig.getCurrentConfig().languagePreference

// ✅ 正确：通过上下文注入的服务
let messages = await ctx.chatHistoryService.loadMessagesAsync(...)

// ✅ 正确：通过上下文提供的配置
let threshold = ctx.agentSessionConfig.threshold
```

---

## 规则二：所有依赖必须来自上下文

中间件的 `handle(ctx:next:)` 方法接收的 `ctx` 参数是中间件获取所有外部依赖的唯一入口。

### 上下文提供的依赖

以 `SendMessageContext` 为例：

```swift
@MainActor
final class SendMessageContext {
    // 会话标识
    let conversationId: UUID

    // 当前消息
    let message: ChatMessage

    // 历史消息服务
    let chatHistoryService: ChatHistoryService

    // Agent 会话配置
    let agentSessionConfig: LLMVM

    // 终止回调
    var abortTurn: (() -> Void)?
}
```

### 通过上下文可以获取

| 需求 | 获取方式 |
|------|----------|
| 语言偏好 | `ctx.agentSessionConfig.getCurrentConfig().languagePreference` |
| 历史消息 | `await ctx.chatHistoryService.loadMessagesAsync(...)` |
| 保存消息 | `await ctx.chatHistoryService.saveMessageAsync(...)` |
| 会话 ID | `ctx.conversationId` |
| 当前消息 | `ctx.message` |
| LLM 配置 | `ctx.agentSessionConfig.getCurrentConfig()` |
| 终止本轮 | `ctx.abort(withMessage: ...)` |

---

## 规则三：如需新能力，扩展上下文

如果中间件需要新的能力（如访问项目配置、工具服务等），应通过扩展上下文提供，而不是直接访问全局。

### 扩展上下文的步骤

1. 在上下文中添加新属性
2. 在 `SendController` 创建上下文时注入
3. 中间件通过上下文使用

**示例：需要访问项目配置**

```swift
// 1. 扩展 SendMessageContext
extension SendMessageContext {
    /// 项目视图模型（用于访问项目配置）
    let projectVM: ProjectVM?
}

// 2. 在 SendController 中注入
let ctx = SendMessageContext(
    conversationId: conversationId,
    message: message,
    chatHistoryService: container.chatHistoryService,
    agentSessionConfig: container.agentSessionConfig,
    projectVM: container.projectVM  // 注入
)

// 3. 中间件中使用
let languagePreference = ctx.projectVM?.languagePreference ?? .english
```

---

## 规则四：中间件必须可测试

中间件应该可以独立测试，不依赖任何全局状态。

### 测试中间件的示例

```swift
@Test("检测工具调用循环")
func testToolLoopDetection() async {
    // 创建模拟的 ChatHistoryService
    let mockChatHistoryService = MockChatHistoryService()
    mockChatHistoryService.messages = createTestMessages()

    // 创建上下文
    let ctx = SendMessageContext(
        conversationId: UUID(),
        message: ChatMessage(role: .user, conversationId: UUID(), content: "test"),
        chatHistoryService: mockChatHistoryService,
        agentSessionConfig: MockLLMVM()
    )

    // 创建中间件
    let middleware = ToolCallLoopDetectionSendMiddleware()

    // 测试
    var executed = false
    await middleware.handle(ctx: ctx) { _ in
        executed = true
    }

    // 验证：如果检测到循环，next 不应该被调用
    #expect(!executed)
}
```

---

## 规则五：保持中间件纯净

中间件应该：
- ✅ 只读不写（除了通过上下文提供的 API）
- ✅ 无副作用（除了通过上下文提供的 API）
- ✅ 幂等性（相同输入，相同行为）
- ✅ 无状态（或状态通过上下文管理）

### ❌ 错误示例

```swift
@MainActor
struct BadMiddleware: SendMiddleware {
    // ❌ 中间件内部维护状态
    private var state: [String: Int] = [:]

    func handle(ctx: SendMessageContext, next: SendPipelineNext) async {
        // ❌ 直接修改全局状态
        AppStateManager.shared.incrementCounter()

        // ❌ 发起网络请求（应该通过上下文提供的服务）
        let data = try await URLSession.shared.data(from: URL(string: "...")!)

        await next(ctx)
    }
}
```

### ✅ 正确示例

```swift
@MainActor
struct GoodMiddleware: SendMiddleware {
    // ✅ 无状态

    func handle(ctx: SendMessageContext, next: SendPipelineNext) async {
        // ✅ 只通过上下文获取数据
        let messages = await ctx.chatHistoryService.loadMessagesAsync(...)

        // ✅ 只通过上下文修改状态
        await ctx.chatHistoryService.saveMessageAsync(...)

        // ✅ 使用上下文提供的终止能力
        ctx.abort(withMessage: warningMessage)

        await next(ctx)
    }
}
```

---

## 常见问题

### Q1: 为什么禁止访问全局依赖？

| 原因 | 说明 |
|------|------|
| **可测试性** | 全局依赖难以模拟，导致测试困难 |
| **可维护性** | 隐式依赖使代码难以理解和重构 |
| **可复用性** | 依赖全局状态的中间件无法在不同环境复用 |
| **可预测性** | 全局状态变化导致行为不可预测 |

### Q2: 如果上下文没有提供需要的能力怎么办？

**答案**：扩展上下文，而不是绕过它。

步骤：
1. 在上下文中添加新属性（可选类型，保持向后兼容）
2. 在 `SendController` 创建上下文时注入
3. 中间件通过上下文使用

### Q3: 中间件可以维护内部状态吗？

**答案**：可以，但仅限于中间件内部的临时状态，不应跨请求持久化。

```swift
// ✅ 允许：临时状态（每个请求独立）
struct LoopDetectionMiddleware: SendMiddleware {
    func handle(ctx: SendMessageContext, next: SendPipelineNext) async {
        var count = 0  // 临时变量
        // ...
    }
}

// ❌ 禁止：跨请求的持久状态
struct LoopDetectionMiddleware: SendMiddleware {
    private var totalCount = 0  // 跨请求状态，违反规则
}
```

---

## 检查清单

编写中间件时，确保：

- [ ] 不访问任何全局单例（`RootViewContainer.shared`、`AppState.shared` 等）
- [ ] 不直接访问静态全局状态
- [ ] 所有依赖都通过 `ctx` 参数获取
- [ ] 如需新能力，通过扩展上下文提供
- [ ] 可以独立测试（使用模拟上下文）
- [ ] 保持无状态或状态仅限于请求内

---

## 相关规范

- [插件目录结构规范](./plugin-directory-rules.md)
- [内核与插件边界规范](./core-plugin-boundary-rules.md)