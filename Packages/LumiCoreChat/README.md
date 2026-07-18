# LumiComponentChat

LumiCore 的聊天服务核心组件包。

## ⚠️ 依赖约束

**此包只能被 LumiCoreKit 依赖，不应被其他任何包直接依赖。**

所有外部模块应通过 `LumiCoreKit` 的 typealias 访问此包中的类型：

```swift
// ✅ 正确：通过 LumiCoreKit 访问
import LumiCoreKit

// ❌ 错误：不应直接依赖此包
import LumiComponentChat
```

## 包含模块

### 核心服务
- `ChatService` - 聊天服务主类，管理对话、消息、Provider 选择和 Agent Turn 循环
- `ChatServiceDelegate` - 代理协议，用于访问 LumiCore 提供的功能
- `LumiChatServicing` - 聊天服务协议

### 管理器
- `ConversationManager` - 对话生命周期管理
- `MessageManager` - 消息 CRUD 操作
- `ProviderManager` - LLM Provider 注册和选择
- `SendPipeline` - 消息发送管道

### Agent 循环
- `TurnContext` - Turn 上下文
- `TurnOutcome` - Turn 结果枚举（completed/failed/awaitingUserResponse）
- `LumiAgentTurnCheck` - Turn 检查协议

### 内置工具
- `NoOpTool` - 空操作工具
- `ConversationInfoTool` - 对话信息查询工具

### 持久化
- `ChatStore` - 聊天数据持久化
- `ChatEntities` - SwiftData 实体定义

## 依赖

- `LumiComponentMessage` - 消息模型
- `LumiComponentAgentTool` - Agent 工具系统
- `LumiComponentPlugin` - 插件系统
- `LumiComponentLayout` - 布局组件
- `LumiComponentLLMProvider` - LLM Provider 支持
- `LLMKit` - LLM 核心
- `LumiLocalizationKit` - 本地化支持
- `SuperLogKit` - 日志系统

## 架构设计

本包是 LumiCore 的聊天核心，实现了 Agent 循环：

1. **消息发送管道** - `SendPipeline` 处理用户消息的入队、审批和发送
2. **Agent Turn 循环** - `runAgentTurn` 实现完整的 Agent 循环：调用 LLM -> 执行检查 -> 执行工具 -> 重复
3. **多 Manager 架构** - 职责分离，Conversation/Message/Provider 各司其职
4. **插件贡献集成** - 通过 `applyPluginContributions` 集成插件的 Provider、工具、中间件和渲染器
5. **空响应和内联工具调用重试** - 自动处理模型异常返回

支持多种自动化级别（full/build/manual）和响应详细程度（verbosity）。