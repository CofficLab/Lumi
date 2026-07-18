import Foundation
import LumiCoreKit
import Testing
@testable import LumiChatKit

@Suite(.serialized)
@MainActor
struct ChatStreamingUpdateSuite {
    @Test func streamingIncrementsRevisionOncePerChunkWithoutPersisting() async throws {
        let directory = ChatPerformanceTestSupport.makeTemporaryDatabaseDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let chunks = (0..<40).map { "token\($0)" }
        let provider = ChunkedStreamingMockProvider(chunks: chunks)
        let (service, conversationID) = try ChatPerformanceTestSupport.configuredService(
            directory: directory,
            provider: provider
        )

        service.append(
            LumiChatMessage(
                conversationID: conversationID,
                role: .user,
                content: "stream me"
            )
        )

        let revisionBefore = service.revision
        let persistBefore = service.persistCallCount

        _ = try await service.runAgentTurn(conversationID: conversationID)

        let revisionDelta = service.revision - revisionBefore
        let persistDelta = service.persistCallCount - persistBefore

        // Each streamed token currently bumps revision once; this documents UI refresh pressure.
        #expect(revisionDelta >= chunks.count + 1)

        // Persist should happen for durable messages, not for transient stream status updates.
        #expect(persistDelta <= 2)
        #expect(persistDelta >= 1)
    }

    @Test func streamingDoesNotPersistTransientStatusMessages() async throws {
        let directory = ChatPerformanceTestSupport.makeTemporaryDatabaseDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let provider = ChunkedStreamingMockProvider(chunks: ["hello", "world"])
        let (service, conversationID) = try ChatPerformanceTestSupport.configuredService(
            directory: directory,
            provider: provider
        )

        service.append(
            LumiChatMessage(
                conversationID: conversationID,
                role: .user,
                content: "hello"
            )
        )
        _ = try await service.runAgentTurn(conversationID: conversationID)

        let persistedMessages = service.messages(for: conversationID)
        #expect(persistedMessages.contains(where: { $0.role == .user }))
        #expect(persistedMessages.contains(where: { $0.role == .assistant }))
        #expect(
            persistedMessages.contains(where: {
                $0.metadata["isTransientStatus"] == "true"
            }) == false
        )
        #expect(service.transientStatusMessage(for: conversationID) == nil)
    }

    @Test func streamingStatusUsesStableRowIDAcrossChunks() async throws {
        let directory = ChatPerformanceTestSupport.makeTemporaryDatabaseDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let provider = ChunkedStreamingMockProvider(
            chunks: ["a", "b", "c"],
            chunkDelayNanoseconds: 5_000_000
        )
        let (service, conversationID) = try ChatPerformanceTestSupport.configuredService(
            directory: directory,
            provider: provider
        )

        service.append(
            LumiChatMessage(
                conversationID: conversationID,
                role: .user,
                content: "watch status"
            )
        )

        let turnTask = Task { @MainActor in
            _ = try await service.runAgentTurn(conversationID: conversationID)
        }

        var observedStatusIDs: Set<UUID> = []
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if let statusID = service.transientStatusMessage(for: conversationID)?.id {
                observedStatusIDs.insert(statusID)
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }

        _ = try await turnTask.value

        #expect(observedStatusIDs.count <= 1)
    }

    @Test func eachPersistedMessageAppendTriggersSnapshotSave() throws {
        let directory = ChatPerformanceTestSupport.makeTemporaryDatabaseDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let service = try ChatService(configuration: .coreDatabase(directory: directory))
        let conversationID = service.createConversation(title: "Persist budget")
        let persistBefore = service.persistCallCount

        for index in 0..<5 {
            service.append(
                LumiChatMessage(
                    conversationID: conversationID,
                    role: .user,
                    content: "Message \(index)"
                )
            )
        }

        #expect(service.persistCallCount - persistBefore == 5)
    }
}
