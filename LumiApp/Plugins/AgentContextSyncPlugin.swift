import AgentToolKit
import Foundation
import LumiCoreKit
import PluginAgentContextSync
import SuperLogKit
import os

actor AgentContextSyncPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = PluginAgentContextSync.AgentContextSyncPlugin.logger
    nonisolated static let emoji = PluginAgentContextSync.AgentContextSyncPlugin.emoji
    nonisolated static let verbose = PluginAgentContextSync.AgentContextSyncPlugin.verbose

    static let id = PluginAgentContextSync.AgentContextSyncPlugin.id
    static let displayName = PluginAgentContextSync.AgentContextSyncPlugin.displayName
    static let description = PluginAgentContextSync.AgentContextSyncPlugin.description
    static let iconName = PluginAgentContextSync.AgentContextSyncPlugin.iconName
    static var category: PluginCategory {
        PluginCategory(package: PluginAgentContextSync.AgentContextSyncPlugin.category)
    }
    static var order: Int { PluginAgentContextSync.AgentContextSyncPlugin.order }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = AgentContextSyncPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(AgentContextSyncSuperSendMiddleware())]
    }
}

@MainActor
private final class AgentContextSyncSuperSendMiddleware: SuperSendMiddleware, SuperLog {
    nonisolated static let emoji = "🔄"
    nonisolated static let verbose: Bool = true
    let id: String = "agent-context-sync"
    let order: Int = 0

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        let projectPath = ctx.projectVM.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let projectName = ctx.projectVM.currentProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedFileURL = ctx.currentFileURL
        let codeSelectionRange = ctx.projectVM.codeSelectionRange
        let recentProjects = ctx.recentProjectsVM.getRecentProjects()

        guard !projectPath.isEmpty else {
            await next(ctx)
            return
        }

        let prompt = buildProjectContextPrompt(
            projectName: projectName,
            projectPath: projectPath,
            selectedFileURL: selectedFileURL,
            codeSelectionRange: codeSelectionRange,
            recentProjects: recentProjects,
            languagePreference: ctx.projectVM.languagePreference
        )
        ctx.transientSystemPrompts.append(prompt)

        await next(ctx)
    }

    private func buildProjectContextPrompt(
        projectName: String,
        projectPath: String,
        selectedFileURL: URL?,
        codeSelectionRange: CodeSelectionRange?,
        recentProjects: [Project],
        languagePreference: LanguagePreference
    ) -> String {
        switch languagePreference {
        case .chinese:
            buildChineseProjectContextPrompt(
                projectName: projectName,
                projectPath: projectPath,
                selectedFileURL: selectedFileURL,
                codeSelectionRange: codeSelectionRange,
                recentProjects: recentProjects
            )
        case .english:
            buildEnglishProjectContextPrompt(
                projectName: projectName,
                projectPath: projectPath,
                selectedFileURL: selectedFileURL,
                codeSelectionRange: codeSelectionRange,
                recentProjects: recentProjects
            )
        }
    }

    private func buildEnglishProjectContextPrompt(
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
        appendSelectedFileContext(
            to: &lines,
            projectPath: projectPath,
            selectedFileURL: selectedFileURL,
            codeSelectionRange: codeSelectionRange,
            language: .english
        )
        appendRecentProjects(to: &lines, projectPath: projectPath, recentProjects: recentProjects, language: .english)
        lines.append("")
        lines.append("You should be aware of the project context when responding to user queries. If the user asks about files, code, or project-specific topics, consider the current project path as the working directory.")
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private func buildChineseProjectContextPrompt(
        projectName: String,
        projectPath: String,
        selectedFileURL: URL?,
        codeSelectionRange: CodeSelectionRange?,
        recentProjects: [Project]
    ) -> String {
        var lines: [String] = []
        lines.append("## 当前项目上下文")
        lines.append("")
        lines.append("用户当前正在以下项目中工作：")
        lines.append("")
        lines.append("**项目名称**：\(projectName.isEmpty ? "未知" : projectName)")
        lines.append("**项目路径**：`\(projectPath)`")
        appendSelectedFileContext(
            to: &lines,
            projectPath: projectPath,
            selectedFileURL: selectedFileURL,
            codeSelectionRange: codeSelectionRange,
            language: .chinese
        )
        appendRecentProjects(to: &lines, projectPath: projectPath, recentProjects: recentProjects, language: .chinese)
        lines.append("")
        lines.append("回复用户时应考虑当前项目上下文。如果用户询问文件、代码或项目相关主题，请将当前项目路径视为工作目录。")
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private func appendSelectedFileContext(
        to lines: inout [String],
        projectPath: String,
        selectedFileURL: URL?,
        codeSelectionRange: CodeSelectionRange?,
        language: LanguagePreference
    ) {
        guard let fileURL = selectedFileURL else { return }
        let filePath = fileURL.path
        let relativePath: String
        if filePath.hasPrefix(projectPath) {
            let index = filePath.index(filePath.startIndex, offsetBy: projectPath.count)
            relativePath = String(filePath[index...]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        } else {
            relativePath = filePath
        }
        let displayPath = relativePath.isEmpty ? filePath : relativePath

        switch language {
        case .english:
            lines.append("**Selected File**: `\(displayPath)`")
            if let range = codeSelectionRange {
                if range.isSingleLine {
                    lines.append("**Code Selection**: Line \(range.startLine), columns \(range.startColumn)-\(range.endColumn)")
                } else {
                    lines.append("**Code Selection**: Lines \(range.startLine)-\(range.endLine) (columns \(range.startColumn)-\(range.endColumn))")
                }
            }
        case .chinese:
            lines.append("**当前选中文件**：`\(displayPath)`")
            if let range = codeSelectionRange {
                if range.isSingleLine {
                    lines.append("**代码选区**：第 \(range.startLine) 行，列 \(range.startColumn)-\(range.endColumn)")
                } else {
                    lines.append("**代码选区**：第 \(range.startLine)-\(range.endLine) 行（列 \(range.startColumn)-\(range.endColumn)）")
                }
            }
        }
    }

    private func appendRecentProjects(
        to lines: inout [String],
        projectPath: String,
        recentProjects: [Project],
        language: LanguagePreference
    ) {
        let otherRecentProjects = recentProjects.filter { $0.path != projectPath }
        guard !otherRecentProjects.isEmpty else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        lines.append("")
        lines.append(language == .english ? "## Recently Used Projects" : "## 最近使用的项目")
        lines.append("")
        lines.append(language == .english ? "The user has recently worked on the following projects:" : "用户最近还使用过以下项目：")
        lines.append("")
        for project in otherRecentProjects {
            let lastUsedStr = dateFormatter.string(from: project.lastUsed)
            if language == .english {
                lines.append("- **\(project.name)** (`\(project.path)`) - last used: \(lastUsedStr)")
            } else {
                lines.append("- **\(project.name)** (`\(project.path)`) - 最后使用：\(lastUsedStr)")
            }
        }
        lines.append("")
        lines.append(language == .english ? "The user may want to reference or switch to one of these projects." : "用户可能会引用或切换到这些项目之一。")
    }
}
