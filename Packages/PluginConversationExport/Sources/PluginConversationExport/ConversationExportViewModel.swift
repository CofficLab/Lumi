import Combine
import Foundation
import ProviderConversation
import ProviderMessage
import ProviderToast

@MainActor
final class ConversationExportViewModel: ObservableObject {
    @Published private(set) var selectedConversationID: UUID?
    @Published private(set) var isPreparing = false
    @Published var document: ConversationHTMLDocument?
    @Published var suggestedFilename = "Lumi-Conversation.html"
    @Published var isExporterPresented = false

    private let conversations: any ConversationManaging
    private let messages: any MessageManaging
    private weak var toast: (any ToastProviding)?
    private var selectionObserver: (any SelectedConversationObserverHandle)?
    private var preparationTask: Task<Void, Never>?

    init(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        toast: (any ToastProviding)?
    ) {
        self.conversations = conversations
        self.messages = messages
        self.toast = toast
        selectedConversationID = conversations.selectedConversationID
        selectionObserver = conversations.addSelectedConversationObserver { [weak self] id in
            self?.selectedConversationID = id
        }
    }

    var canExport: Bool {
        selectedConversationID != nil && !isPreparing
    }

    func beginExport() {
        guard preparationTask == nil, let conversationID = selectedConversationID else { return }
        isPreparing = true
        let cachedSummary = conversations.conversations.first { $0.id == conversationID }
        let fallbackTitle = cachedSummary?.displayTitle ?? conversations.currentTitle

        preparationTask = Task { [weak self] in
            guard let self else { return }
            let summary = await conversations.fetchConversation(id: conversationID) ?? cachedSummary
            let snapshotMessages = await messages.messagesSnapshot(in: conversationID)
            guard !Task.isCancelled else {
                finishPreparation()
                return
            }
            let snapshot = ConversationExportSnapshot(
                conversationID: conversationID,
                title: summary?.displayTitle ?? fallbackTitle,
                createdAt: summary?.createdAt,
                projectPath: summary?.projectPath,
                providerID: summary?.providerID,
                modelName: summary?.modelName,
                messages: snapshotMessages,
                exportedAt: Date()
            )
            let prepared = await Task.detached(priority: .userInitiated) {
                ConversationHTMLExporter.export(snapshot)
            }.value
            guard !Task.isCancelled else {
                finishPreparation()
                return
            }
            document = ConversationHTMLDocument(data: prepared.data)
            suggestedFilename = prepared.suggestedFilename
            isExporterPresented = true
            finishPreparation()
        }
    }

    func handleExportCompletion(_ result: Result<URL, Error>) {
        switch result {
        case let .success(url):
            toast?.show(
                LumiPluginLocalization.string("Conversation exported"),
                detail: url.lastPathComponent,
                style: .success
            )
        case let .failure(error):
            let cocoaError = error as NSError
            guard !(cocoaError.domain == NSCocoaErrorDomain && cocoaError.code == NSUserCancelledError) else {
                return
            }
            toast?.show(
                LumiPluginLocalization.string("Conversation export failed"),
                detail: error.localizedDescription,
                style: .error
            )
        }
    }

    func cancel() {
        preparationTask?.cancel()
        preparationTask = nil
        selectionObserver?.cancel()
        selectionObserver = nil
    }

    private func finishPreparation() {
        isPreparing = false
        preparationTask = nil
    }
}
