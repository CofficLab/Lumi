import Foundation
import SuperLogKit
import AgentToolKit
import LumiCoreKit
import os

/// 当前项目注入中间件
///
/// 在每次发送用户消息前，检测当前活跃窗口选中的项目，
/// 将当前项目信息注入到 LLM 的 transientSystemPrompts 中，
/// 提示大模型：用户当前正在重点关注这个项目。
///
/// ## 设计决策
/// - 优先级设为 -6，在列表中间件之前执行，保证当前项目信息最突出
/// - 只在有项目选中时才注入
/// - 强调当前项目是用户"正在关注"的项目，区别于历史项目列表
@MainActor
public final class CurrentProjectSendMiddleware: SuperSendMiddleware, SuperLog {
    public nonisolated static let emoji = "📌"
    public nonisolated static let verbose: Bool = true
    public let id: String = "current-project-context"
    /// 优先级设为 -6，在 projects-context 之前执行
    public let order: Int = -6

    public func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        // 获取当前活跃窗口的项目路径
        let projectPath = ctx.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !projectPath.isEmpty else {
            if Self.verbose {
                ProjectsPlugin.logger.info("\(Self.t)跳过：当前未选中项目")
            }
            await next(ctx)
            return
        }

        let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
        let prompt = buildCurrentProjectPrompt(name: projectName, path: projectPath)

        ctx.transientSystemPrompts.append(prompt)

        if Self.verbose {
            ProjectsPlugin.logger.info("\(Self.t)📌 当前项目中间件：注入 [\(projectName)]")
        }

        await next(ctx)
    }

    /// 构建当前项目提示词
    private func buildCurrentProjectPrompt(name: String, path: String) -> String {
        """
        ## Current Active Project

        The user is currently working on and focusing on: **\(name)**

        **Path**: `\(path)`

        When the user refers to "the project", "my project", "the current project", or similar phrases, they are referring to this project. Prioritize this project in your responses and code operations.
        """
    }
}
