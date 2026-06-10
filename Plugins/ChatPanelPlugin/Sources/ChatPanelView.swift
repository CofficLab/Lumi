import AppKit
import LumiChatKit
import LumiCoreKit
import LumiUI
import SwiftUI

public struct ChatPanelView: View {
    @LumiTheme private var theme
    @ObservedObject private var chatService: ChatService
    private let currentProjectPath: String?
    private let localStore: LocalStore?

    public init(
        chatService: ChatService,
        currentProjectPath: String? = nil,
        databaseDirectory: URL? = nil
    ) {
        self.chatService = chatService
        self.currentProjectPath = currentProjectPath
        self.localStore = databaseDirectory.map { LocalStore(databaseDirectory: $0) }
    }

    public var body: some View {
        let conversations = chatService.conversations
        let selectedID = chatService.selectedConversationID ?? conversations.first?.id

        ChatConversationListView(
            conversations: conversations,
            selectedID: selectedID,
            currentProjectPath: currentProjectPath,
            isSending: { chatService.isSending(for: $0) },
            onCreateConversation: createConversation,
            onSelectConversation: selectConversation,
            onDeleteConversation: deleteConversation
        )
        .frame(minWidth: 260, idealWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .appSurface(style: .panel, cornerRadius: 0)
        .onAppear {
            ensureSelection(conversations: conversations)
        }
        .onChange(of: chatService.selectedConversationID) { _, newValue in
            localStore?.saveSelectedConversationID(newValue)
        }
    }

    private func createConversation() {
        _ = chatService.createConversation(title: nil)
    }

    private func selectConversation(_ id: UUID) {
        chatService.selectConversation(id: id)
    }

    private func deleteConversation(_ id: UUID) {
        chatService.deleteConversation(id: id)
    }

    private func ensureSelection(conversations: [LumiConversationSummary]) {
        if chatService.selectedConversationID != nil {
            return
        }
        if let savedID = localStore?.loadSelectedConversationID(),
           conversations.contains(where: { $0.id == savedID }) {
            chatService.selectConversation(id: savedID)
            return
        }
        if let first = conversations.first {
            chatService.selectConversation(id: first.id)
        }
    }
}
