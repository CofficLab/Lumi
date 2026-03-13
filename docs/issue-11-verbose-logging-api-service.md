# Issue #11: LLMAPIService 详细日志泄露敏感信息

**严重程度**: 🔴 Critical  
**状态**: Open  
**文件**: `LumiApp/Core/Services/LLM/LLMAPIService.swift`

---

## 问题描述

`LLMAPIService` 中的 `verbose` 标志被设置为 `true`，会记录详细的请求和响应信息，可能泄露敏感数据。

## 当前代码

```swift
class LLMAPIService: SuperLog, @unchecked Sendable {
    nonisolated static let emoji = "🌐"
    nonisolated static let verbose = true  // 问题：生产环境不应开启详细日志
```

## 问题分析

1. **API Key 泄露风险**
   - 日志中可能包含完整的 API Key
   - 即使部分隐藏，也可能被推断

2. **用户数据泄露**
   - 请求体包含用户对话内容
   - 响应体可能包含敏感信息

3. **日志持久化**
   - 系统日志可能被导出
   - 第三方工具可能读取日志

4. **性能影响**
   - 详细日志增加 I/O 开销
   - 序列化大 JSON 影响性能

## 泄露场景

```
// 日志示例
📦 请求体 (1.2KB)：
{
  "model": "gpt-4",
  "messages": [
    {"role": "user", "content": "我的密码是..."}
  ]
}
```

## 建议修复

### 1. 根据环境动态控制日志级别

```swift
class LLMAPIService: SuperLog, @unchecked Sendable {
    #if DEBUG
    nonisolated static let verbose = 1  // 开发环境：基础日志
    #else
    nonisolated static let verbose = 0  // 生产环境：关闭日志
    #endif
```

### 2. 敏感信息脱敏

```swift
private func sanitizeForLogging(_ dictionary: [String: Any]) -> [String: Any] {
    var sanitized = dictionary
    
    // 脱敏 API Key
    if sanitized["api_key"] != nil {
        sanitized["api_key"] = "***REDACTED***"
    }
    
    // 脱敏 Authorization header
    if sanitized["authorization"] != nil {
        sanitized["authorization"] = "***REDACTED***"
    }
    
    // 脱敏用户消息（仅显示长度）
    if var messages = sanitized["messages"] as? [[String: Any]] {
        for i in messages.indices {
            if let content = messages[i]["content"] as? String {
                messages[i]["content"] = "[\(content.count) chars]"
            }
        }
        sanitized["messages"] = messages
    }
    
    return sanitized
}
```

### 3. 分类日志级别

```swift
enum LogLevel {
    case off          // 关闭
    case error        // 仅错误
    case warning      // 错误 + 警告
    case info         // 基础信息（不含敏感数据）
    case debug        // 详细信息（脱敏后）
    case trace        // 完整信息（仅开发环境）
}

nonisolated static var logLevel: LogLevel {
    #if DEBUG
    return .debug
    #else
    return .warning
    #endif
}
```

### 4. 日志审计

```swift
// 添加日志审计功能
class LogAuditor {
    static func audit(log: String) -> Bool {
        // 检查是否包含敏感模式
        let sensitivePatterns = [
            "sk-[a-zA-Z0-9]{20,}",  // OpenAI API Key
            "xox[baprs]-[a-zA-Z0-9-]+",  // Slack Token
            "[0-9]{16,}",  // 可能的信用卡号
        ]
        
        for pattern in sensitivePatterns {
            if log.range(of: pattern, options: .regularExpression) != nil {
                return false
            }
        }
        
        return true
    }
}
```

## 修复优先级

高 - 敏感信息泄露可能导致：
- API Key 被盗用
- 用户隐私泄露
- 合规性问题

## 相关 Issue

- Issue #6: 调试日志可能泄露敏感信息

---

*创建时间: 2026-03-13*