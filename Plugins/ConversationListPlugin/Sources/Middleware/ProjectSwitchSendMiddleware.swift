import AgentToolKit
import LumiCoreKit
import SuperLogKit
import Foundation

/// 项目切换对话引导中间件
///
/// 在每次发送用户消息前，注入当前项目信息，
/// 并指导 LLM 在用户话题完全切换到另一个项目时创建新对话。
///
/// ## 工作流程
/// 1. 获取当前选中的项目
/// 2. 将项目信息和切换指导注入到 transientSystemPrompts
/// 3. LLM 接收后，如发现用户讨论的项目已完全切换，可调用工具创建新对话
@MainActor
public final class ProjectSwitchSendMiddleware: SuperSendMiddleware, SuperLog {
    public nonisolated static let emoji = "📁"
    public nonisolated static let verbose: Bool = true
    public let id: String = "project-switch-guide"
    public let order: Int = 6  // 在标题提示中间件之后执行

    public func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        let projectPath = ctx.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectPath.isEmpty else {
            if Self.verbose, ConversationListPlugin.verbose {
                ConversationListPlugin.logger.debug("\(Self.t)📁 无当前项目，跳过项目切换提示")
            }
            await next(ctx)
            return
        }

        let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
        let language = ctx.languagePreference

        let prompt = Self.buildPrompt(
            projectName: projectName,
            projectPath: projectPath,
            language: language
        )
        ctx.transientSystemPrompts.append(prompt)

        if Self.verbose, ConversationListPlugin.verbose {
            ConversationListPlugin.logger.debug("\(Self.t)📁 已注入项目切换提示: \"\(projectName)\"")
        }

        await next(ctx)
    }

    // MARK: - 提示词构建

    private static func buildPrompt(
        projectName: String,
        projectPath: String,
        language: LanguagePreference
    ) -> String {
        switch language {
        case .chinese:
            return """
            ## 当前项目

            用户当前选中的项目是：**\(projectName)**（路径：`\(projectPath)`）

            **重要提示**：
            如果用户的下一条消息完全切换到了另一个项目的讨论（例如提到了完全不同的项目名、路径或技术栈），
            请不要在当前对话中继续，而是执行以下操作：

            1. 调用 `create_new_conversation` 工具创建一个新的对话，标题设为能反映新项目主题的名称
            2. 调用 `set_conversation_project` 工具将新对话关联到用户正在讨论的新项目路径

            只有当话题完全切换到不同项目时才创建新对话。如果用户只是在当前项目中引用其他项目作为参考，则继续使用当前对话。
            """
        case .english:
            return """
            ## Current Project

            The user's currently selected project is: **\(projectName)** (path: `\(projectPath)`)

            **Important**:
            If the user's next message completely switches to discussing a different project (e.g., mentions a completely different project name, path, or tech stack),
            do not continue in the current conversation. Instead, perform the following:

            1. Call `create_new_conversation` to create a new conversation, with a title that reflects the new project topic
            2. Call `set_conversation_project` to associate the new conversation with the project path the user is discussing

            Only create a new conversation when the topic completely switches to a different project. If the user is just referencing another project as context within the current project, continue using the current conversation.
            """
        }
    }
}
