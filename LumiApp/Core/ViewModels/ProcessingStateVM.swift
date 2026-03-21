import SwiftUI
import Foundation

/// 处理状态 ViewModel
@MainActor
final class ProcessingStateVM: ObservableObject {
    /// 是否正在处理
    @Published public fileprivate(set) var isProcessing: Bool = false

    /// 最后收到心跳的时间（用于动画效果）
    @Published public fileprivate(set) var lastHeartbeatTime: Date?

    /// 从开始到首 token 的耗时（毫秒），收到首 token 后设置
    /// 状态提示文本（用于 UI 展示）
    @Published public fileprivate(set) var statusText: String = ""

    /// 是否有需要展示的活动加载状态
    ///
    /// - 当正在处理且存在非空状态文案时为 true
    /// - 仅作为 UI 辅助，不参与业务逻辑判断
    var hasActiveLoading: Bool {
        isProcessing && !statusText.isEmpty
    }

    /// 设置是否正在处理
    func setIsProcessing(_ processing: Bool) {
        isProcessing = processing
    }

    /// 设置最后心跳时间
    func setLastHeartbeatTime(_ date: Date?) {
        lastHeartbeatTime = date
    }

    func markStreamStarted() {
        statusText = "等待响应…"
        setIsProcessing(true)
    }

    func markFirstToken(ttftMs: Double) {
        if ttftMs >= 1000 {
            statusText = String(format: "首 token %.1fs，生成中…", ttftMs / 1000.0)
        } else {
            statusText = String(format: "首 token %.0fms，生成中…", ttftMs)
        }
        setIsProcessing(true)
    }

    func markGenerating() {
        if statusText != "生成中…" {
            statusText = "生成中…"
        }
        setIsProcessing(true)
    }

    func finish() {
        statusText = ""
        setIsProcessing(false)
        setLastHeartbeatTime(nil)
    }
}
