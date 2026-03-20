import Combine
import Foundation
import SwiftUI

/// 流式 UI 刷新信号与当前会话流式快照（小 `ObservableObject`，供时间线等订阅）。
@MainActor
final class AgentStreamingRender: ObservableObject {
    @Published private(set) var streamingRenderVersion: Int = 0

    private let runtimeStore: ConversationRuntimeStore
    private let conversationVM: ConversationVM
    private var cancellables = Set<AnyCancellable>()

    init(runtimeStore: ConversationRuntimeStore, conversationVM: ConversationVM) {
        self.runtimeStore = runtimeStore
        self.conversationVM = conversationVM
        runtimeStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func bump() {
        streamingRenderVersion &+= 1
    }

    var currentStreamingMessageId: UUID? {
        guard let selectedId = conversationVM.selectedConversationId else { return nil }
        return runtimeStore.streamStateByConversation[selectedId]?.messageId
    }

    var activeStreamingMessageForSelectedConversation: ChatMessage? {
        guard let conversationId = conversationVM.selectedConversationId,
              let state = runtimeStore.streamStateByConversation[conversationId],
              let messageId = state.messageId
        else { return nil }
        let text = runtimeStore.streamingTextByConversation[conversationId] ?? ""
        return ChatMessage(id: messageId, role: .assistant, content: text, timestamp: Date())
    }
}
