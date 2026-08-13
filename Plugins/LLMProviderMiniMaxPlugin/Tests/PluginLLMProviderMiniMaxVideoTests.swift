import Testing
import Foundation
@testable import LLMProviderMiniMaxPlugin
import KernelLumi

// MARK: - Mock Client

private final class MockMiniMaxVideoClient: MiniMaxVideoAPIProtocol, @unchecked Sendable {
    var shouldFail = false
    var failAtStep: FailStep = .submit
    var generateCallCount = 0
    var downloadURL: URL = URL(string: "https://example.com/video.mp4")!
    var fileName: String = "test_video.mp4"
    var byteCount: Int64? = 2048

    enum FailStep {
        case submit, poll, retrieve
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
            }
        }

        // Return mock video asset (download URL only, no binary download)
        return MiniMaxVideoGeneratedAsset(
            taskID: "mock-task-id",
            fileID: "mock-file-id",
            downloadURL: downloadURL,
            fileName: fileName,
            byteCount: byteCount,
            mimeType: "video/mp4"
        )
    }
}

// MARK: - Tests

struct MiniMaxVideoToolTests {

    @Test("Tool should return error when prompt is empty")
    @MainActor
    func testEmptyPrompt() async throws {
        let mockClient = MockMiniMaxVideoClient()
        let tool = MiniMaxVideoTool(client: mockClient)
        let kernel = KernelLumi()

        let context = LumiToolExecutionContextState(
            conversationID: UUID(),
            toolCallID: "test-call-1",
            toolName: "generate_video",
            currentProjectPath: nil,
            allowedDirectories: [],
            language: .english,
            verbosity: nil
        )

        let arguments: [String: LumiJSONValue] = [
            "prompt": .string(""),
            "model": .string("MiniMax-Hailuo-2.3")
        ]

        let result = try await kernel.withToolExecutionContextState(context) {
            try await tool.execute(arguments: arguments, kernel: kernel)
        }

        #expect(result.contains("prompt"))
        #expect(result.contains("empty"))
        #expect(mockClient.generateCallCount == 0)
    }

    @Test("Tool should handle missing prompt")
    @MainActor
    func testMissingPrompt() async throws {
        let mockClient = MockMiniMaxVideoClient()
        let tool = MiniMaxVideoTool(client: mockClient)
        let kernel = KernelLumi()

        let context = LumiToolExecutionContextState(
            conversationID: UUID(),
            toolCallID: "test-call-2",
            toolName: "generate_video",
            currentProjectPath: nil,
            allowedDirectories: [],
            language: .english,
            verbosity: nil
        )

        let arguments: [String: LumiJSONValue] = [
            "model": .string("MiniMax-Hailuo-2.3")
        ]

        let result = try await kernel.withToolExecutionContextState(context) {
            try await tool.execute(arguments: arguments, kernel: kernel)
        }

        #expect(result.contains("prompt"))
        #expect(result.contains("empty"))
        #expect(mockClient.generateCallCount == 0)
    }

    @Test("Tool should successfully generate video with default parameters")
    @MainActor
    func testSuccessfulGenerationWithDefaults() async throws {
        let mockClient = MockMiniMaxVideoClient()
        let tool = MiniMaxVideoTool(client: mockClient)
        let kernel = KernelLumi()

        let context = LumiToolExecutionContextState(
            conversationID: UUID(),
            toolCallID: "test-call-3",
            toolName: "generate_video",
            currentProjectPath: nil,
            allowedDirectories: [],
            language: .english,
            verbosity: nil
        )

        let arguments: [String: LumiJSONValue] = [
            "prompt": .string("A cat playing piano")
        ]

        let result = try await kernel.withToolExecutionContextState(context) {
            try await tool.execute(arguments: arguments, kernel: kernel)
        }

        #expect(result.contains("Video Generated"))
        #expect(result.contains("MiniMax-Hailuo-2.3"))
        #expect(result.contains("6 seconds"))
        #expect(result.contains("768P"))
        #expect(result.contains("2.0 KB"))
        #expect(result.contains("Download link"))
        #expect(result.contains("24 hours"))
        #expect(result.contains("https://example.com/video.mp4"))
        #expect(mockClient.generateCallCount == 1)

        // Verify NO image/video attachment is pushed (links only, no download)
        let attachments = context.collectImages()
        #expect(attachments.isEmpty)
    }

    @Test("Tool should handle custom parameters")
    @MainActor
    func testCustomParameters() async throws {
        let mockClient = MockMiniMaxVideoClient()
        let tool = MiniMaxVideoTool(client: mockClient)
        let kernel = KernelLumi()

        let context = LumiToolExecutionContextState(
            conversationID: UUID(),
            toolCallID: "test-call-4",
            toolName: "generate_video",
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

        let result = try await kernel.withToolExecutionContextState(context) {
            try await tool.execute(arguments: arguments, kernel: kernel)
        }

        #expect(result.contains("Video Generated"))
        #expect(result.contains("Hailuo-02"))
        #expect(result.contains("10 seconds"))
        #expect(result.contains("1080P"))
        #expect(mockClient.generateCallCount == 1)
    }

    @Test("Tool should handle API error at submit step")
    @MainActor
    func testSubmitError() async throws {
        let mockClient = MockMiniMaxVideoClient()
        mockClient.shouldFail = true
        mockClient.failAtStep = .submit

        let tool = MiniMaxVideoTool(client: mockClient)
        let kernel = KernelLumi()

        let context = LumiToolExecutionContextState(
            conversationID: UUID(),
            toolCallID: "test-call-5",
            toolName: "generate_video",
            currentProjectPath: nil,
            allowedDirectories: [],
            language: .english,
            verbosity: nil
        )

        let arguments: [String: LumiJSONValue] = [
            "prompt": .string("Invalid prompt")
        ]

        let result = try await kernel.withToolExecutionContextState(context) {
            try await tool.execute(arguments: arguments, kernel: kernel)
        }

        #expect(result.contains("Error"))
        #expect(result.contains("400"))
        #expect(mockClient.generateCallCount == 1)
    }

    @Test("Tool should handle task failure at poll step")
    @MainActor
    func testPollError() async throws {
        let mockClient = MockMiniMaxVideoClient()
        mockClient.shouldFail = true
        mockClient.failAtStep = .poll

        let tool = MiniMaxVideoTool(client: mockClient)
        let kernel = KernelLumi()

        let context = LumiToolExecutionContextState(
            conversationID: UUID(),
            toolCallID: "test-call-6",
            toolName: "generate_video",
            currentProjectPath: nil,
            allowedDirectories: [],
            language: .english,
            verbosity: nil
        )

        let arguments: [String: LumiJSONValue] = [
            "prompt": .string("A test prompt")
        ]

        let result = try await kernel.withToolExecutionContextState(context) {
            try await tool.execute(arguments: arguments, kernel: kernel)
        }

        #expect(result.contains("Error"))
        #expect(result.contains("failed"))
        #expect(mockClient.generateCallCount == 1)
    }

    @Test("Tool should handle cancellation")
    @MainActor
    func testCancellation() async throws {
        let mockClient = MockMiniMaxVideoClient()
        let tool = MiniMaxVideoTool(client: mockClient)
        let kernel = KernelLumi()

        let context = LumiToolExecutionContextState(
            conversationID: UUID(),
            toolCallID: "test-call-7",
            toolName: "generate_video",
            currentProjectPath: nil,
            allowedDirectories: [],
            language: .english,
            verbosity: nil
        )

        let arguments: [String: LumiJSONValue] = [
            "prompt": .string("A long video")
        ]

        // Start task
        let task = Task { @MainActor in
            try await kernel.withToolExecutionContextState(context) {
                try await tool.execute(arguments: arguments, kernel: kernel)
            }
        }

        // Wait a short time then cancel (mock loops 20 times with 50ms delay each)
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 second
        context.cancel()

        // Wait for task completion
        let result = try await task.value

        #expect(result.contains("cancelled"))
        #expect(mockClient.generateCallCount == 1)
    }

    @Test("Tool should format byte count correctly")
    @MainActor
    func testByteCountFormatting() async throws {
        let mockClient = MockMiniMaxVideoClient()
        let tool = MiniMaxVideoTool(client: mockClient)
        let kernel = KernelLumi()

        let context = LumiToolExecutionContextState(
            conversationID: UUID(),
            toolCallID: "test-call-8",
            toolName: "generate_video",
            currentProjectPath: nil,
            allowedDirectories: [],
            language: .english,
            verbosity: nil
        )

        let arguments: [String: LumiJSONValue] = [
            "prompt": .string("A test")
        ]

        let result = try await kernel.withToolExecutionContextState(context) {
            try await tool.execute(arguments: arguments, kernel: kernel)
        }

        // Mock returns 2048 bytes, should display as 2.0 KB
        #expect(result.contains("2.0 KB"))
    }

    @Test("Tool should display Unknown size when byteCount is nil")
    @MainActor
    func testByteCountNil() async throws {
        let mockClient = MockMiniMaxVideoClient()
        mockClient.byteCount = nil
        let tool = MiniMaxVideoTool(client: mockClient)
        let kernel = KernelLumi()

        let context = LumiToolExecutionContextState(
            conversationID: UUID(),
            toolCallID: "test-call-9",
            toolName: "generate_video",
            currentProjectPath: nil,
            allowedDirectories: [],
            language: .english,
            verbosity: nil
        )

        let arguments: [String: LumiJSONValue] = [
            "prompt": .string("A test")
        ]

        let result = try await kernel.withToolExecutionContextState(context) {
            try await tool.execute(arguments: arguments, kernel: kernel)
        }

        #expect(result.contains("Unknown"))
        #expect(result.contains("Download link"))
    }
}
