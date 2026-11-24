import Foundation
import ProviderAgentLoop
import ProviderChatSection
import ProviderConversation
import SwiftUI

/// The interaction data needed by the chat section view.
struct AskUserPendingInteraction: Equatable, Sendable {
    let response: AskUserPendingResponse
    let toolCallID: String
    let conversationID: UUID
    let initialAnswer: String?

    /// SwiftUI 视图身份（供 `.id` 使用），必须同时含 `conversationID` 与 `toolCallID`。
    ///
    /// 同一个 `toolCallID`（如 `call_0`）在不同会话里都合法。若只用 `toolCallID`
    /// 作 `.id`，从会话 A 切到 B 时 SwiftUI 会复用旧视图实例及其 `@State`
    /// （`answer`/`responded`），让 B 的问题卡片继承 A 的未发送草稿，甚至继承
    /// A 的 `responded=true` 而错误禁用 B 的输入（#483）。含会话 ID 后跨会话切换
    /// 必然改变身份，SwiftUI 重建视图、状态归零；同一会话同一 tool call 的身份
    /// 保持稳定，重新 synchronize 不会清掉用户正在输入的草稿。
    var viewIdentity: String {
        "\(conversationID.uuidString)|\(toolCallID)"
    }

    /// Suspension payloads are owned by the agent loop, so the chat UI does not
    /// need to inspect the message list or duplicate tool-call lookup logic.
    static func from(suspension: AgentLoopSuspension) -> Self? {
        guard suspension.kind == "userInput",
              let toolCallID = suspension.toolCallID,
              !toolCallID.isEmpty,
              let data = suspension.payload.data(using: .utf8),
              let response = try? JSONDecoder().decode(
                  AskUserPendingResponse.self,
                  from: data
              ) else {
            return nil
        }
        return Self(
            response: response,
            toolCallID: toolCallID,
            conversationID: suspension.conversationID,
            initialAnswer: nil
        )
    }

    static func shouldShow(
        selectedConversationID: UUID?,
        interaction: Self?
    ) -> Bool {
        guard let selectedConversationID,
              let interaction else { return false }
        return selectedConversationID == interaction.conversationID
    }
}

/// Owns the currently pending ask_user interaction for the selected chat.
@MainActor
final class AskUserChatViewModel: ObservableObject {
    @Published private(set) var interaction: AskUserPendingInteraction?
    @Published private(set) var selectedConversationID: UUID?

    private let conversations: any ConversationManaging
    private let agentLoop: any AgentLoopProviding
    private var selectedConversationObserver: (any SelectedConversationObserverHandle)?
    private var agentLoopObserver: (any AgentLoopObserverHandle)?

    init(
        conversations: any ConversationManaging,
        agentLoop: any AgentLoopProviding
    ) {
        self.conversations = conversations
        self.agentLoop = agentLoop
        self.selectedConversationID = conversations.selectedConversationID
        synchronize()

        selectedConversationObserver = conversations.addSelectedConversationObserver { [weak self] _ in
            self?.synchronize()
        }
        agentLoopObserver = agentLoop.addAgentLoopObserver { [weak self] event in
            self?.handle(event)
        }
    }

    func cancel() {
        selectedConversationObserver?.cancel()
        selectedConversationObserver = nil
        agentLoopObserver?.cancel()
        agentLoopObserver = nil
        interaction = nil
        selectedConversationID = nil
    }

    private func handle(_ event: AgentLoopEvent) {
        let conversationID: UUID
        switch event {
        case let .started(id, _),
             let .resumed(id, _),
             let .toolCallsReceived(id, _, _, _),
             let .llmResponseReceived(id, _, _),
             let .suspended(id, _, _),
             let .completed(id, _),
             let .failed(id, _, _),
             let .cancelled(id, _):
            conversationID = id
        }

        guard conversationID == conversations.selectedConversationID else { return }
        synchronize()
    }

    private func synchronize() {
        let conversationID = conversations.selectedConversationID
        selectedConversationID = conversationID

        guard let conversationID,
              let suspension = agentLoop.suspension(for: conversationID),
              let next = AskUserPendingInteraction.from(suspension: suspension)
        else {
            interaction = nil
            return
        }
        interaction = next
    }
}

/// ChatSection contribution that always shows pending ask_user interactions
/// at the bottom of the chat, regardless of response verbosity.
struct AskUserChatSectionView: View {
    @ObservedObject var viewModel: AskUserChatViewModel

    var body: some View {
        if let interaction = viewModel.interaction,
           AskUserPendingInteraction.shouldShow(
               selectedConversationID: viewModel.selectedConversationID,
               interaction: interaction
           ) {
            AskUserPendingView(interaction: interaction)
                .id(interaction.viewIdentity)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        } else {
            EmptyView()
        }
    }
}
