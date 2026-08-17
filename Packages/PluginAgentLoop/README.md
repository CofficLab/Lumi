# PluginAgentLoop

自定义 AgentLoop 插件,替换默认的 `DefaultAgentLoopProvider`。

## 功能

这个插件允许你在不修改 `FactoryLumi2` 的情况下自定义 AgentLoop 的行为。通过装饰器模式包装 `DefaultAgentLoopProvider`,你可以在以下场景添加自定义逻辑:

- 在回合前后添加监控和日志
- 拦截和修改消息
- 实现自定义的会话管理策略
- 添加性能追踪

## 使用方式

### 1. 添加依赖

在主项目的 `Package.swift` 或 Xcode 项目中添加:

```swift
.package(path: "Plugins/PluginAgentLoop")
```

### 2. 注册插件

在应用启动时注册插件:

```swift
let plugin = PluginAgentLoop()
kernel.registerPlugin(plugin)
```

### 3. 自定义行为

修改 `PluginAgentLoopProvider.swift` 中的 `runTurn` 方法来添加自定义逻辑:

```swift
public func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome {
    // 添加前置逻辑
    print("🚀 Starting turn for conversation: \(conversationID)")
    
    let result = try await inner.runTurn(in: conversationID)
    
    // 添加后置逻辑
    print("✅ Turn completed: \(result)")
    
    return result
}
```

## 架构说明

### 执行顺序

- `order = 1`,确保在消费方插件之前执行
- 使用 `unregisterProvider` + `registerProvider` 模式替换默认实现
- 依赖注入通过 `setLLMProvider`、`setToolManager` 等方法在 `onReady` 中完成

### 依赖关系

```
PluginAgentLoop (order=1)
    ↓ 提供 AgentLoopProviding
MessageSenderPlugin (order=9)
    ↓ 提供 MessageSendingProviding
ConversationListPlugin (order=81)
    ↓ 消费消息发送
```

## 注意事项

1. **不要在 `onBoot` 中注入依赖**:LLMProvider、ToolManager 等在 `onBoot` 之后才可用,依赖注入应该在 `onReady` 阶段完成
2. **保持 forwardsObjectWillChange = false**:与默认注册保持一致,避免高频更新导致 UI 重渲染
3. **装饰器模式**:通过包装 `DefaultAgentLoopProvider` 而不是继承,避免暴露内部状态

## 测试

```bash
cd Plugins/PluginAgentLoop
swift test
```

## 许可证

与主项目保持一致。
