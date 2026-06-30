import Foundation
import LumiCoreKit

enum RAGRetrievalRuntime {
    static func performRetrieval(projectPath: String, userMessage: String) async -> String? {
        let service = RAGService(
            databaseDirectoryProvider: RAGPluginRuntime.databaseDirectoryProvider,
            onProgress: { _ in }
        )

        if !service.isInitialized {
            try? await service.initialize()
        }

        guard service.isInitialized else {
            return nil
        }

        if RAGService.isAnyIndexing() || RAGService.isIndexing(projectPath: projectPath) {
            return nil
        }

        do {
            let needsIndex = try await service.checkNeedsIndex(projectPath: projectPath)
            if needsIndex {
                await service.ensureIndexedBackground(projectPath: projectPath)
                return nil
            }

            let response = try await service.retrieve(
                query: userMessage,
                projectPath: projectPath,
                topK: 5
            )

            guard response.hasResults else {
                return nil
            }

            return RAGContextBuilder.buildPrompt(
                query: userMessage,
                results: response.results,
                projectPath: projectPath,
                languagePreference: .english
            )
        } catch {
            return nil
        }
    }
}

struct RAGChatMiddleware: LumiSendMiddleware {
    func prepare(_ context: LumiSendContext) async throws -> LumiSendContext {
        var updated = context
        let userMessage = context.messages.last(where: { $0.role == .user })?.content ?? ""
        let projectPath = context.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)

        guard RAGIntentAnalyzer.shouldUseRAG(for: userMessage), !projectPath.isEmpty else {
            return updated
        }

        if let prompt = await RAGRetrievalRuntime.performRetrieval(
            projectPath: projectPath,
            userMessage: userMessage
        ), !prompt.isEmpty {
            updated.systemPromptFragments.append(prompt)
        }

        return updated
    }
}
