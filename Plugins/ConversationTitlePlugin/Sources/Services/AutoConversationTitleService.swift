import Foundation
import LumiKernel
import os
import SuperLogKit

@MainActor
final class AutoConversationTitleService: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-title.auto")
    nonisolated static let emoji = "✏️"
    nonisolated static let verbose = false

    private weak var kernel: LumiKernel?
    private var messageSavedObserver: NotificationObserverToken?
    private var runningConversationIDs: Set<UUID> = []

    init(kernel: LumiKernel) {
        self.kernel = kernel
        installMessageSavedObserver()
    }

    deinit {
        if let messageSavedObserver {
            NotificationCenter.default.removeObserver(messageSavedObserver.value)
        }
    }

    private func installMessageSavedObserver() {
        let observer = NotificationCenter.default.addObserver(
            forName: .lumiMessageSaved,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let event = MessageSavedEvent(notification: notification)
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.handleMessageSaved(event)
            }
        }
        messageSavedObserver = NotificationObserverToken(observer)
    }

    private func handleMessageSaved(_ event: MessageSavedEvent) async {
        guard event.role == LumiChatMessageRole.user.rawValue,
              let conversationID = event.conversationID,
              let messageID = event.messageID,
              runningConversationIDs.insert(conversationID).inserted else {
            return
        }

        defer {
            runningConversationIDs.remove(conversationID)
        }

        guard let kernel,
              shouldGenerateTitle(conversationID: conversationID, messageID: messageID),
              let firstUserMessage = firstUserMessage(in: conversationID) else {
            return
        }

        do {
            let title = try await generateTitle(
                for: firstUserMessage.content,
                conversationID: conversationID
            )
            guard !title.isEmpty,
                  shouldApplyGeneratedTitle(conversationID: conversationID) else {
                return
            }
            _ = kernel.conversations?.updateConversationTitle(title, for: conversationID)
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)自动生成标题失败: \(error.localizedDescription)")
            }
        }
    }

    private func shouldGenerateTitle(conversationID: UUID, messageID: UUID) -> Bool {
        shouldApplyGeneratedTitle(conversationID: conversationID)
            && firstUserMessage(in: conversationID)?.id == messageID
    }

    private func shouldApplyGeneratedTitle(conversationID: UUID) -> Bool {
        guard let conversation = kernel?.conversations?.conversations.first(where: { $0.id == conversationID }) else {
            return false
        }
        return !conversation.hasCustomTitle
    }

    private func firstUserMessage(in conversationID: UUID) -> LumiChatMessage? {
        kernel?.messageManager?.messages(for: conversationID)
            .first {
                $0.role == .user
                    && !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
    }

    private func generateTitle(for userMessage: String, conversationID: UUID) async throws -> String {
        guard let kernel,
              let providerManager = kernel.llmProvider,
              let provider = resolveProvider(for: conversationID, providerManager: providerManager) else {
            return ""
        }

        let model = resolveModel(for: conversationID, provider: provider)
        let request = LumiLLMRequest(
            messages: [
                LumiChatMessage(
                    conversationID: conversationID,
                    role: .system,
                    content: Self.titlePrompt
                ),
                LumiChatMessage(
                    conversationID: conversationID,
                    role: .user,
                    content: userMessage
                ),
            ],
            model: model,
            tools: []
        )

        let response = try await provider.send(request)
        return Self.normalizeTitle(response.content)
    }

    private func resolveProvider(
        for conversationID: UUID,
        providerManager: any LLMProviderManaging
    ) -> (any LumiLLMProvider)? {
        let conversationProviderID = kernel?.conversations?.providerID(for: conversationID)
        if let conversationProviderID,
           let provider = providerManager.llmProvider(id: conversationProviderID) {
            return provider
        }

        if let selectedProviderID = providerManager.selectedProviderID,
           let provider = providerManager.llmProvider(id: selectedProviderID) {
            return provider
        }

        return providerManager.allLLMProviders().first
    }

    private func resolveModel(for conversationID: UUID, provider: any LumiLLMProvider) -> String {
        kernel?.conversations?.modelName(for: conversationID)
            ?? kernel?.llmProvider?.selectedModel
            ?? type(of: provider).info.defaultModel
    }

    private static let titlePrompt = """
    Generate a concise, user-facing title for a conversation from the user's first message.

    Rules:
    - Return only the title, with no quotes, markdown, explanation, or punctuation wrapper.
    - Use the same language as the user's message when practical.
    - Keep it short and specific.
    - Maximum 40 characters.
    """

    nonisolated static func normalizeTitle(_ rawTitle: String) -> String {
        let firstLine = rawTitle
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""

        let stripped = firstLine
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`“”‘’「」『』《》[]()"))
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard stripped.count > 40 else {
            return stripped
        }
        let end = stripped.index(stripped.startIndex, offsetBy: 40)
        return String(stripped[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct MessageSavedEvent: Sendable {
    let conversationID: UUID?
    let messageID: UUID?
    let role: String?

    init(notification: Notification) {
        conversationID = notification.userInfo?[LumiMessageSavedNotification.conversationIDKey] as? UUID
        messageID = notification.userInfo?[LumiMessageSavedNotification.messageIDKey] as? UUID
        role = notification.userInfo?[LumiMessageSavedNotification.roleKey] as? String
    }
}

private final class NotificationObserverToken: @unchecked Sendable {
    let value: NSObjectProtocol

    init(_ value: NSObjectProtocol) {
        self.value = value
    }
}
