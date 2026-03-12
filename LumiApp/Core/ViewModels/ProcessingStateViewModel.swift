import SwiftUI
import Foundation

/// 处理状态 ViewModel
/// 专门管理处理状态和心跳时间，避免因 AgentProvider 其他状态变化导致不必要的视图重新渲染
@MainActor
final class ProcessingStateViewModel: ObservableObject {
    enum Phase: String, Sendable {
        case idle
        case sending
        case waitingFirstToken
        case generating
        case finishing
    }

    /// 是否正在处理
    @Published public fileprivate(set) var isProcessing: Bool = false

    /// 最后收到心跳的时间（用于动画效果）
    @Published public fileprivate(set) var lastHeartbeatTime: Date?

    /// 当前处理阶段（用于 UI 展示）
    @Published public fileprivate(set) var phase: Phase = .idle

    /// 从开始到首 token 的耗时（毫秒），收到首 token 后设置
    @Published public fileprivate(set) var timeToFirstTokenMs: Double?

    /// 状态提示文本（用于 UI 展示）
    @Published public fileprivate(set) var statusText: String = ""

    /// 设置是否正在处理
    func setIsProcessing(_ processing: Bool) {
        isProcessing = processing
    }

    /// 设置最后心跳时间
    func setLastHeartbeatTime(_ date: Date?) {
        lastHeartbeatTime = date
    }

    func beginSending() {
        phase = .sending
        statusText = "连接中…"
        timeToFirstTokenMs = nil
        setIsProcessing(true)
    }

    func markStreamStarted() {
        phase = .waitingFirstToken
        statusText = "等待响应…"
        timeToFirstTokenMs = nil
        setIsProcessing(true)
    }

    func markFirstToken(ttftMs: Double) {
        timeToFirstTokenMs = ttftMs
        phase = .generating
        if ttftMs >= 1000 {
            statusText = String(format: "首 token %.1fs，生成中…", ttftMs / 1000.0)
        } else {
            statusText = String(format: "首 token %.0fms，生成中…", ttftMs)
        }
        setIsProcessing(true)
    }

    func markGenerating() {
        if phase != .generating {
            phase = .generating
            statusText = "生成中…"
        }
        setIsProcessing(true)
    }

    func finish() {
        phase = .idle
        statusText = ""
        timeToFirstTokenMs = nil
        setIsProcessing(false)
        setLastHeartbeatTime(nil)
    }
}