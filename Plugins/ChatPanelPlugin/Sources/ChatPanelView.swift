import LumiCoreKit
import LumiUI
import SwiftUI

public struct ChatPanelView: View {
    @LumiTheme private var theme
    private let chatService: any LumiChatServicing

    @State private var draft = ""
    @State private var refreshToken = 0
    @State private var rawMessageIDs: Set<UUID> = []
    @State private var isSending = false

    public init(chatService: any LumiChatServicing) {
        self.chatService = chatService
    }

    public var body: some View {
        let _ = refreshToken
        let conversations = chatService.conversations
        let selectedID = chatService.selectedConversationID ?? conversations.first?.id
        let messages = selectedID.map { chatService.messages(for: $0) } ?? []

        HStack(spacing: 0) {
            ChatConversationListView(
                conversations: conversations,
                selectedID: selectedID,
                onCreateConversation: createConversation,
                onSelectConversation: selectConversation,
                onDeleteConversation: deleteConversation
            )
            .frame(width: 286)

            ChatDivider(axis: .vertical)

            VStack(spacing: 0) {
                ChatHeaderView(
                    title: selectedTitle(for: selectedID),
                    isSending: isSending
                )

                ChatDivider(axis: .horizontal)

                ChatMessageListView(
                    messages: messages,
                    isSending: isSending,
                    rendererForMessage: { chatService.renderer(for: $0) },
                    rawMessageBinding: rawMessageBinding(for:),
                    onUseAsDraft: { message in
                        draft = message.content
                    }
                )

                ChatDivider(axis: .horizontal)

                ChatComposerView(
                    text: $draft,
                    isSending: isSending,
                    hasConversation: selectedID != nil || !conversations.isEmpty,
                    languagePicker: {
                        ChatLanguagePicker(
                            selectedLanguage: chatService.language(for: selectedID),
                            onSelect: { language in
                                chatService.setLanguage(language, for: selectedID)
                                refresh()
                            }
                        )
                    },
                    automationPicker: {
                        ChatAutomationLevelPicker(
                            selectedLevel: chatService.automationLevel(for: selectedID),
                            onSelect: { level in
                                chatService.setAutomationLevel(level, for: selectedID)
                                refresh()
                            }
                        )
                    },
                    providerPicker: {
                        ChatProviderPicker(chatService: chatService, onChange: refresh)
                    },
                    verbosityPicker: {
                        ChatVerbosityPicker(
                            selectedLevel: chatService.verbosity(for: selectedID),
                            onSelect: { level in
                                chatService.setVerbosity(level, for: selectedID)
                                refresh()
                            }
                        )
                    },
                    onScreenshot: {},
                    onAttachImage: {},
                    onSend: {
                        send(selectedID: selectedID)
                    }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appSurface(style: .panel, cornerRadius: 0)
        .onAppear {
            ensureSelection(conversations: conversations)
        }
    }

    private func createConversation() {
        _ = chatService.createConversation(title: nil)
        refresh()
    }

    private func selectConversation(_ id: UUID) {
        chatService.selectConversation(id: id)
        refresh()
    }

    private func deleteConversation(_ id: UUID) {
        chatService.deleteConversation(id: id)
        refresh()
    }

    private func send(selectedID: UUID?) {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else {
            return
        }

        draft = ""
        isSending = true
        refresh()

        Task { @MainActor in
            await chatService.send(text, in: selectedID)
            isSending = false
            refresh()
        }
    }

    private func ensureSelection(conversations: [LumiConversationSummary]) {
        if chatService.selectedConversationID == nil,
           let first = conversations.first {
            chatService.selectConversation(id: first.id)
            refresh()
        }
    }

    private func selectedTitle(for id: UUID?) -> String {
        guard let id,
              let conversation = chatService.conversations.first(where: { $0.id == id })
        else {
            return "Chat"
        }
        return conversation.title
    }

    private func rawMessageBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { rawMessageIDs.contains(id) },
            set: { isPresented in
                if isPresented {
                    rawMessageIDs.insert(id)
                } else {
                    rawMessageIDs.remove(id)
                }
            }
        )
    }

    private func refresh() {
        refreshToken += 1
    }
}
