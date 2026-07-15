import Testing
import Foundation
@testable import LLMProviderMiniMaxPlugin
import LumiCoreKit

// MARK: - Mock Client

private final class MockMiniMaxVideoClient: MiniMaxVideoClientProtocol, @unchecked Sendable {
    var shouldFail = false
    var failAtStep: FailStep = .submit
    var generateCallCount = 0

    enum FailStep {
        case submit, poll, retrieve, download
    }

    func generate(
        prompt: String,
        model: String,
        duration: Int?,
        resolution: String?,
        promptOptimizer: Bool?,
        fastPretreatment: Bool?,
        aigcWatermark: Bool?,
        shouldContinue: @escaping @Sendable () async -> Bool,
        pollInterval: UInt64
    ) async throws -> MiniMaxVideoGeneratedAsset {
        generateCallCount += 1

        // Simulate work with multiple cancellation checkpoints
        for _ in 0..<20 {
            guard await shouldContinue() else {
                throw MiniMaxVideoError.cancelled
            }
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms per iteration
        }

        if shouldFail {
            switch failAtStep {
            case .submit:
                throw MiniMaxVideoError.apiError(code: 400, message: "Invalid prompt")
            case .poll:
                throw MiniMaxVideoError.taskFailed(message: "Task generation failed")
            case .retrieve:
                throw MiniMaxVideoError.missingDownloadURL
            case .download:
                throw MiniMaxVideoError.downloadFailed(message: "Network error")
            }
        }

        // Return mock video data
        let mockVideoData = Data(repeating: 0x00, count: 2048)
        return MiniMaxVideoGeneratedAsset(
            videoData: mockVideoData,
            mimeType: "video/mp4",
            fileName: "test_video.mp4",
            byteCount: 2048
        )
    }
}

// MARK: - Tests

struct MiniMaxVideoToolTests {

    @Test("Tool should return error when prompt is empty")
    func testEmptyPrompt() async throws {
        let mockClient = MockMiniMaxVideoClient()
        let tool = MiniMaxVideoTool(client: mockClient)

        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "test-call-1",
            toolName: "minimax_generate_video",
            currentProjectPath: nil,
            allowedDirectories: [],
            language: .english,
            verbosity: nil
        )

        let arguments: [String: LumiJSONValue] = [
            "prompt": .string(""),
            "model": .string("MiniMax-Hailuo-2.3")
        ]

        let result = try await tool.execute(arguments: arguments, context: context)

        #expect(result.contains("prompt"))
        #expect(result.contains("empty"))
        #expect(mockClient.generateCallCount == 0)
    }

    @Test("Tool should handle missing prompt")
    func testMissingPrompt() async throws {
        let mockClient = MockMiniMaxVideoClient()
        let tool = MiniMaxVideoTool(client: mockClient)

        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "test-call-2",
            toolName: "minimax_generate_video",
            currentProjectPath: nil,
            allowedDirectories: [],
            language: .english,
            verbosity: nil
        )

        let arguments: [String: LumiJSONValue] = [
            "model": .string("MiniMax-Hailuo-2.3")
        ]

        let result = try await tool.execute(arguments: arguments, context: context)

        #expect(result.contains("prompt"))
        #expect(result.contains("empty"))
        #expect(mockClient.generateCallCount == 0)
    }

    @Test("Tool should successfully generate video with default parameters")
    func testSuccessfulGenerationWithDefaults() async throws {
        let mockClient = MockMiniMaxVideoClient()
        let tool = MiniMaxVideoTool(client: mockClient)

        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "test-call-3",
            toolName: "minimax_generate_video",
            currentProjectPath: nil,
            allowedDirectories: [],
            language: .english,
            verbosity: nil
        )

        let arguments: [String: LumiJSONValue] = [
            "prompt": .string("A cat playing piano")
        ]

        let result = try await tool.execute(arguments: arguments, context: context)

        #expect(result.contains("Video Generated"))
        #expect(result.contains("MiniMax-Hailuo-2.3"))
        #expect(result.contains("6 seconds"))
        #expect(result.contains("768P"))
        #expect(result.contains("2.0 KB"))
        #expect(mockClient.generateCallCount == 1)

        // Verify image attachment was added
        let attachments = context.collectImages()
        #expect(attachments.count == 1)
        #expect(attachments.first?.mimeType == "video/mp4")
        #expect(attachments.first?.fileName == "test_video.mp4")
    }

    @Test("Tool should handle custom parameters")
    func testCustomParameters() async throws {
        let mockClient = MockMiniMaxVideoClient()
        let tool = MiniMaxVideoTool(client: mockClient)

        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "test-call-4",
            toolName: "minimax_generate_video",
            currentProjectPath: nil,
            allowedDirectories: [],
            language: .english,
            verbosity: nil
        )

        let arguments: [String: LumiJSONValue] = [
            "prompt": .string("A sunset over the ocean"),
            "model": .string("Hailuo-02"),
            "duration": .int(10),
            "resolution": .string("1080P"),
            "prompt_optimizer": .bool(true)
        ]

        let result = try await tool.execute(arguments: arguments, context: context)

        #expect(result.contains("Video Generated"))
        #expect(result.contains("Hailuo-02"))
        #expect(result.contains("10 seconds"))
        #expect(result.contains("1080P"))
        #expect(mockClient.generateCallCount == 1)
    }

    @Test("Tool should handle API error at submit step")
    func testSubmitError() async throws {
        let mockClient = MockMiniMaxVideoClient()
        mockClient.shouldFail = true
        mockClient.failAtStep = .submit

        let tool = MiniMaxVideoTool(client: mockClient)

        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "test-call-5",
            toolName: "minimax_generate_video",
            currentProjectPath: nil,
            allowedDirectories: [],
            language: .english,
            verbosity: nil
        )

        let arguments: [String: LumiJSONValue] = [
            "prompt": .string("Invalid prompt")
        ]

        let result = try await tool.execute(arguments: arguments, context: context)

        #expect(result.contains("Error"))
        #expect(result.contains("400"))
        #expect(mockClient.generateCallCount == 1)
    }

    @Test("Tool should handle task failure at poll step")
    func testPollError() async throws {
        let mockClient = MockMiniMaxVideoClient()
        mockClient.shouldFail = true
        mockClient.failAtStep = .poll

        let tool = MiniMaxVideoTool(client: mockClient)

        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "test-call-6",
            toolName: "minimax_generate_video",
            currentProjectPath: nil,
            allowedDirectories: [],
            language: .english,
            verbosity: nil
        )

        let arguments: [String: LumiJSONValue] = [
            "prompt": .string("A test prompt")
        ]

        let result = try await tool.execute(arguments: arguments, context: context)

        #expect(result.contains("Error"))
        #expect(result.contains("failed"))
        #expect(mockClient.generateCallCount == 1)
    }

    @Test("Tool should handle cancellation")
    func testCancellation() async throws {
        let mockClient = MockMiniMaxVideoClient()
        let tool = MiniMaxVideoTool(client: mockClient)

        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "test-call-7",
            toolName: "minimax_generate_video",
            currentProjectPath: nil,
            allowedDirectories: [],
            language: .english,
            verbosity: nil
        )

        let arguments: [String: LumiJSONValue] = [
            "prompt": .string("A long video")
        ]

        // Start task
        let task = Task {
            return try await tool.execute(arguments: arguments, context: context)
        }

        // Wait a short time then cancel (mock loops 20 times with 50ms delay each)
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 second
        context.cancel()

        // Wait for task completion
        let result: String = try await task.value

        #expect(result.contains("cancelled"))
        #expect(mockClient.generateCallCount == 1)
    }

    @Test("Tool should format byte count correctly")
    func testByteCountFormatting() async throws {
        let mockClient = MockMiniMaxVideoClient()
        let tool = MiniMaxVideoTool(client: mockClient)

        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "test-call-8",
            toolName: "minimax_generate_video",
            currentProjectPath: nil,
            allowedDirectories: [],
            language: .english,
            verbosity: nil
        )

        let arguments: [String: LumiJSONValue] = [
            "prompt": .string("A test")
        ]

        let result = try await tool.execute(arguments: arguments, context: context)

        // Mock returns 2048 bytes, should display as 2.0 KB
        #expect(result.contains("2.0 KB"))
    }
}
