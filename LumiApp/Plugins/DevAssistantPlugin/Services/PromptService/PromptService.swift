import Foundation
import OSLog
import MagicKit

/// 提示词服务 - 负责管理和构建系统提示词
actor PromptService: SuperLog {
    nonisolated static let emoji = "📝"
    nonisolated static let verbose = true

    static let shared = PromptService()

    private init() {
        if Self.verbose {
            os_log("\(self.t)提示词服务已初始化")
        }
    }

    // MARK: - 基础系统提示

    /// 基础系统提示词
    private let baseSystemPrompt = """
    You are an expert software engineer and agentic coding tool (DevAssistant).
    You have access to a set of tools to explore the codebase, read files, and execute commands.

    Your goal is to help the user complete tasks efficiently.
    1. Always analyze the request first.
    2. Use tools to gather information (ls, read_file).
    3. Formulate a plan if the task is complex.
    4. Execute the plan to tools.

    The user is on macOS.
    """

    // MARK: - 系统提示构建

    /// 构建完整的系统提示词
    /// - Parameters:
    ///   - languagePreference: 语言偏好
    ///   - includeContext: 是否包含项目上下文
    /// - Returns: 完整的系统提示词
    func buildSystemPrompt(
        languagePreference: LanguagePreference,
        includeContext: Bool = true
    ) async -> String {
        var prompt = baseSystemPrompt

        // 添加语言偏好信息
        prompt += "\n\n" + languagePreference.systemPromptDescription

        // 如果需要，添加项目上下文
        if includeContext {
            let context = await ContextService.shared.getContextPrompt()
            prompt += "\n\n" + context
        }

        if Self.verbose {
            os_log("\(self.t)构建系统提示词，语言偏好: \(languagePreference.displayName)")
        }

        return prompt
    }

    /// 获取基础系统提示词（不包含语言和上下文）
    func getBaseSystemPrompt() -> String {
        return baseSystemPrompt
    }

    // MARK: - 专用提示词模板

    /// 欢迎消息（未选择项目时）
    func getWelcomeMessage() -> String {
        """
        👋 Welcome to Dev Assistant!

        Before we start, please select a project to work on. You can:

        1. **Open Project Settings** (点击右上角齿轮图标) → Select a project
        2. **Choose from recent projects** if you've used this assistant before
        3. **Browse** to select a new project folder

        Once a project is selected, I'll be able to:
        - Read and analyze your code
        - Navigate the project structure
        - Execute build commands
        - Help with debugging and refactoring

        ---
        当前项目：**未选择**
        项目路径：**未设置**
        """
    }

    /// 项目切换成功消息
    func getProjectSwitchedMessage(projectName: String, projectPath: String) -> String {
        """
        ✅ 项目已切换

        **项目名称**: \(projectName)
        **项目路径**: \(projectPath)

        Context loaded successfully. How can I help you with this project?
        """
    }

    /// 欢迎回来消息（已选择项目）
    func getWelcomeBackMessage(projectName: String, projectPath: String, language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return """
            👋 欢迎回来！

            **当前项目**: \(projectName)  
            **项目路径**: \(projectPath)

            有什么可以帮你的吗？
            """
        case .english:
            return """
            👋 Welcome back!

            **Current Project**: \(projectName)  
            **Path**: \(projectPath)

            How can I help you today?
            """
        }
    }

    /// 语言切换消息
    func getLanguageSwitchedMessage(language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "✅ 已切换到中文模式\n\n我将使用中文与您交流。"
        case .english:
            return "✅ Switched to English mode\n\nI'll communicate in English from now on."
        }
    }

    /// 未选择项目警告消息
    func getProjectNotSelectedWarningMessage() -> String {
        """
        ⚠️ 请先选择一个项目

        还没有选择项目。请点击右上角的齿轮图标，选择一个项目后我们才能开始工作。
        """
    }

    /// 规划模式提示词
    func getPlanningModePrompt(task: String) -> String {
        """
        ACT AS: Architect / Planner
        TASK: \(task)

        Please generate a detailed implementation plan in Markdown.
        Structure:
        1. Analysis
        2. Implementation Steps
        3. Verification

        Do not write code yet, just the plan.
        """
    }
}
