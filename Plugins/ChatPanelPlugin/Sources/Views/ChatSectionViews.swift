import LumiChatKit
import LumiCoreKit
import LumiUI
import SwiftUI

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
                    coordinator.handleSlashCommand(suggestion.command, selectedID: selectedID)
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
                leadingToolbarItems: coordinator.chatSectionToolbarItems.filter {
                    $0.placement == .leading
                },
                trailingToolbarItems: coordinator.chatSectionToolbarItems.filter {
                    $0.placement == .trailing
                },
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
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("addToChat"))) { notification in
            if let path = notification.userInfo?["fileURL"] as? String, !path.isEmpty {
                coordinator.handleFileDrop(URL(fileURLWithPath: path))
                return
            }
            guard let userInfo = notification.userInfo,
                  let text = userInfo["text"] as? String,
                  !text.isEmpty else { return }
            coordinator.appendToDraft(text)
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
