import Foundation
import AgentToolKit
import os

/// 项目上下文注入中间件
///
/// 在每次发送用户消息前，自动读取项目列表，
/// 将项目信息注入到 LLM 的 transientSystemPrompts 中，
/// 让大模型知道用户可能提到的项目，提高上下文理解能力。
///
/// ## 设计决策
/// - 只注入最近 5 个项目，避免提示词过长
/// - 包含项目名称和路径，帮助大模型理解用户意图
/// - order 设为 -5，在语言中间件之后、其他中间件之前注入
/// - 如果没有项目或项目为空，则不注入
@MainActor
final class ProjectsSendMiddleware: SuperSendMiddleware, SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose: Bool = true
    let id: String = "projects-context"
    /// 优先级设为 -5，在语言中间件之后执行
    let order: Int = -5

    private let maxProjects: Int = 5

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        // 从存储加载项目
        let store = ProjectsStore()
        let projects = Array(store.loadProjects().prefix(maxProjects))

        // 只在有项目时注入
        if !projects.isEmpty {
            let prompt = buildProjectsPrompt(projects)
            ctx.transientSystemPrompts.append(prompt)

            if Self.verbose {
                if ProjectsPlugin.verbose {
                    ProjectsPlugin.logger.info("📋 项目中间件：注入 \(projects.count) 个项目")
                }
            }
        }

        await next(ctx)
    }

    /// 构建项目提示词
    private func buildProjectsPrompt(_ projects: [Project]) -> String {
        var prompt = """
        ## User's Recent Projects

        The user has recently worked on the following projects. When the user mentions a project name or refers to "the project", they are likely referring to one of these:

        """

        for (index, project) in projects.enumerated() {
            prompt += "\n\(index + 1). **\(project.name)**\n"
            prompt += "   Path: `\(project.path)`\n"
            prompt += "   Last used: \(formatDate(project.lastUsed))\n"
        }

        prompt += "\nKeep these projects in context to better understand the user's requests."

        return prompt
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
