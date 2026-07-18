import Combine
import Foundation
import LumiCoreKit
import Testing
@testable import LumiChatKit

@Suite(.serialized)
@MainActor
struct ChatSectionCoordinatorUpdateSuite {
    @Test func coordinatorForwardsServiceRevisionDuringStreaming() async throws {
        let directory = ChatPerformanceTestSupport.makeTemporaryDatabaseDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let chunks = (0..<25).map { "c\($0)" }
        let provider = ChunkedStreamingMockProvider(
            chunks: chunks,
            chunkDelayNanoseconds: 2_000_000
        )
        let (service, conversationID) = try ChatPerformanceTestSupport.configuredService(
            directory: directory,
            provider: provider
        )
        let coordinator = ChatSectionCoordinator(chatService: service)

        service.append(
            LumiChatMessage(
                conversationID: conversationID,
                role: .user,
                content: "notify test"
            )
        )

        var coordinatorChangeCount = 0
        let cancellable = coordinator.objectWillChange.sink {
            coordinatorChangeCount += 1
        }
        defer { _ = cancellable }

        _ = try await service.runAgentTurn(conversationID: conversationID)

        // Coordinator mirrors ChatService.objectWillChange; high counts imply broad UI invalidation.
        #expect(coordinatorChangeCount >= chunks.count)
    }

    @Test func displayedMessagesKeepsUserMessageIDStableWhileStreaming() async throws {
        let directory = ChatPerformanceTestSupport.makeTemporaryDatabaseDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let provider = ChunkedStreamingMockProvider(
            chunks: ["one", "two", "three"],
            chunkDelayNanoseconds: 5_000_000
        )
        let (service, conversationID) = try ChatPerformanceTestSupport.configuredService(
            directory: directory,
            provider: provider
        )
        let coordinator = ChatSectionCoordinator(chatService: service)

        let userMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .user,
            content: "display ids"
        )
        service.append(userMessage)

        let turnTask = Task { @MainActor in
            _ = try await service.runAgentTurn(conversationID: conversationID)
        }

        var statusContents: Set<String> = []
        let deadline = Date().addingTimeInterval(2)

        while Date() < deadline {
            let displayed = coordinator.displayedMessages(for: conversationID)
            if let status = displayed.last(where: { $0.metadata["isTransientStatus"] == "true" }) {
                #expect(displayed.contains(where: { $0.id == userMessage.id }))
                statusContents.insert(status.content)
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }

        _ = try await turnTask.value

        #expect(statusContents.count >= 1)
    }
}
