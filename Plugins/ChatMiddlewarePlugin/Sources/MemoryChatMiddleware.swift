import Foundation
import LumiCoreKit
import MemoryKit

enum ChatMemoryRuntime {
    private static let retrieval = MemoryRetrievalService()
    private static let memoryRoot: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base
            .appendingPathComponent("Lumi", isDirectory: true)
            .appendingPathComponent("PluginData", isDirectory: true)
            .appendingPathComponent("Memory", isDirectory: true)
    }()

    static func buildPrompt(projectPath: String, userMessage: String) async -> String? {
        let storage = MemoryStorageService(rootURL: memoryRoot)
        let globalIndex = await storage.readIndex(scope: MemoryScope.global)
        var projectIndex = ""
        var globalRelevant: [MemoryItem] = []
        var projectRelevant: [MemoryItem] = []

        if !globalIndex.isEmpty {
            globalRelevant = await retrieval.findRelevant(
                query: userMessage,
                scope: .global,
                storage: storage,
                maxResults: 5
            )
        }

        if !projectPath.isEmpty {
            let projectScope = MemoryScope.project(projectPath)
            projectIndex = await storage.readIndex(scope: projectScope)
            projectRelevant = await retrieval.findRelevant(
                query: userMessage,
                scope: projectScope,
                storage: storage,
                maxResults: 5
            )
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
                lines.append(memory.formattedContent(staleThresholdDays: 30))
            }
        }

        return lines.joined(separator: "\n")
    }
}

struct MemoryChatMiddleware: LumiSendMiddleware {
    func prepare(_ context: LumiSendContext) async throws -> LumiSendContext {
        var updated = context
        let projectPath = ChatMiddlewareRuntime.currentProjectPath.value.trimmingCharacters(in: .whitespacesAndNewlines)
        let userMessage = context.messages.last(where: { $0.role == .user })?.content ?? ""

        let prompt = await ChatMemoryRuntime.buildPrompt(
            projectPath: projectPath,
            userMessage: userMessage
        )

        if let prompt, !prompt.isEmpty {
            updated.systemPromptFragments.append(prompt)
        }

        return updated
    }
}
