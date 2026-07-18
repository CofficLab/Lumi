# LumiComponentMessage

LumiCore 的消息模型组件包。

## ⚠️ 依赖约束

**此包只能被 LumiCoreKit 依赖，不应被其他任何包直接依赖。**

所有外部模块应通过 `LumiCoreKit` 的 typealias 访问此包中的类型：

```swift
// ✅ 正确：通过 LumiCoreKit 访问
import LumiCoreKit

// ❌ 错误：不应直接依赖此包
import LumiComponentMessage
```

## 包含模块

### 核心消息类型
- `LumiChatMessage` - 聊天消息结构体，包含角色、内容、工具调用、元数据等
- `LumiChatMessageRole` - 消息角色枚举（user/assistant/system/tool/error）
- `LumiConversationSummary` - 对话摘要

### 工具相关
- `LumiToolCall` - 工具调用结构体
- `LumiToolResult` - 工具执行结果
- `LumiToolTypes` - 工具类型定义
- `LumiToolTag` - 工具标签枚举（用于工具过滤）

### 附件和流式响应
- `LumiImageAttachment` - 图片附件
- `LumiStreamChunk` - 流式响应块

### 其他类型
- `LumiJSONValue` - JSON 值枚举（用于工具参数）
- `LumiLanguagePreference` - 语言偏好
- `LumiResponseVerbosity` - 响应详细程度
- `LumiConversationContextUsage` - 对话上下文使用量
- `LumiSendMiddleware` - 发送中间件协议
- `LumiPendingMessage` - 待发送消息
- `LumiPendingToolConfirmation` - 待确认的工具调用
- `LumiMessageRenderer` - 消息渲染器
- `LumiTurnEndReason` - Turn 结束原因

## 依赖

无外部依赖。这是 LumiCore 的基础数据模型层。

## 架构设计

本包是 LumiCore 的数据模型基础：

1. **消息模型** - `LumiChatMessage` 是整个系统的核心数据结构，支持多种角色和元数据
2. **工具调用** - 完整的工具调用生命周期模型（调用、结果、附件）
3. **类型安全** - `LumiJSONValue` 提供类型安全的 JSON 处理
4. **扩展点** - 中间件、渲染器等扩展协议

该包设计为零依赖，确保数据模型的纯粹性和可复用性。