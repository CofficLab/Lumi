import LumiChatKit
import LumiCoreKit
import LumiUI
import SwiftUI

struct ChatMessagesSectionView: View {
    @ObservedObject var coordinator: ChatSectionCoordinator

    var body: some View {
        let selectedID = coordinator.selectedConversationID
        let messages = selectedID.map { coordinator.displayedMessages(for: $0) } ?? []
        let isSending = coordinator.chatService.isSending(for: selectedID)

        VStack(spacing: 0) {
            ChatHeaderView(
                title: coordinator.selectedTitle(for: selectedID),
                isSending: isSending
            )

            ChatDivider(axis: .horizontal)

            ChatMessageListView(
                messages: messages,
                isSending: isSending,
                hasEarlierMessages: selectedID.map {
                    coordinator.chatService.hasEarlierMessages(for: $0, beforeMessageID: coordinator.oldestVisibleMessageID)
                } ?? false,
                rendererForMessage: { coordinator.chatService.renderer(for: $0) },
                rawMessageBinding: coordinator.rawMessageBinding(for:),
                onUseAsDraft: { message in
                    coordinator.draft = message.content
                },
                onResend: { message in
                    guard let selectedID else { return }
                    Task {
                        await coordinator.chatService.resendMessage(id: message.id, in: selectedID)
                    }
                },
                onDelete: { message in
                    guard let selectedID else { return }
                    coordinator.chatService.deleteMessage(id: message.id, in: selectedID)
                },
                onLoadEarlier: coordinator.loadEarlierMessages,
                onQuickStart: { prompt in
                    coordinator.draft = prompt
                    coordinator.send()
                },
                automationLevel: coordinator.chatService.automationLevel(for: selectedID)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: coordinator.chatService.selectedConversationID) { _, _ in
            coordinator.resetOldestVisibleMessageID()
        }
    }
}

struct ChatPendingSectionView: View {
    @ObservedObject var coordinator: ChatSectionCoordinator

    var body: some View {
        let selectedID = coordinator.selectedConversationID
        let pending = selectedID.map { coordinator.pendingMessages(for: $0) } ?? []

        Group {
            if !pending.isEmpty {
                ChatPendingMessagesView(
                    messages: pending,
                    onRemove: { coordinator.chatService.removePendingMessage(id: $0) }
                )
            }
        }
    }
}

struct ChatAttachmentSectionView: View {
    @ObservedObject var coordinator: ChatSectionCoordinator

    var body: some View {
        ChatAttachmentPreviewView(
            attachments: coordinator.imageAttachments,
            onRemove: { id in
                coordinator.imageAttachments.removeAll { $0.id == id }
            }
        )
    }
}

struct ChatComposerSectionView: View {
    @ObservedObject var coordinator: ChatSectionCoordinator

    var body: some View {
        let selectedID = coordinator.selectedConversationID
        let conversations = coordinator.chatService.conversations
        let isSending = coordinator.chatService.isSending(for: selectedID)

        VStack(spacing: 0) {
            ChatCommandSuggestionsView(
                suggestions: ChatSlashCommand.suggestions(for: coordinator.draft),
                isVisible: coordinator.showCommandSuggestions,
                onSelect: { suggestion in
                    coordinator.handleSlashCommand(suggestion, selectedID: selectedID)
                }
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 4)

            ComposerView(
                text: $coordinator.draft,
                inputHeight: $coordinator.inputHeight,
                isInputFocused: $coordinator.isInputFocused,
                inputCursorPosition: $coordinator.inputCursorPosition,
                isImageDragHovering: $coordinator.isImageDragHovering,
                isSending: isSending,
                hasConversation: selectedID != nil || !conversations.isEmpty,
                hasAttachments: !coordinator.imageAttachments.isEmpty,
                languagePicker: {
                    ChatLanguagePicker(
                        selectedLanguage: coordinator.chatService.language(for: selectedID),
                        onSelect: { coordinator.chatService.setLanguage($0, for: selectedID) }
                    )
                },
                automationPicker: {
                    ChatAutomationLevelPicker(
                        selectedLevel: coordinator.chatService.automationLevel(for: selectedID),
                        onSelect: { coordinator.chatService.setAutomationLevel($0, for: selectedID) }
                    )
                },
                providerPicker: {
                    ChatProviderPicker(
                        chatService: coordinator.chatService,
                        conversationID: selectedID,
                        onChange: {}
                    )
                },
                verbosityPicker: {
                    ChatVerbosityPicker(
                        selectedLevel: coordinator.chatService.verbosity(for: selectedID),
                        onSelect: { coordinator.chatService.setVerbosity($0, for: selectedID) }
                    )
                },
                onAttachImage: coordinator.selectImageAttachment,
                onFileDrop: coordinator.handleFileDrop,
                onSend: coordinator.send,
                onStop: { coordinator.chatService.cancelSending(for: selectedID) },
                onEscape: { coordinator.chatService.cancelSending(for: selectedID) }
            )
        }
        .onChange(of: coordinator.draft) { _, _ in
            coordinator.bindDraftChanges()
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumiFocusChatInput)) { _ in
            coordinator.isInputFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumiSendChatMessage)) { _ in
            coordinator.send()
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumiStopChatGeneration)) { _ in
            coordinator.chatService.cancelSending(for: selectedID)
        }
        .onReceive(NotificationCenter.default.publisher(for: .screenshotCaptured)) { notification in
            guard let data = notification.userInfo?["data"] as? Data else { return }
            coordinator.addImageAttachment(data: data)
        }
        .alert(
            "Approve high-risk tool?",
            isPresented: Binding(
                get: { coordinator.chatService.pendingToolConfirmation != nil },
                set: { isPresented in
                    if !isPresented {
                        coordinator.chatService.rejectPendingTool()
                    }
                }
            ),
            presenting: coordinator.chatService.pendingToolConfirmation
        ) { _ in
            Button("Approve", role: .none) {
                coordinator.chatService.approvePendingTool()
            }
            Button("Reject", role: .cancel) {
                coordinator.chatService.rejectPendingTool()
            }
        } message: { confirmation in
            Text(confirmation.displayDescription)
        }
    }
}
