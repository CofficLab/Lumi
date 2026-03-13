import SwiftUI
import Foundation

/// 错误状态 ViewModel
/// 专门管理错误消息状态，避免因 AgentVM 其他状态变化导致不必要的视图重新渲染
@MainActor
final class ErrorStateVM: ObservableObject {
    /// 错误消息
    @Published public fileprivate(set) var errorMessage: String?

    /// 设置错误消息
    func setErrorMessage(_ message: String?) {
        errorMessage = message
    }
}
