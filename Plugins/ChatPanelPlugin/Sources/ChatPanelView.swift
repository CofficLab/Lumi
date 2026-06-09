import AppKit
import ChatInputEditorKit
import LumiChatKit
import LumiCoreKit
import LumiUI
import SwiftUI
import UniformTypeIdentifiers

public struct ChatPanelView: View {
    @LumiTheme private var theme
    @ObservedObject private var chatService: LumiChatService
    private let currentProjectPath: String?
    private let localStore: LocalStore?

    @State private var draft = ""
    @State private var rawMessageIDs: Set<UUID> = []
    @State private var oldestVisibleMessageID: UUID?
    @State private var inputHeight: CGFloat = ChatInputEditorView.minHeight
    @State private var isInputFocused = false
    @State private var inputCursorPosition = 0
    @State private var isImageDragHovering = false
    @State private var imageAttachments: [LumiImageAttachment] = []
    @State private var showCommandSuggestions = false
    public init(
        chatService: LumiChatService,
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
        let statusRevision = chatService.revision
        let messages = selectedID.map { displayedMessages(for: $0, statusRevision: statusRevision) } ?? []
        let isSending = chatService.isSending(for: selectedID)
        let pending = selectedID.map { pendingMessages(for: $0) } ?? []

        HStack(spacing: 0) {
            ChatConversationListView(
                conversations: conversations,
                selectedID: selectedID,
                currentProjectPath: currentProjectPath,
                isSending: { chatService.isSending(for: $0) },
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
                    hasEarlierMessages: selectedID.map {
                        chatService.hasEarlierMessages(for: $0, beforeMessageID: oldestVisibleMessageID)
                    } ?? false,
                    rendererForMessage: { chatService.renderer(for: $0) },
                    rawMessageBinding: rawMessageBinding(for:),
                    onUseAsDraft: { message in
                        draft = message.content
                    },
                    onResend: { message in
                        guard let selectedID else { return }
                        Task {
                            await chatService.resendMessage(id: message.id, in: selectedID)
                        }
                    },
                    onDelete: { message in
                        guard let selectedID else { return }
                        chatService.deleteMessage(id: message.id, in: selectedID)
                    },
                    onLoadEarlier: loadEarlierMessages,
                    onQuickStart: { prompt in
                        draft = prompt
                        send(selectedID: selectedID)
                    },
                    automationLevel: chatService.automationLevel(for: selectedID)
                )

                ChatDivider(axis: .horizontal)

                if !pending.isEmpty {
                    ChatPendingMessagesView(
                        messages: pending,
                        onRemove: { chatService.removePendingMessage(id: $0) }
                    )
                    ChatDivider(axis: .horizontal)
                }

                ChatAttachmentPreviewView(
                    attachments: imageAttachments,
                    onRemove: { id in
                        imageAttachments.removeAll { $0.id == id }
                    }
                )

                ChatCommandSuggestionsView(
                    suggestions: ChatSlashCommand.suggestions(for: draft),
                    isVisible: showCommandSuggestions,
                    onSelect: { suggestion in
                        handleSlashCommand(suggestion, selectedID: selectedID)
                    }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 4)

                ChatComposerView(
                    text: $draft,
                    inputHeight: $inputHeight,
                    isInputFocused: $isInputFocused,
                    inputCursorPosition: $inputCursorPosition,
                    isImageDragHovering: $isImageDragHovering,
                    isSending: isSending,
                    hasConversation: selectedID != nil || !conversations.isEmpty,
                    hasAttachments: !imageAttachments.isEmpty,
                    languagePicker: {
                        ChatLanguagePicker(
                            selectedLanguage: chatService.language(for: selectedID),
                            onSelect: { chatService.setLanguage($0, for: selectedID) }
                        )
                    },
                    automationPicker: {
                        ChatAutomationLevelPicker(
                            selectedLevel: chatService.automationLevel(for: selectedID),
                            onSelect: { chatService.setAutomationLevel($0, for: selectedID) }
                        )
                    },
                    providerPicker: {
                        ChatProviderPicker(
                            chatService: chatService,
                            conversationID: selectedID,
                            onChange: {}
                        )
                    },
                    verbosityPicker: {
                        ChatVerbosityPicker(
                            selectedLevel: chatService.verbosity(for: selectedID),
                            onSelect: { chatService.setVerbosity($0, for: selectedID) }
                        )
                    },
                    onAttachImage: { selectImageAttachment() },
                    onFileDrop: handleFileDrop,
                    onSend: { send(selectedID: selectedID) },
                    onStop: { chatService.cancelSending(for: selectedID) },
                    onEscape: { chatService.cancelSending(for: selectedID) }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appSurface(style: .panel, cornerRadius: 0)
        .onAppear {
            ensureSelection(conversations: conversations)
        }
        .onChange(of: chatService.selectedConversationID) { _, newValue in
            localStore?.saveSelectedConversationID(newValue)
        }
        .onChange(of: selectedID) { _, _ in
            oldestVisibleMessageID = nil
        }
        .onChange(of: draft) { _, newValue in
            showCommandSuggestions = newValue.hasPrefix("/")
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumiFocusChatInput)) { _ in
            isInputFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumiSendChatMessage)) { _ in
            send(selectedID: selectedID)
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumiStopChatGeneration)) { _ in
            chatService.cancelSending(for: selectedID)
        }
        .onReceive(NotificationCenter.default.publisher(for: .screenshotCaptured)) { notification in
            guard let data = notification.userInfo?["data"] as? Data else {
                return
            }
            addImageAttachment(data: data)
        }
        .alert(
            "Approve high-risk tool?",
            isPresented: Binding(
                get: { chatService.pendingToolConfirmation != nil },
                set: { isPresented in
                    if !isPresented {
                        chatService.rejectPendingTool()
                    }
                }
            ),
            presenting: chatService.pendingToolConfirmation
        ) { confirmation in
            Button("Approve", role: .none) {
                chatService.approvePendingTool()
            }
            Button("Reject", role: .cancel) {
                chatService.rejectPendingTool()
            }
        } message: { confirmation in
            Text(confirmation.displayDescription)
        }
    }

    private func displayedMessages(for conversationID: UUID, statusRevision: Int) -> [LumiChatMessage] {
        _ = statusRevision

        let transientStatus = chatService.transientStatusMessage(for: conversationID)
        let page: [LumiChatMessage]
        if let oldestVisibleMessageID {
            page = chatService.visibleMessages(
                for: conversationID,
                limit: 10,
                beforeMessageID: oldestVisibleMessageID
            )
        } else {
            let persisted = chatService.messages(for: conversationID).filter {
                $0.role != .tool && ($0.role != .status || $0.renderKind == "turn-completed")
            }
            page = Array(persisted.suffix(10))
        }

        guard let transientStatus else {
            return page
        }
        return page + [transientStatus]
    }

    private func pendingMessages(for conversationID: UUID) -> [LumiPendingMessage] {
        chatService.pendingMessages.filter { $0.conversationID == conversationID }
    }

    private func loadEarlierMessages() {
        guard let selectedID = chatService.selectedConversationID ?? chatService.conversations.first?.id else {
            return
        }
        let persisted = chatService.messages(for: selectedID).filter { $0.role != .tool && $0.role != .status }
        if let oldestVisibleMessageID {
            if let index = persisted.firstIndex(where: { $0.id == oldestVisibleMessageID }), index > 0 {
                self.oldestVisibleMessageID = persisted[max(0, index - 10)].id
            }
        } else if let first = persisted.first {
            oldestVisibleMessageID = first.id
        }
    }

    private func createConversation() {
        _ = chatService.createConversation(title: nil)
    }

    private func selectConversation(_ id: UUID) {
        chatService.selectConversation(id: id)
        oldestVisibleMessageID = nil
    }

    private func deleteConversation(_ id: UUID) {
        chatService.deleteConversation(id: id)
    }

    private func send(selectedID: UUID?) {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !imageAttachments.isEmpty else {
            return
        }
        if text.hasPrefix("/") {
            if let command = ChatSlashCommand.suggestions(for: text).first(where: { $0.command == text.lowercased() }) {
                handleSlashCommand(command, selectedID: selectedID)
                draft = ""
                return
            }
        }

        let attachments = imageAttachments
        draft = ""
        imageAttachments = []
        showCommandSuggestions = false
        chatService.enqueueText(text, imageAttachments: attachments, in: selectedID)
    }

    private func handleSlashCommand(_ command: ChatSlashCommand, selectedID: UUID?) {
        showCommandSuggestions = false
        switch command.command {
        case "/clear":
            if let selectedID {
                for message in chatService.messages(for: selectedID) {
                    chatService.deleteMessage(id: message.id, in: selectedID)
                }
            }
        case "/help", "/model":
            draft = ""
            isInputFocused = true
        default:
            draft = command.command + " "
        }
    }

    private func selectImageAttachment() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        panel.begin { response in
            guard response == .OK else { return }
            for url in panel.urls {
                addImageAttachment(url: url)
            }
        }
    }

    private func handleFileDrop(_ url: URL) {
        let fileURL = url.standardizedFileURL
        if ChatInputEditorRules.isChatImageFileURL(fileURL) {
            addImageAttachment(url: fileURL)
        } else {
            appendToDraft(fileURL.path)
        }
    }

    private func appendToDraft(_ value: String) {
        if draft.isEmpty {
            draft = value
        } else {
            draft += "\n" + value
        }
        inputCursorPosition = draft.count
        isInputFocused = true
    }

    private func addImageAttachment(url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }
        let mimeType = url.pathExtension.lowercased() == "png" ? "image/png" : "image/jpeg"
        addImageAttachment(
            data: data,
            mimeType: mimeType,
            fileName: url.lastPathComponent
        )
    }

    private func addImageAttachment(data: Data, mimeType: String = "image/png", fileName: String? = nil) {
        let resolvedFileName = fileName ?? defaultScreenshotFileName()
        imageAttachments.append(
            LumiImageAttachment(
                mimeType: mimeType,
                base64Data: data.base64EncodedString(),
                fileName: resolvedFileName
            )
        )
    }

    private func defaultScreenshotFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "screenshot-\(formatter.string(from: Date())).png"
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
}
