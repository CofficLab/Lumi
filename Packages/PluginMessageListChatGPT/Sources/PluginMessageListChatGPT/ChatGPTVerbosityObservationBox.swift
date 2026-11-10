import Foundation
import ProviderChatSection
import ProviderConversation
import SwiftUI

@MainActor
final class ChatGPTVerbosityObservationBox {
    private let conversations: (any ConversationManaging)?
    private let chat: any ChatSectionProviding
    private let pluginID: String
    private let itemOrder: Int
    private let expectedVerbosity: ResponseVerbosity
    private let makeView: @MainActor @Sendable () -> AnyView
    private var conversationHandle: (any ConversationObserverHandle)?
    private var isRegistered = false

    init(
        conversations: (any ConversationManaging)?,
        chat: any ChatSectionProviding,
        pluginID: String,
        order: Int,
        expectedVerbosity: ResponseVerbosity,
        makeView: @escaping @MainActor @Sendable () -> AnyView
    ) {
        self.conversations = conversations
        self.chat = chat
        self.pluginID = pluginID
        self.itemOrder = order
        self.expectedVerbosity = expectedVerbosity
        self.makeView = makeView

        register()
        conversationHandle = conversations?.addConversationObserver { [weak self] event in
            switch event {
            case .verbosityChanged, .selected:
                self?.reevaluate()
            default:
                break
            }
        }
    }

    func cancel() {
        conversationHandle?.cancel()
        conversationHandle = nil
        if isRegistered {
            chat.removeItem(id: pluginID)
            isRegistered = false
        }
    }

    private func reevaluate() {
        chat.refreshItems()
    }

    private func register() {
        guard !isRegistered else { return }
        let conversations = conversations
        let expectedVerbosity = expectedVerbosity
        chat.addItems([
            ChatSectionItem(
                id: pluginID,
                order: itemOrder,
                scope: .global,
                exclusiveGroup: "message-list",
                fillsRemainingHeight: true,
                showsTrailingDivider: false,
                isActive: { @MainActor in
                    guard let selectedID = conversations?.selectedConversationID else { return false }
                    return conversations?.verbosity(for: selectedID) == expectedVerbosity
                },
                content: makeView
            )
        ])
        isRegistered = true
    }
}
