import KitPrototype
import ProviderConversationInput

enum PrototypeElementConversationActionOutcome: Equatable {
    case appended
    case unavailable
    case staleSelection
}

@MainActor
enum PrototypeElementConversationAction {
    /// 把当前屏幕的 HTML 文件引用发送到对话输入（与文件树的「发送到对话」一致）。
    static func apply(
        resolved: PrototypeResolvedScreen,
        selectedProjectID: String?,
        selectedScreenID: String?,
        input: (any ConversationInputProviding)?
    ) -> PrototypeElementConversationActionOutcome {
        guard selectedProjectID == resolved.project.id,
              selectedScreenID == resolved.screen.id else {
            return .staleSelection
        }
        guard let input else { return .unavailable }

        input.addToConversation(fileURLs: [resolved.htmlURL])
        return .appended
    }
}
