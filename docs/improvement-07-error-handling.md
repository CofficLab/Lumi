# 改进建议：错误处理与自动恢复机制

**参考产品**: Cursor, Claude Code, VS Code Copilot  
**优先级**: 🟡 中  
**影响范围**: 全局

---

## 背景

优秀的 AI 开发工具需要健壮的错误处理机制：

- 网络故障自动重试
- API 限流智能处理
- 错误上下文保存
- 用户友好的错误提示
- 自动恢复机制

当前 Lumi 项目已有一些错误处理（如 issue-09-error-handling.md 所述），但可以进一步系统化。

---

## 改进方案

### 1. 错误类型系统

```swift
/// 统一错误类型
enum LumiError: Error, LocalizedError {
    // 网络错误
    case networkError(underlying: Error, retryable: Bool)
    case timeout(duration: TimeInterval)
    case connectionLost
    
    // API 错误
    case apiError(code: Int, message: String)
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case invalidAPIKey
    case modelNotAvailable(model: String)
    
    // 文件错误
    case fileNotFound(path: String)
    case fileAccessDenied(path: String)
    case fileTooLarge(path: String, size: Int64, maxSize: Int64)
    
    // 工具错误
    case toolExecutionFailed(tool: String, reason: String)
    case toolTimeout(tool: String, timeout: TimeInterval)
    case toolNotAvailable(tool: String)
    
    // 权限错误
    case permissionDenied(action: String, resource: String)
    case sandboxViolation(path: String)
    
    // 配置错误
    case configurationError(key: String, reason: String)
    case missingConfiguration(key: String)
    
    // 其他
    case unknown(underlying: Error?)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error, _):
            return "网络错误: \(error.localizedDescription)"
        case .timeout(let duration):
            return "请求超时 (\(Int(duration))秒)"
        case .connectionLost:
            return "连接丢失"
        case .apiError(let code, let message):
            return "API 错误 (\(code)): \(message)"
        case .rateLimitExceeded(let retryAfter):
            if let retryAfter = retryAfter {
                return "请求过于频繁，请 \(Int(retryAfter)) 秒后重试"
            }
            return "请求过于频繁，请稍后重试"
        case .invalidAPIKey:
            return "API Key 无效"
        case .modelNotAvailable(let model):
            return "模型 \(model) 不可用"
        case .fileNotFound(let path):
            return "文件不存在: \(path)"
        case .fileAccessDenied(let path):
            return "无权访问文件: \(path)"
        case .fileTooLarge(let path, let size, let maxSize):
            return "文件过大: \(path) (\(size) > \(maxSize) 字节)"
        case .toolExecutionFailed(let tool, let reason):
            return "工具 \(tool) 执行失败: \(reason)"
        case .toolTimeout(let tool, let timeout):
            return "工具 \(tool) 执行超时 (\(Int(timeout))秒)"
        case .toolNotAvailable(let tool):
            return "工具 \(tool) 不可用"
        case .permissionDenied(let action, let resource):
            return "无权执行 \(action) 于 \(resource)"
        case .sandboxViolation(let path):
            return "沙盒限制: 无法访问 \(path)"
        case .configurationError(let key, let reason):
            return "配置错误 [\(key)]: \(reason)"
        case .missingConfiguration(let key):
            return "缺少配置: \(key)"
        case .unknown(let error):
            return "未知错误: \(error?.localizedDescription ?? "无详细信息")"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkError(_, let retryable):
            return retryable ? "请检查网络连接后重试" : "请稍后再试"
        case .timeout:
            return "请检查网络连接，或尝试使用更快的模型"
        case .connectionLost:
            return "正在尝试重新连接..."
        case .apiError(let code, _):
            if code == 401 { return "请检查 API Key 是否正确" }
            if code == 402 { return "请检查账户余额" }
            return "请联系支持团队"
        case .rateLimitExceeded:
            return "请等待后重试，或升级您的计划"
        case .invalidAPIKey:
            return "请在设置中更新您的 API Key"
        case .modelNotAvailable:
            return "请尝试使用其他模型"
        case .fileNotFound:
            return "请确认文件路径是否正确"
        case .fileAccessDenied:
            return "请检查文件权限"
        case .permissionDenied:
            return "请在设置中授权此操作"
        default:
            return nil
        }
    }
    
    /// 是否可重试
    var isRetryable: Bool {
        switch self {
        case .networkError(_, let retryable):
            return retryable
        case .timeout, .connectionLost, .rateLimitExceeded:
            return true
        case .apiError(let code, _):
            return code >= 500 // 服务端错误可重试
        default:
            return false
        }
    }
}
```

---

### 2. 重试策略

```swift
/// 重试策略
struct RetryStrategy {
    let maxAttempts: Int
    let initialDelay: TimeInterval
    let maxDelay: TimeInterval
    let multiplier: Double
    let jitter: Bool
    
    /// 默认策略
    static let `default` = RetryStrategy(
        maxAttempts: 3,
        initialDelay: 1.0,
        maxDelay: 30.0,
        multiplier: 2.0,
        jitter: true
    )
    
    /// 激进策略（快速重试）
    static let aggressive = RetryStrategy(
        maxAttempts: 5,
        initialDelay: 0.5,
        maxDelay: 10.0,
        multiplier: 1.5,
        jitter: true
    )
    
    /// 保守策略（慢速重试）
    static let conservative = RetryStrategy(
        maxAttempts: 3,
        initialDelay: 2.0,
        maxDelay: 60.0,
        multiplier: 2.0,
        jitter: true
    )
    
    /// 无重试
    static let none = RetryStrategy(
        maxAttempts: 1,
        initialDelay: 0,
        maxDelay: 0,
        multiplier: 1.0,
        jitter: false
    )
    
    /// 计算下次重试延迟
    func delay(for attempt: Int) -> TimeInterval {
        var delay = initialDelay * pow(multiplier, Double(attempt - 1))
        delay = min(delay, maxDelay)
        
        if jitter {
            // 添加随机抖动 ±20%
            let jitterRange = delay * 0.2
            delay += Double.random(in: -jitterRange...jitterRange)
        }
        
        return max(0, delay)
    }
}

/// 重试执行器
class RetryExecutor {
    /// 带重试执行异步操作
    func execute<T>(
        strategy: RetryStrategy = .default,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...strategy.maxAttempts {
            do {
                return try await operation()
            } catch let error as LumiError {
                lastError = error
                
                // 检查是否可重试
                guard error.isRetryable && attempt < strategy.maxAttempts else {
                    throw error
                }
                
                // 等待后重试
                let delay = strategy.delay(for: attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                // 通知重试
                NotificationCenter.default.post(
                    name: .willRetry,
                    object: nil,
                    userInfo: [
                        "attempt": attempt,
                        "delay": delay,
                        "error": error
                    ]
                )
            }
        }
        
        throw lastError ?? LumiError.unknown(nil)
    }
}
```

---

### 3. 错误恢复管理器

```swift
/// 错误恢复管理器
class ErrorRecoveryManager {
    private let retryExecutor = RetryExecutor()
    
    /// 错误恢复选项
    struct RecoveryOption {
        let title: String
        let action: () async throws -> Void
        let isDefault: Bool
    }
    
    /// 处理错误并尝试恢复
    func handleError(
        _ error: Error,
        context: ErrorContext,
        automaticRecovery: Bool = true
    ) async -> ErrorRecoveryResult {
        let lumiError = mapToLumiError(error)
        
        // 记录错误
        await ErrorLogger.shared.log(lumiError, context: context)
        
        // 尝试自动恢复
        if automaticRecovery && lumiError.isRetryable {
            let recovered = await attemptAutomaticRecovery(lumiError, context: context)
            if recovered {
                return .recovered
            }
        }
        
        // 返回恢复选项供用户选择
        let options = getRecoveryOptions(for: lumiError, context: context)
        
        return .requiresUserAction(
            error: lumiError,
            options: options
        )
    }
    
    /// 尝试自动恢复
    private func attemptAutomaticRecovery(
        _ error: LumiError,
        context: ErrorContext
    ) async -> Bool {
        switch error {
        case .connectionLost:
            return await attemptReconnect()
            
        case .rateLimitExceeded(let retryAfter):
            let delay = retryAfter ?? 5.0
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return await attemptRetry(context: context)
            
        case .timeout:
            // 尝试切换到更快的模型
            return await attemptFallbackModel(context: context)
            
        default:
            return false
        }
    }
    
    /// 获取恢复选项
    private func getRecoveryOptions(
        for error: LumiError,
        context: ErrorContext
    ) -> [RecoveryOption] {
        var options: [RecoveryOption] = []
        
        switch error {
        case .invalidAPIKey:
            options.append(RecoveryOption(
                title: "更新 API Key",
                action: { [weak self] in
                    await self?.openSettings(section: .apiKey)
                },
                isDefault: true
            ))
            
        case .modelNotAvailable:
            options.append(RecoveryOption(
                title: "切换到其他模型",
                action: { [weak self] in
                    await self?.showModelSelector()
                },
                isDefault: true
            ))
            
        case .fileNotFound:
            options.append(RecoveryOption(
                title: "浏览文件",
                action: { [weak self] in
                    await self?.showFileBrowser()
                },
                isDefault: false
            ))
            
        case .permissionDenied:
            options.append(RecoveryOption(
                title: "打开系统偏好设置",
                action: { [weak self] in
                    await self?.openSystemPreferences()
                },
                isDefault: true
            ))
            
        default:
            options.append(RecoveryOption(
                title: "重试",
                action: { [weak self] in
                    await self?.retryLastOperation()
                },
                isDefault: true
            ))
        }
        
        // 总是添加取消选项
        options.append(RecoveryOption(
            title: "取消",
            action: {},
            isDefault: false
        ))
        
        return options
    }
    
    /// 映射到 LumiError
    private func mapToLumiError(_ error: Error) -> LumiError {
        if let lumiError = error as? LumiError {
            return lumiError
        }
        
        // 根据 NSError 映射
        let nsError = error as NSError
        
        switch nsError.domain {
        case NSURLErrorDomain:
            switch nsError.code {
            case NSURLErrorTimedOut:
                return .timeout(duration: 30)
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return .networkError(underlying: error, retryable: true)
            default:
                return .networkError(underlying: error, retryable: true)
            }
        default:
            return .unknown(underlying: error)
        }
    }
}

/// 错误恢复结果
enum ErrorRecoveryResult {
    case recovered
    case requiresUserAction(error: LumiError, options: [ErrorRecoveryManager.RecoveryOption])
    case unrecoverable(error: LumiError)
}

/// 错误上下文
struct ErrorContext {
    let operation: String
    let timestamp: Date
    let conversationId: UUID?
    let projectId: String?
    let additionalInfo: [String: Any]
}
```

---

### 4. 错误 UI 展示

```swift
/// 错误提示视图
struct ErrorAlertView: View {
    let error: LumiError
    let options: [ErrorRecoveryManager.RecoveryOption]
    let onAction: (ErrorRecoveryManager.RecoveryOption) -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 错误图标和标题
            HStack(spacing: 12) {
                Image(systemName: errorIcon)
                    .font(.title)
                    .foregroundColor(errorColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(errorTitle)
                        .font(.headline)
                    
                    Text(error.errorDescription ?? "未知错误")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            
            // 恢复建议
            if let suggestion = error.recoverySuggestion {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb")
                        .foregroundColor(.yellow)
                    
                    Text(suggestion)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 44)
            }
            
            // 详细信息（可展开）
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    Text("详细信息")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(debugInfo)
                        .font(.system(.caption, design: .monospaced))
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            // 操作按钮
            HStack(spacing: 8) {
                ForEach(options.indices, id: \.self) { index in
                    let option = options[index]
                    
                    Button(option.title) {
                        onAction(option)
                    }
                    .buttonStyle(option.isDefault ? .borderedProminent : .bordered)
                }
                
                Spacer()
                
                Button(isExpanded ? "收起" : "详情") {
                    isExpanded.toggle()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .shadow(radius: 4)
    }
    
    private var errorIcon: String {
        switch error {
        case .networkError, .connectionLost, .timeout:
            return "wifi.slash"
        case .apiError, .rateLimitExceeded, .invalidAPIKey:
            return "exclamationmark.triangle"
        case .fileNotFound, .fileAccessDenied:
            return "doc.questionmark"
        case .permissionDenied:
            return "lock.shield"
        default:
            return "exclamationmark.circle"
        }
    }
    
    private var errorColor: Color {
        switch error {
        case .networkError, .connectionLost, .timeout:
            return .orange
        case .apiError, .rateLimitExceeded, .invalidAPIKey:
            return .red
        case .fileNotFound, .fileAccessDenied:
            return .blue
        case .permissionDenied:
            return .purple
        default:
            return .gray
        }
    }
    
    private var errorTitle: String {
        switch error {
        case .networkError, .connectionLost:
            return "网络问题"
        case .timeout:
            return "请求超时"
        case .apiError, .rateLimitExceeded, .invalidAPIKey:
            return "API 错误"
        case .fileNotFound:
            return "文件未找到"
        case .fileAccessDenied:
            return "访问被拒绝"
        case .permissionDenied:
            return "权限不足"
        default:
            return "发生错误"
        }
    }
    
    private var debugInfo: String {
        """
        错误类型: \(type(of: error))
        时间: \(Date().ISO8601Format())
        可重试: \(error.isRetryable ? "是" : "否")
        """
    }
}
```

---

### 5. 错误日志系统

```swift
/// 错误日志记录器
actor ErrorLogger {
    static let shared = ErrorLogger()
    
    private var logs: [ErrorLogEntry] = []
    private let maxLogCount = 1000
    
    /// 记录错误
    func log(_ error: LumiError, context: ErrorContext) {
        let entry = ErrorLogEntry(
            id: UUID(),
            error: error,
            context: context,
            timestamp: Date()
        )
        
        logs.append(entry)
        
        // 保持日志数量限制
        if logs.count > maxLogCount {
            logs.removeFirst(logs.count - maxLogCount)
        }
        
        // 同时写入系统日志
        os_log(
            .error,
            log: .default,
            "[Lumi Error] %{public}@ - Context: %{public}@",
            error.errorDescription ?? "Unknown",
            context.operation
        )
    }
    
    /// 获取最近的错误
    func getRecentErrors(limit: Int = 50) -> [ErrorLogEntry] {
        Array(logs.suffix(limit))
    }
    
    /// 获取错误统计
    func getErrorStatistics(since date: Date) -> ErrorStatistics {
        let recentLogs = logs.filter { $0.timestamp >= date }
        
        let byType = Dictionary(grouping: recentLogs) { type(of: $0.error) }
        let byHour = Dictionary(grouping: recentLogs) { 
            Calendar.current.component(.hour, from: $0.timestamp) 
        }
        
        return ErrorStatistics(
            totalErrors: recentLogs.count,
            byType: byType.mapValues { $0.count },
            byHour: byHour.mapValues { $0.count },
            mostFrequent: byType.max { $0.value.count < $1.value.count }?.key
        )
    }
    
    /// 导出错误日志
    func exportLogs() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(logs) else {
            return "Failed to export logs"
        }
        
        return String(data: data, encoding: .utf8) ?? "Failed to decode logs"
    }
    
    /// 清理日志
    func clearLogs() {
        logs.removeAll()
    }
}

/// 错误日志条目
struct ErrorLogEntry: Codable, Identifiable {
    let id: UUID
    let error: LumiError
    let context: ErrorContext
    let timestamp: Date
}

/// 错误统计
struct ErrorStatistics {
    let totalErrors: Int
    let byType: [String: Int]
    let byHour: [Int: Int]
    let mostFrequent: String?
}
```

---

### 6. 网络状态监控

```swift
/// 网络状态监控器
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var isConnected: Bool = true
    @Published var connectionType: ConnectionType = .unknown
    @Published var isExpensive: Bool = false
    @Published var isConstrained: Bool = false
    
    private let monitor = NWPathMonitor()
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.isExpensive = path.isExpensive
                self?.isConstrained = path.isConstrained
                
                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = .ethernet
                } else {
                    self?.connectionType = .unknown
                }
                
                // 通知网络状态变化
                NotificationCenter.default.post(
                    name: .networkStatusDidChange,
                    object: nil,
                    userInfo: [
                        "isConnected": self?.isConnected ?? false,
                        "connectionType": self?.connectionType ?? .unknown
                    ]
                )
            }
        }
        
        monitor.start(queue: DispatchQueue.global())
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
}
```

---

## 实施计划

### 阶段 1: 错误系统 (1 周)
1. 定义 `LumiError` 错误类型
2. 实现错误映射
3. 创建错误 UI 组件

### 阶段 2: 恢复机制 (1 周)
1. 实现重试策略
2. 实现自动恢复
3. 实现用户恢复选项

### 阶段 3: 监控和日志 (1 周)
1. 实现错误日志系统
2. 实现网络状态监控
3. 添加错误统计和分析

---

## 预期效果

1. **稳定性提升**: 自动恢复减少 80% 的用户干预
2. **用户体验**: 清晰的错误提示和恢复选项
3. **问题诊断**: 完整的错误日志帮助快速定位问题
4. **可靠性**: 网络波动不影响正常使用

---

## 参考资源

- [Swift Error Handling](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/errorhandling/)
- [NWPathMonitor](https://developer.apple.com/documentation/network/nwpathmonitor)
- [Exponential Backoff](https://en.wikipedia.org/wiki/Exponential_backoff)

---

*创建时间: 2026-03-13*