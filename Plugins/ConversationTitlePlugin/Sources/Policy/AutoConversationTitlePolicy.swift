import Foundation
import LumiKernel

/// Stateless auto conversation naming policy.
public struct AutoConversationTitlePolicy {
    public struct PreflightInput {
        public let role: LumiChatMessageRole
        public let userText: String
        public let currentTitle: String
        public let newConversationTitle: String
        public let newChatTitlePrefix: String

        public init(
            role: LumiChatMessageRole,
            userText: String,
            currentTitle: String,
            newConversationTitle: String,
            newChatTitlePrefix: String
        ) {
            self.role = role
            self.userText = userText
            self.currentTitle = currentTitle
            self.newConversationTitle = newConversationTitle
            self.newChatTitlePrefix = newChatTitlePrefix
        }
    }

    public struct Input {
        public let role: LumiChatMessageRole
        public let userText: String
        public let currentTitle: String
        public let userMessageCount: Int
        public let newConversationTitle: String
        public let newChatTitlePrefix: String

        public init(
            role: LumiChatMessageRole,
            userText: String,
            currentTitle: String,
            userMessageCount: Int,
            newConversationTitle: String,
            newChatTitlePrefix: String
        ) {
            self.role = role
            self.userText = userText
            self.currentTitle = currentTitle
            self.userMessageCount = userMessageCount
            self.newConversationTitle = newConversationTitle
            self.newChatTitlePrefix = newChatTitlePrefix
        }
    }

    public struct Output: Equatable {
        public let shouldGenerate: Bool
        public let trimmedUserText: String?

        public init(shouldGenerate: Bool, trimmedUserText: String?) {
            self.shouldGenerate = shouldGenerate
            self.trimmedUserText = trimmedUserText
        }
    }

    public init() {}

    public func evaluate(_ input: Input) -> Output {
        let preflight = preflight(
            PreflightInput(
                role: input.role,
                userText: input.userText,
                currentTitle: input.currentTitle,
                newConversationTitle: input.newConversationTitle,
                newChatTitlePrefix: input.newChatTitlePrefix
            )
        )

        guard input.userMessageCount == 1 else {
            return Output(shouldGenerate: false, trimmedUserText: nil)
        }

        return preflight
    }

    public func preflight(_ input: PreflightInput) -> Output {
        guard input.role == .user else {
            return Output(shouldGenerate: false, trimmedUserText: nil)
        }

        let trimmed = input.userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Output(shouldGenerate: false, trimmedUserText: nil)
        }

        guard shouldAutoTitle(
            input.currentTitle,
            newConversationTitle: input.newConversationTitle,
            newChatTitlePrefix: input.newChatTitlePrefix
        ) else {
            return Output(shouldGenerate: false, trimmedUserText: nil)
        }

        return Output(shouldGenerate: true, trimmedUserText: trimmed)
    }

    private func shouldAutoTitle(
        _ title: String,
        newConversationTitle: String,
        newChatTitlePrefix: String
    ) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        let defaultConversationTitles = [
            newConversationTitle,
            "New Conversation",
            "新对话",
        ]
        let defaultChatTitlePrefixes = [
            newChatTitlePrefix,
            "New Chat",
            "新聊天",
        ]

        return defaultConversationTitles.contains(trimmed)
            || defaultChatTitlePrefixes.contains { trimmed.hasPrefix($0) }
    }
}
