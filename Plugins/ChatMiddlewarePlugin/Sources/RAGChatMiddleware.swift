import Foundation
import LumiCoreKit
import RAGKit

enum ChatRAGRuntime {
    private static let databaseDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base
            .appendingPathComponent("Lumi", isDirectory: true)
            .appendingPathComponent("PluginData", isDirectory: true)
            .appendingPathComponent("RAG", isDirectory: true)
            .appendingPathComponent("database", isDirectory: true)
    }()

    private static let onProgress: @Sendable (RAGIndexProgressEvent) -> Void = { _ in }

    static func performRetrieval(projectPath: String, userMessage: String) async -> String? {
        let service = RAGService(
            databaseDirectoryProvider: { databaseDirectory },
            onProgress: onProgress
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
        let projectPath = ChatMiddlewareRuntime.currentProjectPath.value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard RAGIntentAnalyzer.shouldUseRAG(for: userMessage), !projectPath.isEmpty else {
            return updated
        }

        if let prompt = await ChatRAGRuntime.performRetrieval(
            projectPath: projectPath,
            userMessage: userMessage
        ), !prompt.isEmpty {
            updated.systemPromptFragments.append(prompt)
        }

        return updated
    }
}
