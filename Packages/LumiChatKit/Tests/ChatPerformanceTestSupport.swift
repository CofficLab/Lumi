import Foundation
import LumiCoreKit
@testable import LumiChatKit

enum ChatPerformanceTestSupport {
    static func makeTemporaryDatabaseDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiChatKitPerf-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @MainActor
    static func configuredService(
        directory: URL,
        provider: any LumiLLMProvider
    ) throws -> (ChatService, UUID) {
        let service = try ChatService(configuration: .coreDatabase(directory: directory))
        let conversationID = service.createConversation(title: "Perf")
        service.registerProviders([provider])
        service.selectProvider(id: type(of: provider).info.id, model: "mock", for: conversationID)
        return (service, conversationID)
    }
}

final class ChunkedStreamingMockProvider: LumiLLMProvider, @unchecked Sendable {
    static let info = LumiLLMProviderInfo(
        id: "chunked-streaming-mock",
        displayName: "Chunked Streaming Mock",
        defaultModel: "mock",
        availableModels: ["mock"],
        websiteURL: URL(string: "https://example.com")!
    )

    let chunks: [String]
    let chunkDelayNanoseconds: UInt64

    init(chunks: [String], chunkDelayNanoseconds: UInt64 = 0) {
        self.chunks = chunks
        self.chunkDelayNanoseconds = chunkDelayNanoseconds
    }

    func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        try await sendStreaming(request) { _ in }
    }

    func lumiResolveAPIKey() throws -> String { "mock-key" }

    func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        guard let conversationID = request.messages.last?.conversationID else {
            throw NSError(domain: "ChunkedStreamingMockProvider", code: 1)
        }

        for chunk in chunks {
            if chunkDelayNanoseconds > 0 {
                try await Task.sleep(nanoseconds: chunkDelayNanoseconds)
            }
            await onChunk(LumiStreamChunk(content: chunk, eventTitle: "生成中"))
        }
        await onChunk(LumiStreamChunk(isDone: true, eventTitle: "结束"))

        return LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: chunks.joined()
        )
    }

    func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        .available
    }

    func providerStatus() -> LumiLLMProviderStatus? {
        nil
    }
}
