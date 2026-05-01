import Foundation
import MagicKit
import os

/// Agent 上下文同步中间件
///
/// 在每次发送用户消息前，自动注入当前项目上下文信息，
/// 让大模型知晓用户当前所在的项目环境。
///
/// ## 工作流程
/// 1. 拦截用户消息发送
/// 2. 从上下文获取当前项目信息
/// 3. 将项目信息格式化为系统提示词
/// 4. 注入到 transientSystemPrompts 中（不落库）
///
/// ## 设计决策
/// - 使用临时提示词而非保存到数据库，减少存储和上下文冗余
/// - 每次发送消息时动态注入最新的项目信息
/// - 如果未选择项目，静默跳过
@MainActor
final class AgentContextSyncSuperSendMiddleware: SuperSendMiddleware, SuperLog {
    nonisolated static let emoji = "🔄"
    nonisolated static let verbose: Bool = false
    let id: String = "agent-context-sync"
    let order: Int = 0  // 较早执行，优先注入项目上下文

    // MARK: - 执行

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        let projectPath = ctx.projectVM.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let projectName = ctx.projectVM.currentProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedFileURL = ctx.projectVM.selectedFileURL
        let codeSelectionRange = ctx.projectVM.codeSelectionRange
        let recentProjects = ctx.projectVM.getRecentProjects()

        if Self.verbose {
            AgentContextSyncPlugin.logger.info("\(Self.t)🔄 Agent Context Sync 中间件：检查项目信息")
            AgentContextSyncPlugin.logger.info("\(Self.t)   项目名称：\(projectName.isEmpty ? "<未选择>" : projectName)")
            AgentContextSyncPlugin.logger.info("\(Self.t)   项目路径：\(projectPath.isEmpty ? "<未选择>" : projectPath)")
            AgentContextSyncPlugin.logger.info("\(Self.t)   选中文件：\(selectedFileURL?.path ?? "<未选择>")")
            AgentContextSyncPlugin.logger.info("\(Self.t)   代码选区：\(codeSelectionRange?.description ?? "<无>")")
        }

        // 未选择项目时跳过
        guard !projectPath.isEmpty else {
            if Self.verbose {
                AgentContextSyncPlugin.logger.info("\(Self.t)   ⏭️ 跳过 (未选择项目)")
            }
            await next(ctx)
            return
        }

        // 构建项目上下文提示词
        let prompt = buildProjectContextPrompt(
            projectName: projectName,
            projectPath: projectPath,
            selectedFileURL: selectedFileURL,
            codeSelectionRange: codeSelectionRange,
            recentProjects: recentProjects
        )
        ctx.transientSystemPrompts.append(prompt)

        if Self.verbose {
            AgentContextSyncPlugin.logger.info("\(Self.t)   ✅ 已注入项目上下文")
            AgentContextSyncPlugin.logger.info("\(Self.t)   📝 提示词长度：\(prompt.count) 字符")
            AgentContextSyncPlugin.logger.info("\(Self.t)   ➡️ 继续传递给 LLM...")
        }

        await next(ctx)
    }

    // MARK: - 提示词构建

    /// 将项目信息格式化为系统提示词
    private func buildProjectContextPrompt(
        projectName: String,
        projectPath: String,
        selectedFileURL: URL?,
        codeSelectionRange: CodeSelectionRange?,
        recentProjects: [Project]
    ) -> String {
        var lines: [String] = []

        lines.append("## Current Project Context")
        lines.append("")
        lines.append("The user is currently working in the following project:")
        lines.append("")
        lines.append("**Project Name**: \(projectName.isEmpty ? "Unknown" : projectName)")
        lines.append("**Project Path**: `\(projectPath)`")

        // 注入当前选中文件信息
        if let fileURL = selectedFileURL {
            let filePath = fileURL.path
            let relativePath: String
            if filePath.hasPrefix(projectPath) {
                let index = filePath.index(filePath.startIndex, offsetBy: projectPath.count)
                relativePath = String(filePath[index...]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            } else {
                relativePath = filePath
            }
            lines.append("**Selected File**: `\(relativePath.isEmpty ? filePath : relativePath)`")

            // 注入代码选区信息
            if let range = codeSelectionRange {
                if range.isSingleLine {
                    lines.append("**Code Selection**: Line \(range.startLine), columns \(range.startColumn)-\(range.endColumn)")
                } else {
                    lines.append("**Code Selection**: Lines \(range.startLine)-\(range.endLine) (columns \(range.startColumn)-\(range.endColumn))")
                }
            }
        }

        // 注入最近使用的项目列表
        if !recentProjects.isEmpty {
            lines.append("")
            lines.append("## Recently Used Projects")
            lines.append("")
            lines.append("The user has recently worked on the following projects:")
            lines.append("")

            // 排除当前项目，只显示其他最近项目
            let otherRecentProjects = recentProjects.filter { $0.path != projectPath }
            if !otherRecentProjects.isEmpty {
                for project in otherRecentProjects {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    let lastUsedStr = dateFormatter.string(from: project.lastUsed)
                    lines.append("- **\(project.name)** (`\(project.path)`) — last used: \(lastUsedStr)")
                }
                lines.append("")
                lines.append("The user may want to reference or switch to one of these projects.")
            }
        }

        lines.append("")
        lines.append("You should be aware of the project context when responding to user queries. If the user asks about files, code, or project-specific topics, consider the current project path as the working directory.")
        lines.append("")

        return lines.joined(separator: "\n")
    }
}
