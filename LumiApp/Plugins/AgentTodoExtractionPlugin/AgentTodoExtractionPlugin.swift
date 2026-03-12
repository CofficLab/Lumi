import Foundation
import MagicKit

/// Agent Todo Extraction 插件
///
/// 从 assistant 回复中提取“待办事项”并生成一条结构化的跟进消息（规则法，低风险、低成本）。
actor AgentTodoExtractionPlugin: SuperPlugin {
    static let id: String = "AgentTodoExtraction"
    static let displayName: String = "Agent Todo Extraction"
    static let description: String = "从回复中提取待办（规则法），用于快速回顾与跟进。"
    static let iconName: String = "checklist"
    static let isConfigurable: Bool = true
    static let enable: Bool = true
    static var order: Int { 540 }

    static let shared = AgentTodoExtractionPlugin()

    @MainActor
    func conversationTurnMiddlewares() -> [AnyConversationTurnMiddleware] {
        [AnyConversationTurnMiddleware(TodoExtractionMiddleware())]
    }
}

