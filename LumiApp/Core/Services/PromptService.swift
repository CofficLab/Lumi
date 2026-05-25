import Foundation
import AgentToolKit

/// 提示词服务 - 负责管理和构建系统提示词
actor PromptService: SuperLog {
    nonisolated static let emoji = "📝"
    nonisolated static let verbose: Bool = true

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

    /// 系统上下文消息（在会话开始时发送，设置项目上下文）
    /// - Parameters:
    ///   - projectName: 项目名称
    ///   - projectPath: 项目路径
    ///   - language: 语言偏好
    /// - Returns: 系统消息内容
    func getSystemContextMessage(projectName: String? = nil, projectPath: String? = nil, language: LanguagePreference = .chinese) -> String {
        let cdCommand: String
        let projectContext: String
        
        if let name = projectName, let path = projectPath, !name.isEmpty {
            cdCommand = "cd \(path) && "
            projectContext = """
            **当前项目**: \(name)
            **项目路径**: \(path)
            """
        } else {
            cdCommand = ""
            projectContext = "**项目**: 未选择"
        }
        
        switch language {
        case .chinese:
            return """
            你是 Lumi，一个智能助手。
            
            \(projectContext)
            
            **重要规则**：
            1. 所有命令执行都必须在上述项目路径下进行
            2. 执行任何命令前，先使用 `\(cdCommand)<命令>` 格式
            3. 读取或修改文件时，使用完整路径或相对于项目路径的相对路径
            4. 如果用户没有指定路径，默认在项目根目录下操作
            
            请始终保持在这个项目的上下文中工作。
            """
        case .english:
            return """
            You are Lumi, an intelligent assistant.
            
            \(projectContext)
            
            **Important Rules**:
            1. All command execution must be done in the project directory above
            2. Before executing any command, use the format `\(cdCommand)<command>`
            3. When reading or modifying files, use full paths or paths relative to the project root
            4. If the user doesn't specify a path, default to operating in the project root directory
            
            Please always work within the context of this project.
            """
        }
    }
}
