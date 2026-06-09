import Foundation
import LumiCoreKit
import MemoryKit

enum MemoryPromptBuilder {
    static func buildPrompt(projectPath: String, userMessage: String) async -> String? {
        let config = MemoryPlugin.config
        let storage = MemoryStorageService.shared
        let retrieval = MemoryRetrievalService.shared

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

        guard !globalIndex.isEmpty || !projectIndex.isEmpty else {
            return nil
        }

        var lines = [
            "## Memory System",
            "You can use memory tools to save, recall, list, and delete memories."
        ]

        if !globalIndex.isEmpty {
            lines.append("### Global Memory Index")
            lines.append(globalIndex)
        }

        if !projectIndex.isEmpty {
            lines.append("### Project Memory Index")
            lines.append(projectIndex)
        }

        let allRelevant = globalRelevant + projectRelevant
        if !allRelevant.isEmpty {
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

        if let prompt = await MemoryPromptBuilder.buildPrompt(
            projectPath: projectPath,
            userMessage: userMessage
        ), !prompt.isEmpty {
            updated.systemPromptFragments.append(prompt)
        }

        return updated
    }
}
