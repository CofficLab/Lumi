import Foundation
import OSLog
import MagicKit

/// 提示词服务 - 负责管理和构建系统提示词
actor PromptService: SuperLog {
    nonisolated static let emoji = "📝"
    nonisolated static let verbose = false

    private let contextService: ContextService

    init(contextService: ContextService) {
        self.contextService = contextService
        if Self.verbose {
            os_log("\(self.t) 提示词服务已初始化")
        }
    }

    // MARK: - 基础系统提示

    /// 基础系统提示词
    private let baseSystemPrompt = """
    You are an expert software engineer and manager-style coding assistant (DevAssistant).
    You coordinate tools and specialized workers while presenting a single coherent assistant experience.

    You can use normal tools to inspect and change the project:
    - ls / read_file / write_file / run_command

    You can also delegate specialist subtasks with:
    - create_and_assign_task(workerType, taskDescription, context?, providerId?, model?)

    Available worker types:
    1. code_expert
       - Strengths: code analysis, bug fixing, refactoring, implementation details
       - Typical tasks: analyze code issues, refactor a function, optimize logic
    2. document_expert
       - Strengths: technical documentation, API explanations, structured summaries
       - Typical tasks: write docs, summarize modules, improve comments
    3. test_expert
       - Strengths: test planning, unit/integration tests, quality validation
       - Typical tasks: design test cases, add tests, check edge cases
    4. architect
       - Strengths: system design, architecture review, tradeoff analysis
       - Typical tasks: architecture evaluation, module boundary decisions

    Workflow:
    1. Understand user intent and constraints.
    2. Decide whether direct tool execution or worker delegation is best.
    3. For complex work, decompose into explicit subtasks and delegate to appropriate worker(s).
    4. Collect results and verify consistency across workers.
    5. Synthesize final output with clear structure, decisions, and next actions.

    Behavioral rules:
    - Do not expose hidden chain-of-thought.
    - Do not dump raw worker output without synthesis.
    - Keep user-visible responses concise and practical.
    - Prefer deterministic, verifiable actions over speculation.
    - If a worker/tool fails, explain the failure and provide fallback or retry strategy.

    Synthesis format (for multi-worker tasks):
    1. Outcome Summary
    2. Key Findings
    3. Changes / Deliverables
    4. Risks & Open Questions
    5. Recommended Next Steps

    Conflict check before final response:
    - Compare facts from each worker (APIs, file paths, versions, assumptions).
    - If conflicts exist, explicitly state the conflict and preferred resolution.
    - If uncertain, request or run an additional verification step.

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
            let context = await contextService.getContextPrompt()
            prompt += "\n\n" + context
        }

        if Self.verbose {
            os_log("\(self.t) 构建系统提示词，语言偏好：\(languagePreference.displayName)")
        }

        return prompt
    }

    /// 获取基础系统提示词（不包含语言和上下文）
    func getBaseSystemPrompt() -> String {
        return baseSystemPrompt
    }

    // MARK: - 快捷短语提示词

    /// 快捷短语数据模型
    struct QuickPhrase: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let subtitle: String
        let prompt: String
    }

    /// 获取快捷短语列表
    /// - Parameters:
    ///   - projectName: 当前项目名称
    ///   - projectPath: 当前项目路径
    /// - Returns: 快捷短语列表
    func getQuickPhrases(projectName: String? = nil, projectPath: String? = nil) -> [QuickPhrase] {
        // 构建项目上下文描述
        let cdCommand: String
        if let name = projectName, let path = projectPath, !name.isEmpty {
            cdCommand = "cd \(path) && "
        } else {
            cdCommand = ""
        }

        return [
            QuickPhrase(
                icon: "checkmark.circle",
                title: "英文 Commit",
                subtitle: "提交英文 commit",
                prompt: """
                执行以下操作，无需向我确认：
                1. 运行 `\(cdCommand)git status` 查看当前改动
                2. 运行 `\(cdCommand)git diff` 查看具体代码变更
                3. 生成一个遵循 conventional commits 规范（feat/fix/docs/refactor 等）的英文 commit message
                4. 立即执行 `\(cdCommand)git commit -m "<生成的 commit message>"` 提交代码
                """
            ),
            QuickPhrase(
                icon: "checkmark.circle",
                title: "中文 Commit",
                subtitle: "提交中文 commit",
                prompt: """
                执行以下操作，无需向我确认：
                1. 运行 `\(cdCommand)git status` 查看当前改动
                2. 运行 `\(cdCommand)git diff` 查看具体代码变更
                3. 生成一个遵循 conventional commits 规范（feat/fix/docs/refactor 等）的中文 commit message
                4. 立即执行 `\(cdCommand)git commit -m "<生成的 commit message>"` 提交代码
                """
            ),
        ]
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

    /// 空会话欢迎消息（当会话没有任何消息时显示）
    /// - Parameters:
    ///   - projectName: 项目名称
    ///   - projectPath: 项目路径
    ///   - language: 语言偏好
    ///   - conversationId: 会话 ID（用于显示当前会话标识）
    func getEmptySessionWelcomeMessage(projectName: String? = nil, projectPath: String? = nil, language: LanguagePreference = .chinese, conversationId: UUID? = nil) -> String {
        // 构建项目上下文描述
        let projectContext: String
        if let name = projectName, let path = projectPath, !name.isEmpty {
            projectContext = """
            **当前项目**: \(name)
            **项目路径**: \(path)
            """
        } else {
            projectContext = "**项目**: 未选择"
        }

        // 格式化当前时间
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy 年 MM 月 dd 日 HH:mm"
        let currentTime = dateFormatter.string(from: Date())

        // 构建会话 ID 显示
        let sessionIdDisplay: String
        if let id = conversationId {
            let shortId = id.uuidString.prefix(8)
            sessionIdDisplay = "**会话 ID**: `\(shortId)`\n"
        } else {
            sessionIdDisplay = ""
        }

        switch language {
        case .chinese:
            return """
            👋 你好！我是你的智能编程助手 DevAssistant。

            \(projectContext)
            
            **当前时间**: \(currentTime)  
            
            \(sessionIdDisplay)
            我可以帮你：
            - **分析代码** - 阅读和理解项目结构
            - **执行命令** - 运行构建、测试和脚本
            - **修改文件** - 编辑代码和创建新文件
            - **解答问题** - 提供技术支持和建议

            请告诉我你需要什么帮助？
            """
        case .english:
            dateFormatter.dateFormat = "MMMM dd, yyyy HH:mm"
            let currentTimeEN = dateFormatter.string(from: Date())
            return """
            👋 Hello! I'm your intelligent coding assistant, DevAssistant.

            \(projectContext)  
            
            **Current Time**: \(currentTimeEN)  
            
            \(sessionIdDisplay)
            I can help you:
            - **Analyze code** - Read and understand project structure
            - **Execute commands** - Run builds, tests, and scripts
            - **Modify files** - Edit code and create new files
            - **Answer questions** - Provide technical support and advice

            How can I help you today?
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
            你是 DevAssistant，一个智能编程助手。
            
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
            You are DevAssistant, an intelligent coding assistant.
            
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
