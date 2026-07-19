import Foundation

/// 聊天服务能力协议
///
/// 定义 LumiCore 需要的聊天服务功能，由 LumiCoreChat 实现。
@MainActor
public protocol ChatServiceProviding: ObservableObject {
    /// 当前选中的 Provider ID
    var selectedProviderID: String? { get }

    /// 发送消息
    func sendMessage(_ content: String, conversationID: UUID) async throws

    /// 取消当前请求
    func cancelCurrentRequest()
}