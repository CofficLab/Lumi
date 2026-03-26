# RequestLogPlugin

> 记录每次聊天请求的发送数据，用于调试和审计。

## 功能简介

RequestLogPlugin 是一个用于记录 LLM 请求和响应数据的中间件插件。它会在每次聊天请求完成后，记录完整的请求信息、LLM 配置、消息列表、工具调用和响应数据。

## 目录结构

```
RequestLogPlugin/
├── RequestLogPlugin.swift           # 插件主入口
├── RequestLogPlugin.xcstrings       # 本地化字符串
├── RequestLogPluginREADME.md        # 本文档
└── Middleware/
    └── RequestLogSendMiddleware.swift  # 发送中间件实现
```

## 中间件说明

### RequestLogSendMiddleware

- **ID**: `request.log`
- **Order**: 1000（较晚执行，确保在其他处理后记录）
- **协议**: `SendMiddleware`

#### 功能

1. **发送前阶段 (`handle`)**: 不做任何处理，直接继续管线执行
2. **发送后阶段 (`handlePost`)**: 记录完整的请求和响应数据

#### 记录内容

| 分类 | 内容 |
|------|------|
| 请求基础信息 | URL、请求体大小、时间戳 |
| LLM 配置 | Provider、Model、Temperature、Max Tokens |
| 消息列表 | 所有发送的消息（含角色和工具调用） |
| 可用工具 | 工具名称和描述 |
| 临时系统提示词 | 中间件添加的临时提示词 |
| 响应信息 | 内容、工具调用、延迟、Token 数量、完成原因 |
| Token 使用 | Prompt/Completion/Total Tokens |
| 耗时 | 总请求耗时 |

## 使用方式

插件启用后自动工作，无需配置。每次聊天请求完成后，日志会输出到：
- Xcode 控制台
- OS Log（可通过 Console.app 查看）

## 日志示例

```
============================================================
📤 请求日志 [2024-01-15T10:30:00Z]
============================================================

【请求信息】
  URL: https://api.anthropic.com/v1/messages
  请求体大小: 1.50 KB
  时间戳: 2024-01-15T10:30:00Z

【LLM 配置】
  Provider: anthropic
  Model: claude-3-sonnet-20240229
  Temperature: 1.0
  Max Tokens: 4096

【消息列表】(3 条)
  [0] system: You are a helpful assistant...
  [1] user: Hello, how are you?
  [2] assistant: Hello! I'm doing well...

【可用工具】(2 个)
  - tool1: Description for tool1...
  - tool2: Description for tool2...

【响应信息】
  ✅ 成功
  内容: Hello! I'm doing well, thank you for asking!...
  延迟: 1500ms
  输入 Token: 120
  输出 Token: 45
  总 Token: 165
  完成原因: end_turn

【Token 使用】
  Prompt Tokens: 120
  Completion Tokens: 45
  Total Tokens: 165

【耗时】
  总耗时: 1.50s

============================================================
```

## 与其他插件的交互

- 该中间件通过 `SendMiddleware` 协议的 `handlePost` 方法获取 `RequestMetadata` 和响应消息
- 不会修改任何请求或响应数据，仅做日志记录
- order 设置为 1000，确保在其他中间件处理完成后执行

## 注意事项

- 日志可能包含敏感信息（如用户消息内容），请注意保护日志输出
- 大量请求可能会产生大量日志，建议仅在调试时启用