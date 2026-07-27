import Foundation
import LumiKernel

/// 聊天服务实现
@MainActor
public final class ChatService: ChatServiceProviding {

    /// 当前选中的 Provider ID
    @Published public var selectedProviderID: String?

    public init() {}

    public func sendMessage(_ content: String, conversationID: UUID) async throws {
        // TODO: 实现消息发送逻辑
    }

    public func cancelCurrentRequest() {
        // TODO: 实现取消请求逻辑
    }
}