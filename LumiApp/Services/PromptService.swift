import Foundation
import AgentToolKit

/// 提示词服务 - 负责管理和构建系统提示词
actor PromptService: SuperLog {
    nonisolated static let emoji = "📝"
    nonisolated static let verbose: Bool = false

    init() {
        if Self.verbose {
            logInfo("提示词服务已初始化")
        }
    }

    private nonisolated func logInfo(_ message: String) {
        AppLogger.core.info("[PromptService][INFO] \(message)")
    }

    /// 空会话欢迎消息（当会话没有任何消息时显示）
    /// - Parameters:
    ///   - projectName: 项目名称
    ///   - projectPath: 项目路径
    ///   - language: 语言偏好
    ///   - conversationId: 会话 ID（用于显示当前会话标识）
    func getEmptySessionWelcomeMessage(projectName: String? = nil, projectPath: String? = nil, language: LanguagePreference = .chinese, conversationId: UUID? = nil) -> String {
        switch language {
        case .chinese:
            return """
            你好！请告诉我你需要什么帮助。
            """
        case .english:
            return """
            Hello! How can I help you today?
            """
        }
    }

}
