# RequestLogPlugin

> 记录每次聊天请求的发送数据，用于调试和审计。

## 功能简介

RequestLogPlugin 是一个用于记录 LLM 请求和响应数据的中间件插件。它会在每次聊天请求完成后，将完整的请求信息、LLM 配置、消息列表、工具调用和响应数据存储到 SwiftData 数据库中。

## 目录结构

```
RequestLogPlugin/
├── RequestLogPlugin.swift              # 插件主入口
├── RequestLogPlugin.xcstrings          # 本地化字符串
├── RequestLogPluginREADME.md           # 本文档
├── Middleware/
│   └── RequestLogSendMiddleware.swift  # 发送中间件实现
├── Models/
│   └── RequestLogItem.swift            # SwiftData 数据模型
└── Services/
    └── RequestLogHistoryManager.swift  # 历史记录管理器
```

## 数据存储

### 存储方式

- **格式**：SwiftData（SQLite）
- **位置**：`~/Library/Application Support/com.coffic.Lumi/db_{debug|production}/RequestLogPlugin/history.sqlite`

### 数据模型

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 唯一标识符 |
| conversationId | UUID | 会话 ID |
| timestamp | Date | 时间戳 |
| requestURL | String | 请求 URL |
| requestBodySize | Int | 请求体大小 |
| providerId | String? | LLM 供应商 ID |
| modelName | String? | 模型名称 |
| messageCount | Int | 消息数量 |
| toolCount | Int | 工具数量 |
| isSuccess | Bool | 是否成功 |
| errorMessage | String? | 错误信息 |
| hasToolCalls | Bool | 是否包含工具调用 |
| latency | Double? | 请求延迟 |
| inputTokens | Int? | 输入 Token 数量 |
| outputTokens | Int? | 输出 Token 数量 |
| duration | Double? | 总耗时 |

### 数据保留策略

- **保留期限**：7 天
- **最大记录数**：10,000 条
- **自动清理**：超过限制时自动清理过期数据

## 中间件说明

### RequestLogSendMiddleware

- **ID**: `request.log`
- **Order**: 1000（较晚执行，确保在其他处理后记录）
- **协议**: `SendMiddleware`

#### 功能

1. **发送前阶段 (`handle`)**: 不做任何处理，直接继续管线执行
2. **发送后阶段 (`handlePost`)**: 将请求和响应数据存储到数据库

## API 说明

### RequestLogHistoryManager

历史记录管理器提供以下 API：

```swift
// 添加日志
await RequestLogHistoryManager.shared.add(metadata: metadata, response: response)

// 查询指定时间范围的日志
let logs = await RequestLogHistoryManager.shared.query(from: startTime, to: endTime)

// 按会话 ID 查询
let logs = await RequestLogHistoryManager.shared.query(conversationId: conversationId)

// 获取最新日志
let logs = await RequestLogHistoryManager.shared.getLatest(limit: 100)

// 获取统计信息
let stats = await RequestLogHistoryManager.shared.getStats()

// 清空所有日志
await RequestLogHistoryManager.shared.clearAll()
```

### 统计信息

```swift
struct RequestLogStats {
    var totalRequests: Int       // 总请求数
    var successCount: Int        // 成功数
    var failedCount: Int         // 失败数
    var successRate: Double      // 成功率
    var averageDuration: Double  // 平均耗时
    var totalInputTokens: Int    // 总输入 Token
    var totalOutputTokens: Int   // 总输出 Token
}
```

## 使用方式

插件启用后自动工作，无需配置。每次聊天请求完成后：

1. 数据自动存储到 SQLite 数据库
2. 同时输出简要日志到控制台

## 与其他插件的交互

- 该中间件通过 `SendMiddleware` 协议的 `handlePost` 方法获取 `RequestMetadata` 和响应消息
- 不会修改任何请求或响应数据，仅做日志记录
- order 设置为 1000，确保在其他中间件处理完成后执行

## 注意事项

- 日志可能包含敏感信息（如用户消息内容），请注意数据安全
- 数据库文件位于应用的 Application Support 目录下
- 建议在生产环境中考虑数据加密或脱敏