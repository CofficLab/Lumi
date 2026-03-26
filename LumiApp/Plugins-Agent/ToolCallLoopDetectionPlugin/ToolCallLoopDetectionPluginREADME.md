# Tool Call Loop Detection Plugin

检测并阻止 AI Agent 的工具调用无限循环，保护系统资源和用户体验。

## 功能

- 基于历史消息分析工具调用模式
- 检测循环调用并自动终止本轮对话
- 向用户显示详细的循环信息和建议

## 目录结构

```
ToolCallLoopDetectionPlugin/
├── ToolCallLoopDetectionPlugin.swift          # 插件主入口
├── ToolCallLoopDetectionPlugin.xcstrings      # 本地化字符串
├── README.md                                   # 插件文档
└── Middleware/                                 # 中间件目录
    └── ToolCallLoopDetectionSendMiddleware.swift  # 循环检测中间件
```

## 工作原理

1. **检测时机**：在每次发送用户消息到 LLM 之前，中间件分析最近的工具调用历史
2. **检测逻辑**：统计同一工具（名称 + 参数）的调用次数
3. **触发条件**：当某工具调用次数超过阈值（`AgentConfig.repeatedToolWindowThreshold = 10`）时触发
4. **终止流程**：调用 `context.abort(withMessage:)` 保存循环警告消息并终止本轮

## 配置

检测阈值在 `AgentConfig` 中配置：

```swift
// 连续重复同一工具签名的阈值
static let repeatedToolSignatureThreshold = 10

// 窗口内重复同一工具签名的阈值
static let repeatedToolWindowThreshold = 10
```

## 使用示例

### 正常情况

```
用户：列出当前目录文件
→ Agent 调用 ls_tool()
→ 返回结果
→ Agent 回复

用户：创建文件 test.txt
→ Agent 调用 write_file()
→ 返回结果
→ Agent 回复
```

### 循环检测

```
用户：读取文件内容
→ Agent 调用 read_file()
→ 返回错误
→ Agent 重试 read_file()
→ 返回错误
→ Agent 重试 read_file()  ← 第 10 次
→ 🔴 检测到循环！
→ 终止并显示警告
```

## 限制

- 只能检测"已发生"的循环，无法预测
- 基于完全相同的工具签名检测（不处理参数相似度）
- 检测阈值固定，无法动态调整

## 未来优化

- 支持参数相似度检测（如路径差异）
- 支持动态阈值调整
- 支持工具白名单机制
- 支持更复杂的循环模式识别

## 相关文件

- `Middleware/ToolCallLoopDetectionSendMiddleware.swift` - 中间件实现
- `SendMessageContext.swift` - 扩展的上下文（支持 abort 回调）
- `ChatMessage+System.swift` - 循环警告消息生成
- `AgentConfig.swift` - 检测阈值配置