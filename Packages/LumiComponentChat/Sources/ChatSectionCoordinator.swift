import AppKit
import Combine
import LumiComponentLayout
import LumiComponentLLMProvider
import LumiComponentMessage
import SwiftUI
import UniformTypeIdentifiers

@MainActor
public final class ChatSectionCoordinator: ObservableObject {
    @Published public var draft = ""
    @Published public var rawMessageIDs: Set<UUID> = []
    @Published public var oldestVisibleMessageID: UUID?
    @Published public var inputHeight: CGFloat = ChatInputConstants.inputMinHeight
    @Published public var isInputFocused = false
    @Published public var inputCursorPosition = 0
    @Published public var isImageDragHovering = false
    @Published public var imageAttachments: [LumiImageAttachment] = []
    @Published public var showCommandSuggestions = false
    @Published public var showImageUnsupportedAlert = false
    @Published public private(set) var chatSectionToolbarItems: [LumiChatSectionToolbarItem] = []

    public let chatService: ChatService
    private var cancellables = Set<AnyCancellable>()

    public init(chatService: ChatService, databaseDirectory: URL? = nil) {
        self.chatService = chatService
        bindChatService()
    }

    public var selectedConversationID: UUID? {
        chatService.selectedConversationID ?? chatService.conversations.first?.id
    }

    public func setChatSectionToolbarItems(_ items: [LumiChatSectionToolbarItem]) {
        chatSectionToolbarItems = items
    }

    public func displayedMessages(for conversationID: UUID) -> [LumiChatMessage] {
        let persisted = persistedDisplayMessages(for: conversationID)
        let startIndex = visibleMessageStartIndex(in: persisted)
        let page = Array(persisted[startIndex...])

        guard let transientStatus = chatService.transientStatusMessage(for: conversationID) else {
            return page
        }
        return page + [transientStatus]
    }

    public func pendingMessages(for conversationID: UUID) -> [LumiPendingMessage] {
        chatService.pendingMessages.filter { $0.conversationID == conversationID }
    }

    public func loadEarlierMessages() {
        guard let selectedID = selectedConversationID else { return }
        let persisted = persistedDisplayMessages(for: selectedID)
        guard !persisted.isEmpty else { return }

        let currentStartIndex = visibleMessageStartIndex(in: persisted)
        guard currentStartIndex > 0 else { return }

        let newStartIndex = max(0, currentStartIndex - messagePageSize)
        oldestVisibleMessageID = persisted[newStartIndex].id
    }

    public func send() {
        let selectedID = selectedConversationID
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !imageAttachments.isEmpty else { return }

        if text.hasPrefix("/") {
            let normalized = text.lowercased()
            if Self.exactSlashCommands.contains(normalized) {
                handleSlashCommand(normalized, selectedID: selectedID)
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

    public func handleSlashCommand(_ command: String, selectedID: UUID?) {
        showCommandSuggestions = false
        switch command {
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
            draft = command + " "
        }
    }

    public func canAttachImages(for conversationID: UUID?) -> Bool {
        LumiModelVisionSupport.supportsVision(
            providerInfos: chatService.providerInfos,
            routingMode: chatService.routingMode,
            providerID: chatService.providerID(for: conversationID),
            model: chatService.modelName(for: conversationID)
        )
    }

    public func selectImageAttachment() {
        guard canAttachImages(for: selectedConversationID) else {
            showImageUnsupportedAlert = true
            return
        }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        panel.begin { [weak self] response in
            guard response == .OK, let self else { return }
            for url in panel.urls {
                self.addImageAttachment(url: url)
            }
        }
    }

    public func handleFileDrop(_ url: URL) {
        let fileURL = url.standardizedFileURL
        if ChatInputConstants.isChatImageFileURL(fileURL) {
            guard canAttachImages(for: selectedConversationID) else {
                showImageUnsupportedAlert = true
                return
            }
            addImageAttachment(url: fileURL)
        } else {
            appendToDraft(fileURL.path)
        }
    }

    public func appendToDraft(_ value: String) {
        if draft.isEmpty {
            draft = value
        } else {
            draft += "\n" + value
        }
        inputCursorPosition = draft.count
        isInputFocused = true
    }

    public func addImageAttachment(url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }
        let mimeType = url.pathExtension.lowercased() == "png" ? "image/png" : "image/jpeg"
        addImageAttachment(
            data: data,
            mimeType: mimeType,
            fileName: url.lastPathComponent
        )
    }

    public func addImageAttachment(data: Data, mimeType: String = "image/png", fileName: String? = nil) {
        guard canAttachImages(for: selectedConversationID) else {
            showImageUnsupportedAlert = true
            return
        }

        let resolvedFileName = fileName ?? defaultScreenshotFileName()
        imageAttachments.append(
            LumiImageAttachment(
                mimeType: mimeType,
                base64Data: data.base64EncodedString(),
                fileName: resolvedFileName
            )
        )
    }

    public func selectedTitle(for id: UUID?) -> String {
        guard let id,
              let conversation = chatService.conversations.first(where: { $0.id == id })
        else {
            return "Chat"
        }
        return conversation.title
    }

    public func rawMessageBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { self.rawMessageIDs.contains(id) },
            set: { isPresented in
                if isPresented {
                    self.rawMessageIDs.insert(id)
                } else {
                    self.rawMessageIDs.remove(id)
                }
            }
        )
    }

    public func resetOldestVisibleMessageID() {
        oldestVisibleMessageID = nil
    }

    public func bindDraftChanges() {
        showCommandSuggestions = draft.hasPrefix("/")
    }

    private static let exactSlashCommands = ["/clear", "/help", "/model"]
    private let messagePageSize = 10

    private func persistedDisplayMessages(for conversationID: UUID) -> [LumiChatMessage] {
        chatService.messages(for: conversationID).filter {
            $0.role != .tool && ($0.role != .status || $0.renderKind == "turn-completed")
        }
    }

    private func visibleMessageStartIndex(in persisted: [LumiChatMessage]) -> Int {
        if let oldestVisibleMessageID,
           let index = persisted.firstIndex(where: { $0.id == oldestVisibleMessageID }) {
            return index
        }
        return max(0, persisted.count - messagePageSize)
    }

    private func bindChatService() {
        chatService.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    private func defaultScreenshotFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "screenshot-\(formatter.string(from: Date())).png"
    }
}
