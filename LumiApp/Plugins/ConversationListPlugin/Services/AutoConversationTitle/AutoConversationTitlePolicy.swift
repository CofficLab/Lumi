import Foundation

/// 无状态的自动会话命名策略。
///
/// 输入当前消息、现有标题和消息计数，输出是否应该生成标题以及清洗后的用户文本；
/// 不访问数据库、不读取配置，也不执行标题更新。
struct AutoConversationTitlePolicy {
    struct PreflightInput {
        let role: MessageRole
        let userText: String
        let currentTitle: String
        let newConversationTitle: String
        let newChatTitlePrefix: String
    }

    struct Input {
        let role: MessageRole
        let userText: String
        let currentTitle: String
        let userMessageCount: Int
        let newConversationTitle: String
        let newChatTitlePrefix: String
    }

    struct Output: Equatable {
        let shouldGenerate: Bool
        let trimmedUserText: String?
    }

    func evaluate(_ input: Input) -> Output {
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

    func preflight(_ input: PreflightInput) -> Output {
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
        title == newConversationTitle || title.hasPrefix(newChatTitlePrefix)
    }
}
