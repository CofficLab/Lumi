# Issue #16: 缺少请求超时用户反馈

**严重程度**: 🟡 Medium  
**状态**: Open  
**文件**: `LumiApp/Core/Services/LLM/LLMAPIService.swift`, UI 相关文件

---

## 问题描述

当前设置了 300 秒（5 分钟）的请求超时，但缺少用户反馈机制，用户可能不知道请求正在进行中或已超时。

---

## 当前代码

```swift
class LLMAPIService: SuperLog, @unchecked Sendable {
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300  // 5 分钟超时
        configuration.timeoutIntervalForResource = 600  // 10 分钟资源超时
        // ...
    }
}
```

---

## 问题分析

### 1. 用户不知道发生了什么

- 发送请求后没有明确的加载指示
- 不知道请求需要多长时间
- 不知道是否还在进行中

### 2. 超时后缺少友好提示

- 用户可能认为应用卡死
- 没有重试选项
- 没有取消选项

### 3. 长时间等待的焦虑

- 5 分钟的等待对用户来说很长
- 没有进度反馈
- 无法估计剩余时间

---

## 建议修复

### 1. 请求状态管理

```swift
/// 请求状态
enum RequestState {
    case idle
    case connecting
    case sending
    case waitingResponse
    case receiving
    case completed
    case failed(Error)
    case timedOut
    case cancelled
    
    var description: String {
        switch self {
        case .idle: return "空闲"
        case .connecting: return "连接中..."
        case .sending: return "发送请求..."
        case .waitingResponse: return "等待响应..."
        case .receiving: return "接收数据..."
        case .completed: return "完成"
        case .failed: return "失败"
        case .timedOut: return "超时"
        case .cancelled: return "已取消"
        }
    }
    
    var icon: String {
        switch self {
        case .idle: return "circle"
        case .connecting, .sending, .waitingResponse, .receiving:
            return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle"
        case .failed, .timedOut: return "xmark.circle"
        case .cancelled: return "minus.circle"
        }
    }
}

/// 请求进度
struct RequestProgress {
    let state: RequestState
    let startTime: Date
    let bytesSent: Int64?
    let bytesReceived: Int64?
    let totalBytes: Int64?
    
    var elapsedTime: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
    
    var estimatedTimeRemaining: TimeInterval? {
        // 基于传输速率估算
        guard let sent = bytesSent,
              let total = totalBytes,
              sent > 0 else {
            return nil
        }
        
        let rate = Double(sent) / elapsedTime
        let remaining = Double(total - sent) / rate
        return remaining
    }
}
```

### 2. 请求状态发布者

```swift
/// 请求状态管理器
@MainActor
class RequestStatePublisher: ObservableObject {
    @Published var currentRequest: String?
    @Published var state: RequestState = .idle
    @Published var progress: RequestProgress?
    
    private var requestStartTime: Date?
    
    func startRequest(description: String) {
        currentRequest = description
        state = .connecting
        requestStartTime = Date()
        updateProgress()
    }
    
    func updateState(_ newState: RequestState) {
        state = newState
        updateProgress()
    }
    
    func completeRequest() {
        state = .completed
        currentRequest = nil
        progress = nil
        requestStartTime = nil
    }
    
    func failRequest(with error: Error) {
        if isTimeoutError(error) {
            state = .timedOut
        } else {
            state = .failed(error)
        }
    }
    
    private func updateProgress() {
        guard let startTime = requestStartTime else { return }
        
        progress = RequestProgress(
            state: state,
            startTime: startTime,
            bytesSent: nil,
            bytesReceived: nil,
            totalBytes: nil
        )
    }
    
    private func isTimeoutError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut
    }
}
```

### 3. UI 反馈组件

```swift
/// 请求状态视图
struct RequestStatusView: View {
    @ObservedObject var statePublisher: RequestStatePublisher
    @State private var showCancelConfirm = false
    
    var body: some View {
        if let request = statePublisher.currentRequest {
            VStack(spacing: 12) {
                // 状态图标和文字
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(request)
                            .font(.headline)
                        
                        Text(statePublisher.state.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // 耗时显示
                    if let progress = statePublisher.progress {
                        Text(formatTime(progress.elapsedTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 进度条（如果有）
                if let progress = statePublisher.progress,
                   let total = progress.totalBytes,
                   let received = progress.bytesReceived {
                    ProgressView(value: Double(received), total: Double(total))
                        .progressViewStyle(.linear)
                    
                    HStack {
                        Text("\(ByteCountFormatter.string(fromByteCount: received, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if let remaining = progress.estimatedTimeRemaining {
                            Text("剩余约 \(formatTime(remaining))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 操作按钮
                HStack {
                    Button("取消") {
                        showCancelConfirm = true
                    }
                    .buttonStyle(.bordered)
                    
                    if statePublisher.state == .timedOut || statePublisher.state == .failed {
                        Button("重试") {
                            // 触发重试
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .shadow(radius: 2)
            .confirmationDialog("确认取消？", isPresented: $showCancelConfirm) {
                Button("取消请求", role: .destructive) {
                    // 执行取消
                }
                Button("继续等待", role: .cancel) {}
            }
        }
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        
        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }
}
```

### 4. 超时警告机制

```swift
/// 超时警告管理器
class TimeoutWarningManager {
    let warningThreshold: TimeInterval = 60  // 1 分钟后显示警告
    let timeoutThreshold: TimeInterval = 300  // 5 分钟超时
    
    private var timer: Timer?
    private var warningShown = false
    
    func startMonitoring(
        onRequestTimeout: @escaping () -> Void,
        onWarning: @escaping (TimeInterval) -> Void
    ) {
        warningShown = false
        
        // 警告计时器
        timer = Timer.scheduledTimer(withTimeInterval: warningThreshold, repeats: false) { [weak self] _ in
            guard let self = self, !self.warningShown else { return }
            self.warningShown = true
            onWarning(self.timeoutThreshold - self.warningThreshold)
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
}
```

### 5. 集成到 LLMAPIService

```swift
class LLMAPIService: SuperLog, @unchecked Sendable {
    @MainActor
    private weak var statePublisher: RequestStatePublisher?
    
    func setStatePublisher(_ publisher: RequestStatePublisher) {
        statePublisher = publisher
    }
    
    func sendChatRequest(
        url: URL,
        apiKey: String,
        body: [String: Any]
    ) async throws -> Data {
        // 更新状态
        await MainActor.run {
            statePublisher?.startRequest(description: "AI 正在思考...")
        }
        
        do {
            await MainActor.run {
                statePublisher?.updateState(.sending)
            }
            
            let data = try await sendRawRequestWithRetry(...)
            
            await MainActor.run {
                statePublisher?.updateState(.receiving)
            }
            
            return data
        } catch let error as URLError where error.code == .timedOut {
            await MainActor.run {
                statePublisher?.failRequest(with: error)
            }
            throw APIError.timeout
        } catch {
            await MainActor.run {
                statePublisher?.failRequest(with: error)
            }
            throw error
        }
    }
}
```

---

## 用户体验改进

1. **明确的加载指示** - 用户知道请求正在进行
2. **实时进度反馈** - 用户了解请求进展
3. **超时友好提示** - 用户知道发生了什么
4. **重试选项** - 用户可以轻松重试
5. **取消选项** - 用户可以中止请求

---

## 修复优先级

中 - 影响用户体验，但不影响核心功能

---

*创建时间: 2026-03-13*