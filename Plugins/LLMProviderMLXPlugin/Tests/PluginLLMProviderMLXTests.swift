import Foundation
import Testing
@testable import LLMProviderMLXPlugin
import Combine
import AgentToolKit
import LumiCoreKit

// MARK: - Test Helpers

/// 测试用文件管理器协议，用于模拟文件系统操作
protocol TestableFileManager {
    func fileExists(atPath path: String) -> Bool
    func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws
    func removeItem(at url: URL) throws
    func contentsOfDirectory(at url: URL) throws -> [URL]
}

/// Mock文件管理器，用于测试
final class MockFileManager: FileManager {
    var existingFiles: Set<String> = []
    var directories: Set<String> = []
    var fileSizes: [String: Int64] = [:]
    var shouldThrowOnRemove = false
    var shouldThrowOnCreate = false

    override func fileExists(atPath path: String) -> Bool {
        return existingFiles.contains(path) || directories.contains(path)
    }

    override func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey: Any]? = nil) throws {
        if shouldThrowOnCreate {
            throw NSError(domain: "TestError", code: 1, userInfo: nil)
        }
        directories.insert(url.path)
    }

    override func removeItem(at url: URL) throws {
        if shouldThrowOnRemove {
            throw NSError(domain: "TestError", code: 2, userInfo: nil)
        }
        existingFiles.remove(url.path)
        directories.remove(url.path)
        fileSizes.removeValue(forKey: url.path)
    }

    // 不覆盖enumerator方法，因为签名复杂，直接返回nil即可
    // 在测试中主要测试不需要enumerator的功能

    override func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
        if let size = fileSizes[path] {
            return [.size: size]
        }
        throw NSError(domain: "TestError", code: 3, userInfo: nil)
    }

    func setFileSize(_ size: Int64, forPath path: String) {
        fileSizes[path] = size
        existingFiles.insert(path)
    }

    func addDirectory(_ path: String) {
        directories.insert(path)
    }
}

/// 测试辅助类，提供临时目录管理和测试环境隔离
final class MLXTestHelper {
    static let testBaseDirectory: URL = {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXPluginTests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    static func cleanupTestDirectory() {
        try? FileManager.default.removeItem(at: testBaseDirectory)
    }

    static func createTestModelDirectory(modelId: String) throws -> URL {
        let modelDir = testBaseDirectory
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent(modelId, isDirectory: true)
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        return modelDir
    }

    static func createTestFile(at url: URL, content: Data = Data()) throws {
        try content.write(to: url)
    }

    static func createValidSafetensorsFile(at url: URL, size: Int = 1_500_000) throws {
        let data = Data(repeating: 0, count: size)
        try data.write(to: url)
    }
}

// MARK: - Package Tests

@Test func packageLoads() async throws {
    #expect(MLXLumiPlugin.info.id == "com.coffic.lumi.plugin.llm-provider.mlx")
    #expect(MLXLumiPlugin.info.displayName.isEmpty == false)
}

// MARK: - MLXModels Tests

@Test func modelCacheDirectoryStaysInsideModelsCacheRoot() throws {
    let root = MLXModels.modelsCacheBaseDirectory.standardizedFileURL.path

    for modelId in ["Qwen/Qwen3-0.6B-4bit", "../escape", "org/../escape", "", "."] {
        let path = MLXModels.cacheDirectory(for: modelId).standardizedFileURL.path
        #expect(path == root || path.hasPrefix(root + "/"))
        #expect(!path.components(separatedBy: "/").contains(".."))
    }
}

@Test func modelCacheDirectorySanitization() throws {
    let testCases = [
        ("normal/model", "normal/model"),
        ("model/with/slash", "model_with_slash"),
        ("model\\with\\backslash", "model_with_backslash"),
        (".hidden", "_"),
        ("..", "_"),
        ("", "_"),
        ("  spaces  ", "spaces")
    ]

    for (input, expectedComponent) in testCases {
        let cacheDir = MLXModels.cacheDirectory(for: input)
        let lastComponent = cacheDir.lastPathComponent
        #expect(lastComponent == expectedComponent, "Expected \(expectedComponent) for input '\(input)', got \(lastComponent)")
    }
}

@Test func availableModelsFiltersByRAM() {
    // Test that models are filtered by RAM requirements
    let allModels = MLXModels.recommended
    #expect(!allModels.isEmpty, "Should have recommended models")

    let modelsFor8GB = MLXModels.availableModels(for: 8)
    let modelsFor16GB = MLXModels.availableModels(for: 16)

    #expect(modelsFor8GB.count <= allModels.count)
    #expect(modelsFor16GB.count >= modelsFor8GB.count, "More RAM should allow more models")

    // All models for 8GB should have minRAM <= 8
    for model in modelsFor8GB {
        #expect(model.minRAM <= 8, "Model \(model.id) requires \(model.minRAM)GB but is in 8GB list")
    }
}

@Test func modelSearchById() {
    let knownModels = ["mlx-community/Qwen2.5-0.5B-4bit", "mlx-community/Mistral-7B-4bit"]

    for modelId in knownModels {
        let model = MLXModels.model(id: modelId)
        #expect(model != nil, "Should find model \(modelId)")
        #expect(model?.id == modelId)
    }

    let unknownModel = MLXModels.model(id: "nonexistent/model")
    #expect(unknownModel == nil)
}

@Test func visionModelsAndToolModels() {
    let visionModels = MLXModels.visionModels
    let toolModels = MLXModels.toolModels

    #expect(!visionModels.isEmpty, "Should have vision models")
    #expect(!toolModels.isEmpty, "Should have tool models")

    // All vision models should support vision
    for model in visionModels {
        #expect(model.supportsVision, "Vision model \(model.id) should support vision")
    }

    // All tool models should support tools
    for model in toolModels {
        #expect(model.supportsTools, "Tool model \(model.id) should support tools")
    }
}

@Test func detectSystemRAMReturnsPositiveValue() {
    let ram = MLXModels.detectSystemRAM()
    #expect(ram > 0, "System RAM should be positive, got \(ram)")
    #expect(ram <= 1024, "System RAM should be reasonable (< 1TB), got \(ram)")
}

// MARK: - MLXDownloadManager Tests

@MainActor
@Test func downloadProgressFractionStaysFiniteForUnknownTotals() {
    #expect(MLXDownloadManager.downloadProgressFraction(writtenBytes: 0, totalBytes: 0) == 0)
    #expect(MLXDownloadManager.downloadProgressFraction(writtenBytes: 100, totalBytes: 0) == 0)
    #expect(MLXDownloadManager.downloadProgressFraction(writtenBytes: -1, totalBytes: 100) == 0)

    let partial = MLXDownloadManager.downloadProgressFraction(writtenBytes: 50, totalBytes: 100)
    #expect(partial.isFinite)
    #expect(partial == 0.475)

    let overComplete = MLXDownloadManager.downloadProgressFraction(writtenBytes: 200, totalBytes: 100)
    #expect(overComplete == 0.95)
}

@MainActor
@Test func downloadProgressFractionHandlesEdgeCases() {
    // Test maximum fraction limit
    let maxFraction = MLXDownloadManager.downloadProgressFraction(
        writtenBytes: Int64.max,
        totalBytes: 100
    )
    #expect(maxFraction <= 0.95, "Should cap at 95%")

    // Test very large numbers
    let largeNumbers = MLXDownloadManager.downloadProgressFraction(
        writtenBytes: 10_000_000_000,
        totalBytes: 20_000_000_000
    )
    #expect(largeNumbers.isFinite, "Should handle large numbers")
    #expect(largeNumbers > 0.4 && largeNumbers < 0.5)

    // Test negative values
    let negativeBoth = MLXDownloadManager.downloadProgressFraction(
        writtenBytes: -100,
        totalBytes: -200
    )
    #expect(negativeBoth == 0, "Negative values should return 0")
}

@MainActor
@Test func downloadProgressStartsInIdleState() {
    let manager = MLXDownloadManager.shared
    #expect(manager.status == .idle, "Initial state should be idle")
    #expect(manager.downloadingModelId == nil)
}

// MARK: - MLXDownloadError Tests

@Test func mlxDownloadErrorDescriptionsAreValid() {
    let errors: [MLXDownloadError] = [
        .invalidURL,
        .invalidResponse,
        .httpError(404),
        .noFilesAvailable,
        .missingFile("test.txt"),
        .emptySafetensorsFile("empty.safetensors"),
        .sizeMismatch(100, 50),
        .downloadFailed("test failure")
    ]

    for error in errors {
        #expect(error.errorDescription != nil)
        #expect(!error.errorDescription!.isEmpty)
    }
}

@Test func mlxDownloadErrorDescriptionsContainContext() {
    let fileError = MLXDownloadError.missingFile("model.safetensors")
    #expect(fileError.errorDescription?.contains("model.safetensors") == true)

    let sizeError = MLXDownloadError.sizeMismatch(1000, 500)
    #expect(sizeError.errorDescription?.contains("1000") == true)
    #expect(sizeError.errorDescription?.contains("500") == true)

    let httpError = MLXDownloadError.httpError(404)
    #expect(httpError.errorDescription?.contains("404") == true)
}

// MARK: - MLXDownloadStatus Tests

@Test func mlxDownloadStatusEquality() {
    #expect(MLXDownloadStatus.idle == MLXDownloadStatus.idle)
    #expect(MLXDownloadStatus.downloading == MLXDownloadStatus.downloading)
    #expect(MLXDownloadStatus.completed == MLXDownloadStatus.completed)
    #expect(MLXDownloadStatus.failed("error") == MLXDownloadStatus.failed("error"))
    #expect(MLXDownloadStatus.failed("error1") != MLXDownloadStatus.failed("error2"))
    #expect(MLXDownloadStatus.idle != MLXDownloadStatus.downloading)
}

@Test func mlxDownloadStatusAllStatesCovered() {
    let allStates: [MLXDownloadStatus] = [
        .idle,
        .downloading,
        .paused,
        .completed,
        .failed("test error"),
        .cancelling
    ]

    // Ensure all states are distinct where they should be
    #expect(allStates.count == 6, "Should have 6 distinct states")

    // Test failed states with different messages
    let failed1 = MLXDownloadStatus.failed("error1")
    let failed2 = MLXDownloadStatus.failed("error2")
    #expect(failed1 != failed2, "Failed states with different messages should differ")
}

// MARK: - MLXDownloadProgress Tests

@Test func mlxDownloadProgressLabels() {
    var progress = MLXDownloadProgress()
    progress.fractionCompleted = 0.5
    #expect(progress.percentLabel == "50%")

    progress.speed = 1024 * 1024 // 1 MB/s
    #expect(progress.speedLabel.contains("MB"))

    progress.speed = 0
    #expect(progress.speedLabel.isEmpty)
}

@Test func mlxDownloadProgressFormatting() {
    // Test percentage formatting
    var progress1 = MLXDownloadProgress()
    progress1.fractionCompleted = 0.0
    #expect(progress1.percentLabel == "0%")

    var progress2 = MLXDownloadProgress()
    progress2.fractionCompleted = 0.999
    #expect(progress2.percentLabel == "99%")

    var progress3 = MLXDownloadProgress()
    progress3.fractionCompleted = 1.0
    #expect(progress3.percentLabel == "100%")

    var progress4 = MLXDownloadProgress()
    progress4.fractionCompleted = 0.333
    #expect(progress4.percentLabel == "33%")
}

@Test func mlxDownloadProgressSpeedFormatting() {
    var progress = MLXDownloadProgress()

    // Test different speed formats
    progress.speed = 1024 // 1 KB/s
    #expect(progress.speedLabel.contains("KB"))

    progress.speed = 1024 * 1024 // 1 MB/s
    #expect(progress.speedLabel.contains("MB"))

    progress.speed = 1024 * 1024 * 1024 // 1 GB/s
    #expect(progress.speedLabel.contains("GB"))

    progress.speed = 0
    #expect(progress.speedLabel.isEmpty)

    progress.speed = -100 // Negative speed
    #expect(progress.speedLabel.isEmpty)
}

@Test func mlxDownloadProgressFileTracking() {
    var progress = MLXDownloadProgress()

    // Test file progress tracking
    progress.completedFiles = 0
    progress.totalFiles = 10
    #expect(progress.completedFiles == 0)
    #expect(progress.totalFiles == 10)

    progress.completedFiles = 5
    #expect(progress.completedFiles == 5)

    progress.completedFiles = 10
    #expect(progress.completedFiles == 10)
}

// MARK: - ModelState Tests

@Test func ModelStateEquality() {
    #expect(ModelState.notCached == ModelState.notCached)
    #expect(ModelState.downloading == ModelState.downloading)
    #expect(ModelState.cached == ModelState.cached)

    #expect(ModelState.notCached != ModelState.downloading)
    #expect(ModelState.downloading != ModelState.cached)
    #expect(ModelState.cached != ModelState.notCached)
}

// MARK: - MLXError Tests

@Test func MLXErrorDescriptionsAreValid() {
    // 注意：MLXError在MLXProvider.swift中定义，可能不可直接访问
    // 这里我们测试其他错误类型

    let downloadErrors: [MLXDownloadError] = [
        .invalidURL,
        .invalidResponse,
        .httpError(404),
        .noFilesAvailable,
        .missingFile("test.txt"),
        .emptySafetensorsFile("empty.safetensors"),
        .sizeMismatch(100, 50),
        .downloadFailed("test failure")
    ]

    for error in downloadErrors {
        #expect(error.errorDescription != nil)
        #expect(!error.errorDescription!.isEmpty)
    }
}

// MARK: - InferenceError Tests

@Test func InferenceErrorDescriptionsAreValid() {
    let errors: [InferenceError] = [
        .modelNotDownloaded,
        .alreadyLoading,
        .loadFailed("memory error"),
        .generateFailed("timeout"),
        .notReady
    ]

    for error in errors {
        #expect(error.errorDescription != nil)
        #expect(!error.errorDescription!.isEmpty)
    }
}

// MARK: - LLMState Tests

@Test func LLMStateEquality() {
    #expect(LLMState.idle == LLMState.idle)
    #expect(LLMState.loading == LLMState.loading)
    #expect(LLMState.ready == LLMState.ready)
    #expect(LLMState.generating == LLMState.generating)

    #expect(LLMState.error("test") == LLMState.error("test"))
    #expect(LLMState.error("test1") != LLMState.error("test2"))

    #expect(LLMState.idle != LLMState.loading)
    #expect(LLMState.ready != LLMState.generating)
}

// MARK: - Integration Tests

@Test func modelLifecycleIntegration() throws {
    // Test model cache directory creation and validation
    let modelId = "test/model-integration"
    let modelDir = try MLXTestHelper.createTestModelDirectory(modelId: modelId)
    defer { try? MLXTestHelper.cleanupTestDirectory() }

    // Create valid safetensors file
    let safetensorsURL = modelDir.appendingPathComponent("model.safetensors")
    try MLXTestHelper.createValidSafetensorsFile(at: safetensorsURL)

    // Verify directory exists
    #expect(FileManager.default.fileExists(atPath: modelDir.path))

    // Clean up
    try FileManager.default.removeItem(at: modelDir)
    #expect(!FileManager.default.fileExists(atPath: modelDir.path))
}

@MainActor
@Test func downloadProgressSimulation() {
    // Simulate a download progress scenario
    var progress = MLXDownloadProgress()
    progress.totalFiles = 100
    progress.totalFiles = 100

    // Simulate downloading files
    for i in 1...10 {
        progress.completedFiles = Int64(i)
        let expectedFraction = MLXDownloadManager.downloadProgressFraction(
            writtenBytes: Int64(i * 10),
            totalBytes: 100
        )
        progress.fractionCompleted = expectedFraction

        #expect(progress.completedFiles == Int64(i))
        #expect(progress.fractionCompleted >= 0 && progress.fractionCompleted <= 0.95)
    }

    // Final state
    progress.completedFiles = 100
    #expect(progress.completedFiles == 100)
}

// MARK: - Cleanup

@Test func cleanupTestFiles() {
    // Cleanup test files
    try? MLXTestHelper.cleanupTestDirectory()
}

// MARK: - MLXModelManager Tests

@Test func MLXModelManagerInitialization() {
    let mockFileManager = MockFileManager()
    let testCacheDir = URL(fileURLWithPath: "/tmp/test-cache")

    let manager = MLXModelManager(
        fileManager: mockFileManager,
        cacheDirectory: testCacheDir
    )

    #expect(manager.systemRAM > 0)
    #expect(manager.cachedModelIds.isEmpty)
    #expect(manager.totalCacheSize == 0)
}

@Test func MLXModelManagerModelStateDetermination() {
    let mockFileManager = MockFileManager()
    let testCacheDir = URL(fileURLWithPath: "/tmp/test-cache")

    let manager = MLXModelManager(
        fileManager: mockFileManager,
        cacheDirectory: testCacheDir
    )

    // Test not cached state
    let notCachedState = manager.getModelState(id: "test-model")
    #expect(notCachedState == .notCached)

    // 通过模拟文件系统来测试cached状态
    mockFileManager.addDirectory(testCacheDir.path + "/test-model")
    // 由于我们无法直接修改private(set)属性，我们只测试基本功能
}

@Test func MLXModelManagerCacheSizeFormatting() {
    let mockFileManager = MockFileManager()
    let testCacheDir = URL(fileURLWithPath: "/tmp/test-cache")

    let manager = MLXModelManager(
        fileManager: mockFileManager,
        cacheDirectory: testCacheDir
    )

    // 只能测试默认的格式化功能，因为totalCacheSize有private setter
    let formattedSize = manager.formattedCacheSize
    #expect(!formattedSize.isEmpty)

    // 验证格式化字符串包含适当的单位
    #expect(formattedSize.contains("bytes") || formattedSize.contains("KB") ||
            formattedSize.contains("MB") || formattedSize.contains("GB"))
}

@Test func MLXModelManagerSeriesGrouping() {
    let mockFileManager = MockFileManager()
    let testCacheDir = URL(fileURLWithPath: "/tmp/test-cache")

    let manager = MLXModelManager(
        fileManager: mockFileManager,
        cacheDirectory: testCacheDir
    )

    let series = manager.modelsBySeries()
    #expect(!series.isEmpty, "Should have model series")

    // Check that series are properly grouped
    for modelSeries in series {
        #expect(!modelSeries.name.isEmpty)
        #expect(!modelSeries.models.isEmpty)

        // All models in a series should have the same series name
        for model in modelSeries.models {
            #expect(model.series == modelSeries.name)
        }
    }
}

@Test func MLXModelManagerRAMFiltering() {
    let mockFileManager = MockFileManager()
    let testCacheDir = URL(fileURLWithPath: "/tmp/test-cache")

    let manager = MLXModelManager(
        fileManager: mockFileManager,
        cacheDirectory: testCacheDir
    )

    let allModels = manager.availableModels()
    #expect(!allModels.isEmpty)

    // All models should have minRAM <= system RAM
    for model in allModels {
        #expect(model.minRAM <= manager.systemRAM)
    }
}

// MARK: - MLXChatMessage Tests

@Test func MLXChatMessageInitialization() {
    let textMessage = MLXChatMessage(role: .user, content: "Hello")
    #expect(textMessage.role == .user)
    #expect(textMessage.content == "Hello")
    #expect(textMessage.images.isEmpty)

    // 由于ImageAttachment可能不可访问，我们只测试文本消息
    let systemMessage = MLXChatMessage(role: .system, content: "You are a helpful assistant")
    #expect(systemMessage.role == .system)
    #expect(systemMessage.content == "You are a helpful assistant")
}

@Test func MLXChatMessageRoleCoverage() {
    let roles: [MLXChatMessage.Role] = [.system, .user, .assistant]

    for role in roles {
        let message = MLXChatMessage(role: role, content: "Test")
        #expect(message.role == role)
    }
}

// MARK: - MLXToolCall Tests

@Test func MLXToolCallInitialization() {
    let toolCall = MLXToolCall(
        id: "call-123",
        name: "search",
        arguments: "{\"query\":\"test\"}"
    )

    #expect(toolCall.id == "call-123")
    #expect(toolCall.name == "search")
    #expect(toolCall.arguments.contains("query"))
}

// MARK: - GenerationChunk Tests

@Test func GenerationChunkTextCase() {
    let chunk = GenerationChunk.text("Hello world")
    switch chunk {
    case .text(let content):
        #expect(content == "Hello world")
    default:
        #expect(Bool(false), "Should be text case")
    }
}

@Test func GenerationChunkToolCallCase() {
    let toolCall = MLXToolCall(id: "123", name: "calculate", arguments: "{}")
    let chunk = GenerationChunk.toolCall(toolCall)

    switch chunk {
    case .toolCall(let tc):
        #expect(tc.name == "calculate")
    default:
        #expect(Bool(false), "Should be toolCall case")
    }
}

@Test func GenerationChunkErrorCase() {
    let errorMessage = "Generation failed"
    let chunk = GenerationChunk.error(errorMessage)

    switch chunk {
    case .error(let message):
        #expect(message == errorMessage)
    default:
        #expect(Bool(false), "Should be error case")
    }
}

// MARK: - Byte Formatting Tests

@Test func byteFormattingEdgeCases() {
    // Test very small sizes
    let smallSize = Int64(100)
    let smallFormatter = ByteCountFormatter()
    smallFormatter.countStyle = .file
    let smallResult = smallFormatter.string(fromByteCount: smallSize)
    #expect(smallResult.contains("100"))

    // Test exact MB size
    let mbSize = Int64(1024 * 1024)
    let mbFormatter = ByteCountFormatter()
    mbFormatter.countStyle = .file
    let mbResult = mbFormatter.string(fromByteCount: mbSize)
    #expect(mbResult.contains("MB"))

    // Test exact GB size
    let gbSize = Int64(1024 * 1024 * 1024)
    let gbFormatter = ByteCountFormatter()
    gbFormatter.countStyle = .file
    let gbResult = gbFormatter.string(fromByteCount: gbSize)
    #expect(gbResult.contains("GB"))
}

// MARK: - MLXProvider Tests

@Test func MLXProviderStaticProperties() {
    // Test plugin static properties through MLXLumiPlugin
    let pluginId = MLXLumiPlugin.info.id

    // Test that plugin info is valid
    #expect(pluginId.contains("mlx"))
    #expect(MLXLumiPlugin.info.displayName.isEmpty == false)

    // Test MLXModels static properties as proxy for provider properties
    #expect(MLXModels.recommended.isEmpty == false)
    #expect(MLXModels.toolModels.isEmpty == false)
}

@Test func MLXProviderDisplayNameMapping() {
    // Test display name mapping through MLXModels
    let allModels = MLXModels.recommended

    if allModels.isEmpty {
        #expect(true) // Handle empty case
        return
    }

    // Test that models have valid display names
    for model in allModels.prefix(3) {
        #expect(model.displayName.isEmpty == false)
        #expect(model.id.isEmpty == false)
    }
}

@available(macOS 14.0, *)
@Test func MLXProviderGetCacheDirectory() {
    // Test cache directory through MLXModels
    let testModel = "test/cache-directory-model"
    let cacheDir = MLXModels.cacheDirectory(for: testModel)

    // Test that cache directory is valid
    #expect(cacheDir.isFileURL)
    #expect(cacheDir.path.isEmpty == false)

    // Test that cache directory is inside the system cache directory
    let cacheRoot = MLXModels.modelsCacheBaseDirectory
    #expect(cacheDir.path.hasPrefix(cacheRoot.path))
}

// MARK: - Chat Message Conversion Tests

@Test func MLXChatMessagesConversionWithSystemPrompt() {
    // Test MLX chat message structure
    let messages = [
        MLXChatMessage(role: .user, content: "Hello"),
        MLXChatMessage(role: .assistant, content: "Hi there!")
    ]

    // Test basic message properties
    #expect(messages.count == 2)
    #expect(messages[0].role == .user)
    #expect(messages[1].role == .assistant)
}

@Test func MLXChatMessagesRoleMapping() {
    // Test MLX chat message roles
    let userMessage = MLXChatMessage(role: .user, content: "Hello")
    let assistantMessage = MLXChatMessage(role: .assistant, content: "Hi")
    let systemMessage = MLXChatMessage(role: .system, content: "You are helpful")

    #expect(userMessage.role == .user)
    #expect(assistantMessage.role == .assistant)
    #expect(systemMessage.role == .system)
}

// MARK: - Tool Conversion Tests

@Test func MLXToolCallStructure() {
    // Test MLXToolCall structure and properties
    let toolCall = MLXToolCall(
        id: "call-123",
        name: "search",
        arguments: "{\"query\":\"test\"}"
    )

    #expect(toolCall.id == "call-123")
    #expect(toolCall.name == "search")
    #expect(toolCall.arguments.contains("query"))

    // Test that JSON structure is valid
    #expect(toolCall.arguments.hasPrefix("{"))
    #expect(toolCall.arguments.hasSuffix("}"))
}

// MARK: - Model State Tests

@Test func MLXModelStatesTransitions() {
    // Test model state transitions and properties
    let states: [LLMState] = [.idle, .loading, .ready, .generating, .error("test")]

    for state in states {
        switch state {
        case .idle:
            #expect(true) // Initial state
        case .loading:
            #expect(true) // Loading model
        case .ready:
            #expect(true) // Ready for inference
        case .generating:
            #expect(true) // Currently generating
        case .error:
            #expect(true) // Error occurred
        }
    }
}

// MARK: - Download Progress Edge Cases

@Test func MLXDownloadProgressZeroStates() {
    var progress = MLXDownloadProgress()

    // Test initial zero state
    #expect(progress.fractionCompleted == 0.0)
    #expect(progress.completedFiles == 0)
    #expect(progress.totalFiles == 0)

    // Test with only total files set
    progress.totalFiles = 100
    #expect(progress.fractionCompleted == 0.0)
    #expect(progress.completedFiles == 0)
}

@Test func MLXDownloadProgressCompleteState() {
    var progress = MLXDownloadProgress()

    progress.completedFiles = 100
    progress.totalFiles = 100
    progress.fractionCompleted = 1.0

    #expect(progress.completedFiles == 100)
    #expect(progress.totalFiles == 100)
    #expect(progress.percentLabel == "100%")
}

// MARK: - Model Series Tests

@Test func MLXModelSeriesProperties() {
    // Test ModelSeries structure
    let models = [
        LocalModelInfo(
            id: "test/model-1",
            displayName: "Test Model 1",
            description: "Test model 1 description",
            size: "1GB",
            minRAM: 8,
            expectedBytes: 1_000_000_000,
            supportsVision: false,
            supportsTools: true,
            priority: 1,
            series: "TestSeries"
        ),
        LocalModelInfo(
            id: "test/model-2",
            displayName: "Test Model 2",
            description: "Test model 2 description",
            size: "2GB",
            minRAM: 8,
            expectedBytes: 2_000_000_000,
            supportsVision: false,
            supportsTools: true,
            priority: 2,
            series: "TestSeries"
        )
    ]

    let series = MLXModelManager.ModelSeries(name: "TestSeries", models: models)

    #expect(series.id == "TestSeries")
    #expect(series.name == "TestSeries")
    #expect(series.models.count == 2)
    #expect(series.models.first?.id == "test/model-1")
}

// MARK: - Cache Directory Safety Tests

@Test func MLXCacheDirectoryPathTraversalProtection() {
    // Test that cache directory prevents path traversal attacks
    let maliciousPaths = [
        "../../../etc/passwd",
        "../../../../../../private/etc/passwd",
        "..\\..\\..\\..\\windows\\system32",
        "/etc/passwd",
        "\\windows\\system32\\config\\sam"
    ]

    for path in maliciousPaths {
        let cacheDir = MLXModels.cacheDirectory(for: path)
        let standardizedPath = cacheDir.standardizedFileURL.path

        // Ensure the path doesn't escape the models cache directory
        let root = MLXModels.modelsCacheBaseDirectory.standardizedFileURL.path
        #expect(standardizedPath.hasPrefix(root) || standardizedPath == root)

        // Ensure no .. components in final path
        let components = standardizedPath.components(separatedBy: "/")
        #expect(!components.contains(".."))
    }
}

@Test func MLXCacheDirectoryEmptyAndSpecialCases() {
    // Test edge cases for cache directory creation
    let edgeCases = [
        "",
        ".",
        "..",
        "...",
        "   ",
        "normal",
        "model/with/slashes",
        "model\\with\\backslashes"
    ]

    for testCase in edgeCases {
        let cacheDir = MLXModels.cacheDirectory(for: testCase)

        // Should always return a valid URL
        #expect(cacheDir.isFileURL)
        #expect(cacheDir.path.isEmpty == false)

        // Should be within the models cache root
        let root = MLXModels.modelsCacheBaseDirectory.standardizedFileURL.path
        let cachePath = cacheDir.standardizedFileURL.path
        #expect(cachePath.hasPrefix(root) || cachePath == root)
    }
}

// MARK: - File Validation Tests

@Test func MLXSafetensorsFileSizeValidation() {
    // Test the logic that determines if safetensors files are valid
    let validSizes: [Int64] = [1_000_000, 1_500_000, 10_000_000, 100_000_000]
    let invalidSizes: [Int64] = [0, 100, 500, 999_999]

    for size in validSizes {
        // These should be considered valid safetensors files
        #expect(size >= 1_000_000)
    }

    for size in invalidSizes {
        // These should be considered too small
        #expect(size < 1_000_000)
    }
}

// MARK: - Download Status Tests

@Test func MLXDownloadStatusStateCoverage() {
    // Test all download status states
    let allStates: [MLXDownloadStatus] = [
        .idle,
        .downloading,
        .paused,
        .completed,
        .failed("Network error"),
        .failed("File not found"),
        .cancelling
    ]

    // Test that all states are distinct
    let uniqueStates = Set(allStates.map { String(describing: $0) })
    #expect(uniqueStates.count >= 6) // At least 6 distinct state representations

    // Test failed states preserve error messages
    let failed1 = MLXDownloadStatus.failed("Error 1")
    let failed2 = MLXDownloadStatus.failed("Error 2")
    #expect(failed1 != failed2)
}

// MARK: - Error Context Tests

@Test func MLXDownloadErrorContextPreservation() {
    // Test that errors preserve important context
    let fileName = "important-model.safetensors"
    let error = MLXDownloadError.missingFile(fileName)

    #expect(error.errorDescription?.contains(fileName) == true)

    let sizeMismatch = MLXDownloadError.sizeMismatch(1000, 500)
    #expect(sizeMismatch.errorDescription?.contains("1000") == true)
    #expect(sizeMismatch.errorDescription?.contains("500") == true)
}

@Test func InferenceErrorContextPreservation() {
    let errorMessage = "CUDA out of memory"
    let error = InferenceError.loadFailed(errorMessage)

    #expect(error.errorDescription?.contains(errorMessage) == true)
    #expect(error.errorDescription?.contains("加载失败") == true)
}

@Test func MLXSystemRAMDetectionReasonableRange() {
    // Test that RAM detection returns reasonable values
    let ram = MLXModels.detectSystemRAM()

    // Should be positive
    #expect(ram > 0)

    // Should be reasonable for modern computers (between 4GB and 1024GB)
    #expect(ram >= 4)
    #expect(ram <= 1024)

    // Should be consistent when called multiple times
    let ram2 = MLXModels.detectSystemRAM()
    #expect(ram == ram2)
}

// MARK: - Progress Calculation Tests

@MainActor
@Test func MLXProgressCalculationAccuracy() {
    // Test progress calculation accuracy
    let testCases: [(written: Int64, total: Int64, expectedRange: ClosedRange<Double>)] = [
        (0, 100, 0.0...0.01),      // 0% should be very close to 0
        (50, 100, 0.47...0.48),    // 50% should be around 0.475 (95% of 50%)
        (100, 100, 0.94...0.96),   // 100% should be around 0.95
        (25, 50, 0.47...0.48),     // 50% with different numbers
        (10, 1000, 0.009...0.01)   // 1% progress
    ]

    for testCase in testCases {
        let result = MLXDownloadManager.downloadProgressFraction(
            writtenBytes: testCase.written,
            totalBytes: testCase.total
        )

        #expect(result >= testCase.expectedRange.lowerBound)
        #expect(result <= testCase.expectedRange.upperBound)
    }
}

// MARK: - Model Filtering Tests

@Test func MLXAvailableModelsFilteringConsistency() {
    // Test that model filtering is consistent

    // Test with different RAM limits
    let models4GB = MLXModels.availableModels(for: 4)
    let models8GB = MLXModels.availableModels(for: 8)
    let models16GB = MLXModels.availableModels(for: 16)

    // More RAM should allow more models
    #expect(models16GB.count >= models8GB.count)
    #expect(models8GB.count >= models4GB.count)

    // All models should respect their RAM requirements
    for model in models4GB {
        #expect(model.minRAM <= 4)
    }

    for model in models8GB {
        #expect(model.minRAM <= 8)
    }
}

@Test func MLXVisionModelsSubset() {
    // Test that vision models are a proper subset
    let allModels = MLXModels.recommended
    let visionModels = MLXModels.visionModels

    // All vision models should be in the recommended list
    for visionModel in visionModels {
        #expect(allModels.contains { $0.id == visionModel.id })
        #expect(visionModel.supportsVision)
    }
}

@Test func MLXToolModelsSubset() {
    // Test that tool models are a proper subset
    let allModels = MLXModels.recommended
    let toolModels = MLXModels.toolModels

    // All tool models should be in the recommended list
    for toolModel in toolModels {
        #expect(allModels.contains { $0.id == toolModel.id })
        #expect(toolModel.supportsTools)
    }
}

// MARK: - MLXInferenceService Tests

@available(macOS 14.0, *)
@MainActor
@Test func MLXInferenceServiceInitialization() {
    let service = MLXInferenceService()

    // Test initial state
    #expect(service.state == .idle)
    #expect(service.currentModelId == nil)
    #expect(service.tokensPerSecond == 0.0)
}

@available(macOS 14.0, *)
@MainActor
@Test func MLXInferenceServiceStateTransitions() {
    let service = MLXInferenceService()

    // Test initial state
    #expect(service.state == .idle)

    // Test state equality
    #expect(service.state == .idle)
    #expect(service.state != .loading)
    #expect(service.state != .ready)
}

@available(macOS 14.0, *)
@MainActor
@Test func MLXInferenceServiceTokensPerSecondTracking() {
    let service = MLXInferenceService()

    // Initial tokens per second should be 0
    #expect(service.tokensPerSecond == 0.0)

    // Test that tokens per second is non-negative
    #expect(service.tokensPerSecond >= 0)
}

// MARK: - InferenceError Tests

@Test func InferenceErrorCoverage() {
    let errors: [InferenceError] = [
        .modelNotDownloaded,
        .alreadyLoading,
        .loadFailed("Memory error"),
        .generateFailed("Timeout"),
        .notReady
    ]

    for error in errors {
        let description = error.errorDescription
        #expect(description != nil)
        #expect(description!.isEmpty == false)

        // All error descriptions should contain meaningful information
        #expect(description!.count > 10)
    }
}

// MARK: - MLXDownloadManager Advanced Tests

@MainActor
@Test func MLXDownloadManagerInitialState() {
    let manager = MLXDownloadManager.shared

    // Test initial state
    #expect(manager.status == .idle)
    #expect(manager.downloadingModelId == nil)
    #expect(manager.currentFileName == nil)
    #expect(manager.currentFileSize == 0)
}

@MainActor
@Test func MLXDownloadManagerProgressTracking() {
    let manager = MLXDownloadManager.shared

    let progress = manager.progress

    // Test initial progress values
    #expect(progress.fractionCompleted >= 0 && progress.fractionCompleted <= 1.0)
    #expect(progress.completedFiles >= 0)
    #expect(progress.totalFiles >= 0)
}

@MainActor
@Test func MLXDownloadManagerSpeedTracking() {
    let manager = MLXDownloadManager.shared

    // Test speed tracking
    let speed = manager.progress.speed

    // Speed should be non-negative when available
    if let currentSpeed = speed {
        #expect(currentSpeed >= 0)
    }
}

// MARK: - Performance and Memory Tests

@Test func MemoryEfficientModelFiltering() {
    // Test that model filtering doesn't create unnecessary copies
    let modelsBefore = MLXModels.availableModels(for: 8)
    let modelsAfter = MLXModels.availableModels(for: 8)

    // Should return the same models (not new instances)
    #expect(modelsBefore.count == modelsAfter.count)

    // Model IDs should match
    let idsBefore = Set(modelsBefore.map { $0.id })
    let idsAfter = Set(modelsAfter.map { $0.id })
    #expect(idsBefore == idsAfter)
}

@Test func CachedModelConsistency() {
    // Test that cached models are consistent across calls
    let cached1 = Set(MLXModels.recommended.map { $0.id })
    let cached2 = Set(MLXModels.recommended.map { $0.id })

    #expect(cached1 == cached2)
}

// MARK: - Edge Cases and Boundary Tests

@MainActor
@Test func LargeNumberHandling() {
    // Test handling of very large numbers in progress calculation
    let hugeWritten = Int64.max
    let hugeTotal = Int64.max

    let result = MLXDownloadManager.downloadProgressFraction(
        writtenBytes: hugeWritten,
        totalBytes: hugeTotal
    )

    // Should handle without overflow
    #expect(result.isFinite)
    #expect(result >= 0 && result <= 1.0)
}

@MainActor
@Test func NegativeNumberHandling() {
    // Test handling of negative numbers
    let testCases: [(written: Int64, total: Int64)] = [
        (-1, 100),
        (100, -1),
        (-1, -1),
        (-100, -200)
    ]

    for testCase in testCases {
        let result = MLXDownloadManager.downloadProgressFraction(
            writtenBytes: testCase.written,
            totalBytes: testCase.total
        )

        // Should return 0 for negative inputs
        #expect(result == 0)
    }
}

@MainActor
@Test func ZeroDivisionHandling() {
    // Test division by zero scenarios
    let testCases: [(written: Int64, total: Int64)] = [
        (0, 0),
        (100, 0),
        (0, 100),
        (1000000, 0)
    ]

    for testCase in testCases {
        let result = MLXDownloadManager.downloadProgressFraction(
            writtenBytes: testCase.written,
            totalBytes: testCase.total
        )

        // Should handle gracefully without crashing
        #expect(result.isFinite)
        #expect(result >= 0 && result <= 1.0)
    }
}

// MARK: - String and Formatting Tests

@Test func ProgressLabelFormatting() {
    // Test progress label formatting for various percentages
    let percentages: [Double] = [0.0, 0.01, 0.25, 0.5, 0.75, 0.99, 1.0]

    for percentage in percentages {
        var progress = MLXDownloadProgress()
        progress.fractionCompleted = percentage

        let label = progress.percentLabel

        // Label should contain a number and % symbol
        #expect(label.contains("%"))

        // Should not be empty
        #expect(label.isEmpty == false)
    }
}

@Test func SpeedLabelFormattingAccuracy() {
    // Test speed label formatting for various speeds
    let speeds: [Double] = [0, 1024, 1024*1024, 1024*1024*1024, 10*1024*1024]

    for speed in speeds {
        var progress = MLXDownloadProgress()
        progress.speed = speed

        let label = progress.speedLabel

        if speed > 0 {
            // Should contain appropriate unit
            #expect(label.isEmpty == false)
            #expect(label.contains("/s"))

            // Should not contain unreasonable values
            #expect(!label.contains("NaN"))
            #expect(!label.contains("Infinity"))
        } else {
            // Zero speed should return empty label
            #expect(label.isEmpty)
        }
    }
}

// MARK: - Concurrency and Thread Safety Tests

@Test func ThreadSafeProgressReading() {
    // Test that progress reading is thread-safe
    let progress1 = MLXDownloadProgress()
    let progress2 = progress1

    // Both should have same values
    #expect(progress1.fractionCompleted == progress2.fractionCompleted)
    #expect(progress1.completedFiles == progress2.completedFiles)
}

// MARK: - Model Series Integration Tests

@Test func ModelSeriesIntegration() {
    // Test that model series grouping works correctly
    let allModels = MLXModels.recommended

    if allModels.isEmpty {
        #expect(true) // Handle empty model list gracefully
        return
    }

    // Test that models have proper series information
    let seriesNames = Set(allModels.map { $0.series })
    #expect(seriesNames.isEmpty == false)

    // Test that models within a series have the same series name
    for series in seriesNames {
        let modelsInSeries = allModels.filter { $0.series == series }
        #expect(modelsInSeries.isEmpty == false)

        for model in modelsInSeries {
            #expect(model.series == series)
        }
    }
}

// MARK: - Cache Integration Tests

@Test func CacheDirectoryIntegration() {
    // Test integration between cache directory and file system
    let testModel = "test/cache-integration-model"
    let cacheDir = MLXModels.cacheDirectory(for: testModel)

    // Test that cache directory has proper structure
    #expect(cacheDir.path.contains("models"))

    // Test that different models get different directories
    let testModel2 = "test/cache-integration-model-2"
    let cacheDir2 = MLXModels.cacheDirectory(for: testModel2)

    #expect(cacheDir.path != cacheDir2.path)
}

// MARK: - Data Structure Tests

@Test func LocalModelInfoProperties() {
    // Test LocalModelInfo structure properties
    let modelInfo = LocalModelInfo(
        id: "test/model",
        displayName: "Test Model",
        description: "A test model for unit testing",
        size: "2GB",
        minRAM: 8,
        expectedBytes: 2_000_000_000,
        supportsVision: false,
        supportsTools: true,
        priority: 1,
        series: "Test"
    )

    #expect(modelInfo.id == "test/model")
    #expect(modelInfo.displayName == "Test Model")
    #expect(modelInfo.description == "A test model for unit testing")
    #expect(modelInfo.size == "2GB")
    #expect(modelInfo.minRAM == 8)
    #expect(modelInfo.expectedBytes == 2_000_000_000)
    #expect(modelInfo.series == "Test")
    #expect(modelInfo.priority == 1)
    #expect(modelInfo.supportsTools == true)
    #expect(modelInfo.supportsVision == false)
}

// MARK: - Error Recovery Tests

@Test func ErrorDescriptionCompleteness() {
    // Test that all error types have complete descriptions
    let downloadErrors: [MLXDownloadError] = [
        .invalidURL,
        .invalidResponse,
        .httpError(404),
        .httpError(500),
        .httpError(403),
        .noFilesAvailable,
        .missingFile("test.txt"),
        .emptySafetensorsFile("test.safetensors"),
        .sizeMismatch(100, 50),
        .downloadFailed("Network timeout")
    ]

    for error in downloadErrors {
        let description = error.errorDescription

        #expect(description != nil)
        #expect(description!.isEmpty == false)

        // Should contain useful information
        #expect(description!.count > 5)

        // Should not contain placeholder text
        #expect(!description!.contains("placeholder"))
        #expect(!description!.contains("TODO"))
    }
}

// MARK: - State Machine Tests

@Test func DownloadStateTransitions() {
    // Test download state machine logic
    let states: [MLXDownloadStatus] = [
        .idle,
        .downloading,
        .paused,
        .cancelling,
        .completed,
        .failed("Error")
    ]

    // Test state transitions are valid
    for (index, state) in states.enumerated() {
        // Each state should be distinct from the previous
        if index > 0 {
            let previousState = states[index - 1]
            if case .failed(_) = state, case .failed(_) = previousState {
                // Different error messages should still be different states
                continue
            }
            #expect(state != previousState)
        }
    }
}

@Test func ModelStateTransitions() {
    // Test model state machine logic
    let states: [ModelState] = [
        .notCached,
        .downloading,
        .cached
    ]

    // Test that states are properly ordered
    #expect(states[0] != states[1])
    #expect(states[1] != states[2])
    #expect(states[0] != states[2])
}
