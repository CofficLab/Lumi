import SwiftUI
import Foundation

/// 思考状态 ViewModel
/// 专门管理思考状态和思考文本，避免因 AgentProvider 其他状态变化导致不必要的视图重新渲染
@MainActor
final class ThinkingStateViewModel: ObservableObject {
    /// 是否正在思考（用于显示思考状态）
    @Published public fileprivate(set) var isThinking: Bool = false

    /// 当前思考过程文本
    @Published public fileprivate(set) var thinkingText: String = ""

    /// 设置思考状态
    func setIsThinking(_ thinking: Bool) {
        isThinking = thinking
    }

    /// 追加思考文本
    func appendThinkingText(_ text: String) {
        thinkingText += text
    }

    /// 设置思考文本
    func setThinkingText(_ text: String) {
        thinkingText = text
    }
}