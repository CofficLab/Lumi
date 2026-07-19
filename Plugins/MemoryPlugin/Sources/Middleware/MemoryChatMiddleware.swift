import Foundation
import LumiKernel

enum MemoryPromptBuilder {
    static func buildPrompt(projectPath: String, userMessage: String) async -> String {
        let config = MemoryPlugin.config
        let storage = MemoryStorageService.shared
        let retrieval = MemoryRetrievalService.shared

        // 始终包含主动保存指引
        var lines = [
            "## Memory System",
            "You have a persistent memory system to remember important information across conversations.",
            "",
            "### When to Save Memories",
            "Be proactive — save when you discover:",
            "- User preferences (communication style, verbosity, output format)",
            "- Project conventions (coding patterns, naming rules, architecture decisions)",
            "- Feedback about your behavior (what works, what to avoid)",
            "- Debugging insights (common issues, workarounds, constraints)",
            "- Workflow patterns (how the user prefers to work)",
            "",
            "Do NOT save: code snippets, already-documented content, or generic knowledge.",
            "Save immediately when you identify valuable insights — don't wait for the user to ask."
        ]

        // 获取已有记忆索引
        var globalIndex = ""
        var projectIndex = ""
        var globalRelevant: [MemoryItem] = []
        var projectRelevant: [MemoryItem] = []

        if config.injectGlobalIndex {
            globalIndex = await storage.readIndex(scope: .global)
            if !globalIndex.isEmpty {
                globalRelevant = await retrieval.findRelevant(
                    query: userMessage,
                    scope: .global,
                    maxResults: config.maxRelevantMemories
                )
            }
        }

        if config.injectProjectIndex, !projectPath.isEmpty {
            let projectScope = MemoryScope.project(projectPath)
            projectIndex = await storage.readIndex(scope: projectScope)
            if !projectIndex.isEmpty {
                projectRelevant = await retrieval.findRelevant(
                    query: userMessage,
                    scope: projectScope,
                    maxResults: config.maxRelevantMemories
                )
            }
        }

        // 追加已有记忆索引
        if !globalIndex.isEmpty {
            lines.append("")
            lines.append("### Global Memory Index")
            lines.append(globalIndex)
        }

        if !projectIndex.isEmpty {
            lines.append("")
            lines.append("### Project Memory Index")
            lines.append(projectIndex)
        }

        // 追加相关记忆
        let allRelevant = globalRelevant + projectRelevant
        if !allRelevant.isEmpty {
            lines.append("")
            lines.append("### Relevant Memories")
            for memory in allRelevant {
                lines.append(memory.formattedContent(staleThresholdDays: config.staleThresholdDays))
            }
        }

        return lines.joined(separator: "\n")
    }
}

struct MemoryChatMiddleware: LumiSendMiddleware {
    func prepare(_ context: LumiSendContext) async throws -> LumiSendContext {
        var updated = context
        let projectPath = context.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let userMessage = context.messages.last(where: { $0.role == .user })?.content ?? ""

        let prompt = await MemoryPromptBuilder.buildPrompt(
            projectPath: projectPath,
            userMessage: userMessage
        )
        updated.systemPromptFragments.append(prompt)

        return updated
    }
}
