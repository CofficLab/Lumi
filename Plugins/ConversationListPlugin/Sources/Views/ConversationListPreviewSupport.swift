#if DEBUG
    import Combine
    import Foundation
    import LumiKernel

    /// Mock ConversationManaging for DEBUG previews
    @MainActor
    final class MockConversationManaging: ObservableObject, ConversationManaging {
        @Published var conversations: [LumiConversationSummary] = []
        @Published var selectedConversationID: UUID?
        var currentTitle: String { "" }
        var dataDirectory: URL { URL(fileURLWithPath: NSTemporaryDirectory()) }

        func createConversation(title: String?, projectPath: String?, providerID: String?, modelName: String?) throws -> UUID {
            let id = UUID()
            let normalizedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
            let storedTitle = normalizedTitle?.isEmpty == true ? nil : normalizedTitle
            let conv = LumiConversationSummary(
                id: id,
                title: storedTitle,
                preview: "",
                createdAt: Date(),
                updatedAt: Date(),
                providerID: providerID,
                modelName: modelName,
                projectPath: projectPath
            )
            conversations.insert(conv, at: 0)
            return id
        }

        func selectConversation(id: UUID) {
            selectedConversationID = id
        }

        func deleteConversation(id: UUID) {
            conversations.removeAll { $0.id == id }
            if selectedConversationID == id {
                selectedConversationID = conversations.first?.id
            }
        }

        func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool {
            guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
                return false
            }
            let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
            conversations[index].title = normalized.isEmpty ? nil : normalized
            if conversationID == selectedConversationID {
                objectWillChange.send()
            }
            return true
        }

        func isSending(for conversationID: UUID?) -> Bool { false }
        func mockConversationIDs() -> [UUID] { [] }
        func providerID(for conversationID: UUID?) -> String? { nil }
        func modelName(for conversationID: UUID?) -> String? { nil }
        func selectProvider(id: String, model: String?, for conversationID: UUID?) {}
        func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity { .standard }
        func setVerbosity(_ verbosity: LumiResponseVerbosity, for conversationID: UUID?) {}
        func reasoningEffort(for conversationID: UUID?) -> LumiReasoningEffort { .automatic }
        func setReasoningEffort(_ reasoningEffort: LumiReasoningEffort, for conversationID: UUID?) {}
        func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel { .chat }
        func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?) {}
        func language(for conversationID: UUID?) -> LumiConversationLanguage { .chinese }
        func setLanguage(_ language: LumiConversationLanguage, for conversationID: UUID?) {}
        func setConversationOrder(_ order: Int, for conversationID: UUID) {}
    }

    @MainActor
    final class MockMessageManaging: ObservableObject, MessageManaging {
        @Published var messagesByConversationID: [UUID: [LumiChatMessage]] = [:]

        func messages(for conversationID: UUID) -> [LumiChatMessage] {
            messagesByConversationID[conversationID] ?? []
        }

        func displayMessages(for conversationID: UUID) -> [LumiChatMessage] {
            messages(for: conversationID)
        }

        func visibleMessages(for conversationID: UUID, limit: Int, beforeMessageID: UUID?) async -> [LumiChatMessage] {
            Array(messages(for: conversationID).prefix(limit))
        }

        func messageCount(for conversationID: UUID) async -> Int {
            messages(for: conversationID).count
        }

        func hasEarlierMessages(for conversationID: UUID, beforeMessageID: UUID?) async -> Bool { false }
        func deleteMessage(id: UUID, in conversationID: UUID) {}
        func insertMessage(_ message: LumiChatMessage, to conversationID: UUID) {}
        func updateMessage(id: UUID, in conversationID: UUID, content: String) {}
        func updateToolCallResult(
            _ result: LumiToolResult,
            toolCallID: String,
            assistantMessageID: UUID,
            in conversationID: UUID
        ) {}
        func clearMessages(in conversationID: UUID) {
            messagesByConversationID[conversationID] = []
        }

        func message(id: UUID, in conversationID: UUID) -> LumiChatMessage? {
            messages(for: conversationID).first { $0.id == id }
        }

        func lastMessage(in conversationID: UUID) -> LumiChatMessage? {
            messages(for: conversationID).last
        }

        func fetchDailyMessageCounts(since: Date) async -> [Date: Int] { [:] }
        func fetchDailyTokenCounts(since: Date) async -> [Date: Int] { [:] }
        func fetchTokenUsage(on day: Date, providerID: String?, modelName: String?) async -> MessageTokenUsage {
            MessageTokenUsage(day: Calendar.current.startOfDay(for: day), inputTokens: 0, outputTokens: 0)
        }
    }

    enum ConversationListPreviewSupport {
        @MainActor
        static func makeContext() -> ConversationListContext {
            let mock = MockConversationManaging()
            let messageMock = MockMessageManaging()
            for i in 0 ..< 5 {
                let conversationID = try! mock.createConversation(title: i == 0 ? nil : "Sample Conversation \(i + 1)", projectPath: nil, providerID: nil, modelName: nil)
                messageMock.messagesByConversationID[conversationID] = (0 ..< (i + 1)).map { index in
                    LumiChatMessage(
                        conversationID: conversationID,
                        role: index.isMultiple(of: 2) ? .user : .assistant,
                        content: "Preview message \(index + 1)"
                    )
                }
            }
            let kernel = LumiKernel()
            kernel.registerService(ConversationManaging.self, mock)
            kernel.registerService(MessageManaging.self, messageMock)
            return ConversationListContext(kernel: kernel)
        }
    }
#endif
