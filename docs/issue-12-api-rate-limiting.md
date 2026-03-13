# Issue #12: 缺少 API 请求速率限制

**严重程度**: 🟠 High  
**状态**: Open  
**文件**: `LumiApp/Core/Services/LLM/LLMAPIService.swift`, `LLMService.swift`

---

## 问题描述

当前 LLM 服务没有实现请求速率限制（Rate Limiting），可能导致：

1. API 配额超限
2. 账户被封禁
3. 意外的高额费用
4. 服务拒绝攻击（DoS）

---

## 当前代码

```swift
class LLMAPIService: SuperLog, @unchecked Sendable {
    // 没有速率限制机制
    func sendChatRequest(...) async throws -> Data {
        // 直接发送请求
    }
}
```

---

## 问题分析

### 1. 各供应商的速率限制

| 供应商 | 限制类型 | 限制值 |
|--------|---------|--------|
| OpenAI | RPM (Requests/min) | 500-10000 |
| OpenAI | TPM (Tokens/min) | 100K-10M |
| Anthropic | RPM | 60-1000 |
| DeepSeek | RPM | 60 |

### 2. 潜在风险

- **自动重试叠加**: 重试机制可能加剧速率限制问题
- **多会话并发**: 多个会话同时请求可能超限
- **流式请求**: 长时间连接占用资源
- **工具调用链**: 一个请求触发多个工具调用

### 3. 用户体验问题

- 没有剩余配额提示
- 速率限制时缺少友好提示
- 没有自动降级机制

---

## 建议修复

### 1. 实现令牌桶算法

```swift
/// 速率限制器
actor RateLimiter {
    /// 每个供应商的限制配置
    struct ProviderLimits {
        let requestsPerMinute: Int
        let tokensPerMinute: Int
        var remainingRequests: Int
        var remainingTokens: Int
        var resetTime: Date
    }
    
    private var limits: [String: ProviderLimits] = [:]
    private var lastRequestTime: [String: Date] = [:]
    
    /// 检查是否可以发送请求
    func canMakeRequest(
        provider: String,
        estimatedTokens: Int
    ) async -> Result<Void, RateLimitError> {
        guard var limit = limits[provider] else {
            return .success(())
        }
        
        // 检查是否需要重置
        if Date() >= limit.resetTime {
            limit.remainingRequests = limit.requestsPerMinute
            limit.remainingTokens = limit.tokensPerMinute
            limit.resetTime = Date().addingTimeInterval(60)
            limits[provider] = limit
        }
        
        // 检查请求数限制
        guard limit.remainingRequests > 0 else {
            let waitTime = limit.resetTime.timeIntervalSince(Date())
            return .failure(.requestLimitExceeded(waitTime: waitTime))
        }
        
        // 检查 Token 数限制
        guard limit.remainingTokens >= estimatedTokens else {
            let waitTime = limit.resetTime.timeIntervalSince(Date())
            return .failure(.tokenLimitExceeded(waitTime: waitTime))
        }
        
        return .success(())
    }
    
    /// 记录请求消耗
    func recordRequest(
        provider: String,
        tokensUsed: Int
    ) async {
        guard var limit = limits[provider] else { return }
        
        limit.remainingRequests -= 1
        limit.remainingTokens -= tokensUsed
        limits[provider] = limit
        
        lastRequestTime[provider] = Date()
    }
    
    /// 从响应头更新限制信息
    func updateFromHeaders(
        provider: String,
        headers: [String: String]
    ) async {
        // OpenAI 格式
        // x-ratelimit-limit-requests: 10000
        // x-ratelimit-remaining-requests: 9999
        // x-ratelimit-limit-tokens: 10000000
        // x-ratelimit-remaining-tokens: 9999978
        // x-ratelimit-reset-requests: 6m0s
        // x-ratelimit-reset-tokens: 6m0s
        
        if let remainingRequests = headers["x-ratelimit-remaining-requests"],
           let requests = Int(remainingRequests),
           var limit = limits[provider] {
            limit.remainingRequests = requests
            limits[provider] = limit
        }
        
        // 类似处理其他头部...
    }
}

enum RateLimitError: Error {
    case requestLimitExceeded(waitTime: TimeInterval)
    case tokenLimitExceeded(waitTime: TimeInterval)
    case concurrentLimitExceeded
}
```

### 2. 集成到 LLMAPIService

```swift
class LLMAPIService: SuperLog, @unchecked Sendable {
    private let rateLimiter = RateLimiter()
    
    func sendChatRequest(
        url: URL,
        apiKey: String,
        body: [String: Any],
        provider: String
    ) async throws -> Data {
        // 估算 Token 数
        let estimatedTokens = estimateTokens(for: body)
        
        // 检查速率限制
        let checkResult = await rateLimiter.canMakeRequest(
            provider: provider,
            estimatedTokens: estimatedTokens
        )
        
        switch checkResult {
        case .success:
            break
        case .failure(let error):
            throw error
        }
        
        // 发送请求
        let (data, response) = try await sendRawRequestWithRetry(...)
        
        // 更新速率限制信息
        if let httpResponse = response as? HTTPURLResponse {
            await rateLimiter.updateFromHeaders(
                provider: provider,
                headers: httpResponse.allHeaderFields as? [String: String] ?? [:]
            )
        }
        
        // 记录实际消耗
        await rateLimiter.recordRequest(
            provider: provider,
            tokensUsed: extractTokensUsed(from: data)
        )
        
        return data
    }
}
```

### 3. 请求队列管理

```swift
/// 请求队列
actor RequestQueue {
    private var queue: [QueuedRequest] = []
    private var activeRequests: [String: Task<Data, Error>] = [:]
    private let maxConcurrent: Int = 5
    
    struct QueuedRequest {
        let id: UUID
        let request: () async throws -> Data
        let continuation: CheckedContinuation<Data, Error>
        let priority: Int
        let createdAt: Date
    }
    
    /// 添加请求到队列
    func enqueue(
        priority: Int = 0,
        request: @escaping () async throws -> Data
    ) async throws -> Data {
        // 检查并发数
        if activeRequests.count >= maxConcurrent {
            // 等待或排队
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            queue.append(QueuedRequest(
                id: UUID(),
                request: request,
                continuation: continuation,
                priority: priority,
                createdAt: Date()
            ))
            
            // 按优先级排序
            queue.sort { $0.priority > $1.priority }
            
            Task {
                await processQueue()
            }
        }
    }
    
    private func processQueue() async {
        while !queue.isEmpty && activeRequests.count < maxConcurrent {
            guard let queued = queue.first else { break }
            queue.removeFirst()
            
            let taskId = queued.id.uuidString
            activeRequests[taskId] = Task {
                defer { activeRequests.removeValue(forKey: taskId) }
                return try await queued.request()
            }
        }
    }
}
```

### 4. 用户提示 UI

```swift
/// 速率限制状态视图
struct RateLimitStatusView: View {
    @ObservedObject var viewModel: RateLimitViewModel
    
    var body: some View {
        HStack(spacing: 8) {
            // 请求限制进度
            ProgressView(value: viewModel.remainingRequestsRatio)
                .frame(width: 60)
            
            Text("\(viewModel.remainingRequests)/\(viewModel.totalRequests)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Token 限制进度
            ProgressView(value: viewModel.remainingTokensRatio)
                .frame(width: 60)
            
            Text(formatTokens(viewModel.remainingTokens))
                .font(.caption)
                .foregroundColor(.secondary)
            
            // 重置时间
            if let resetTime = viewModel.resetTime {
                Text("重置于 \(resetTime.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
}
```

---

## 修复优先级

高 - 缺少速率限制可能导致：
- 账户被封禁
- 意外高额费用
- 服务中断

---

*创建时间: 2026-03-13*