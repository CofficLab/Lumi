import SwiftUI
import Foundation

/// 处理状态 ViewModel
/// 专门管理处理状态和心跳时间，避免因 AgentProvider 其他状态变化导致不必要的视图重新渲染
@MainActor
final class ProcessingStateViewModel: ObservableObject {
    /// 是否正在处理
    @Published public fileprivate(set) var isProcessing: Bool = false

    /// 最后收到心跳的时间（用于动画效果）
    @Published public fileprivate(set) var lastHeartbeatTime: Date?

    /// 设置是否正在处理
    func setIsProcessing(_ processing: Bool) {
        isProcessing = processing
    }

    /// 设置最后心跳时间
    func setLastHeartbeatTime(_ date: Date?) {
        lastHeartbeatTime = date
    }
}