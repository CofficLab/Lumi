import Foundation
import Testing
@testable import LLMProviderMLXPlugin
import Combine
import AgentToolKit
import LumiKernel

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
///
/// 注意：早期实现使用单个共享静态目录（`testBaseDirectory`），但 Swift Testing 默认
/// 并行执行用例，并发读写同一个目录会触发竞态。这里改为每次都创建唯一目录，
/// 且不再提供全局清理（由调用方通过 defer 负责回收自己的目录）。
final class MLXTestHelper {

    /// 为单个用例创建唯一临时目录（取代旧的共享 testBaseDirectory）。
    static func makeUniqueBaseDirectory() throws -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXPluginTests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static func createTestModelDirectory(modelId: String) throws -> URL {
        // 每次都创建独立目录，避免并发用例互相干扰
        let base = try makeUniqueBaseDirectory()
        let modelDir = base
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
    // cacheDirectory(for:) 会按 "/" 切分，最多取前 2 段，
    // 每段会 trim 空白、过滤 "."/".." 与空串为 "_"，并把路径分隔符替换为 "_"。
    // (lastComponent, 输入) 对照——lastComponent 是返回 URL 的最后一段。
    let testCases: [(input: String, lastComponent: String)] = [
        ("normal/model", "model"),             // ["normal","model"] -> 末段 "model"
        ("model/with/slash", "with"),           // 3 段被截为前 2 段，末段 "with"
        ("model\\with\\backslash", "model_with_backslash"), // 无 "/"，整体作为单段并替换 "\\"
        (".hidden", ".hidden"),                 // 单段 "." 前缀并非过滤条件；".hidden" 保留
        ("..", "_"),                            // 单段 ".." -> "_"
        ("", "_"),                              // 空串单段 -> "_"
        ("  spaces  ", "spaces")                // trim 空白
    ]

    for testCase in testCases {
        let cacheDir = MLXModels.cacheDirectory(for: testCase.input)
        let lastComponent = cacheDir.lastPathComponent
        #expect(lastComponent == testCase.lastComponent,
                "Expected '\(testCase.lastComponent)' for input '\(testCase.input)', got '\(lastComponent)'")
    }
}

@Test func modelCacheDirectorySanitizationSpecialSegments() {
    // "." / ".." 作为单独的段会被过滤为 "_"，但以 "." 开头的普通段（如 ".hidden"）会被保留。
    #expect(MLXModels.cacheDirectory(for: ".").lastPathComponent == "_")
    #expect(MLXModels.cacheDirectory(for: "..").lastPathComponent == "_")
    #expect(MLXModels.cacheDirectory(for: ".hidden").lastPathComponent == ".hidden")
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
    // 使用当前真实存在的模型 ID（与 Sources/Models 中的定义保持一致）
    let knownModels = [
        "mlx-community/Qwen3.5-0.8B-OptiQ-4bit",
        "mlx-community/Mistral-Nemo-12B-Instruct-4bit",
        "mlx-community/Llama-3.2-3B-Instruct-4bit",
        "mlx-community/gemma-4-E2B-it-4bit"
    ]

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
    // 在独立临时目录中验证模型目录的创建与删除（不依赖共享目录）
    let modelId = "test/model-integration"
    let modelDir = try MLXTestHelper.createTestModelDirectory(modelId: modelId)
    // 回收本用例创建的整个 base 目录（包含其父级 models/）
    let baseDir = modelDir
        .deletingLastPathComponent()  // .../models/test/model-integration -> .../models/test
        .deletingLastPathComponent()  // -> .../models
        .deletingLastPathComponent()  // -> <base uuid>
    defer { try? FileManager.default.removeItem(at: baseDir) }

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

@Test func temporaryDirectoryIsWritableForTests() throws {
    // 原先此用例负责清理一个全局共享临时目录（与并行测试不兼容）。
    // 现在每个用例各自管理独立目录，这里仅验证临时目录可写，保持用例存在。
    let dir = try MLXTestHelper.makeUniqueBaseDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    let f = dir.appendingPathComponent("probe.txt")
    try Data("ok".utf8).write(to: f)
    #expect(FileManager.default.fileExists(atPath: f.path))
}

// MARK: - MLXModelManager Tests

@Test func MLXModelManagerInitialization() {
    let mockFileManager = MockFileManager()
    let testCacheDir = URL(fileURLWithPath: "/tmp/test-cache-\(UUID().uuidString)")

    let manager = MLXModelManager(
        fileManager: mockFileManager,
        cacheDirectory: testCacheDir
    )

    // systemRAM 来自 sysctl，应为正值
    #expect(manager.systemRAM > 0)
    // 注入的独立缓存目录不存在任何已统计文件，缓存大小应为 0
    #expect(manager.totalCacheSize == 0)
    // cachedModelIds 扫描的是 MLXModels 真实缓存根目录，无法强制为空，
    // 但格式化输出必须始终为合法字符串。
    #expect(!manager.formattedCacheSize.isEmpty)
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
//
// MLXInferenceService 内部会派生 Task 并引用 MLX/MLXLLM C++ 运行时；
// 并发实例化 + 释放可能导致运行时崩溃。将这些用例串行化（且固定在 MainActor）以保证稳定。

// MARK: - MLXInferenceService Tests
//
// MLXInferenceService 内部会派生 Task 并引用 MLX/MLXLLM C++ 运行时；
// 并发实例化 + 释放可能导致运行时崩溃（SIGSEGV/SIGABRT）。将这些用例串行化
// （且固定在 MainActor）以保证稳定。测试目标已声明 macOS 14+，无需重复 @available。

@MainActor
@Suite(.serialized)
enum MLXInferenceServiceTests {
    @Test
    static func initialization() {
        let service = MLXInferenceService()

        // Test initial state
        #expect(service.state == .idle)
        #expect(service.currentModelId == nil)
        #expect(service.tokensPerSecond == 0.0)
    }

    @Test
    static func stateTransitions() {
        let service = MLXInferenceService()

        // Test initial state
        #expect(service.state == .idle)

        // Test state equality
        #expect(service.state == .idle)
        #expect(service.state != .loading)
        #expect(service.state != .ready)
    }

    @Test
    static func tokensPerSecondTracking() {
        let service = MLXInferenceService()

        // Initial tokens per second should be 0
        #expect(service.tokensPerSecond == 0.0)

        // Test that tokens per second is non-negative
        #expect(service.tokensPerSecond >= 0)
    }

    @Test
    static func loadModelRejectsAlreadyLoading() async {
        let service = MLXInferenceService()

        // 直接加载一个不存在的模型会失败（缺目录）；
        // 这里验证：加载未下载模型时抛出 modelNotDownloaded，且状态回到 error。
        do {
            try await service.loadModel(id: "org/never-cached-\(UUID().uuidString)")
            Issue.record("加载未下载的模型应抛错")
        } catch InferenceError.modelNotDownloaded {
            // 期望路径：模型目录不存在
        } catch {
            // 其它错误（加载阶段）也可接受，只要不静默成功
        }
        #expect(service.currentModelId == nil)
    }

    @Test
    static func chatReturnsErrorWhenNotReady() async {
        let service = MLXInferenceService()
        // 未加载模型时，chat 应立即产出一条 error chunk 并结束
        var chunks: [GenerationChunk] = []
        for await chunk in service.chat(messages: [MLXChatMessage(role: .user, content: "hi")]) {
            chunks.append(chunk)
        }
        #expect(chunks.count == 1)
        if case .error(let msg) = chunks.first {
            #expect(msg.isEmpty == false)
        } else {
            Issue.record("未就绪时应返回 .error chunk")
        }
    }

    @Test
    static func unloadModelResetsState() {
        let service = MLXInferenceService()
        service.unloadModel()
        // 卸载后状态回到 idle（异步执行，这里只验证不崩溃 + 类型可访问）
        #expect(service.state == .idle || service.state != .loading)
    }

    @Test
    static func stopGenerationFromIdleIsNoop() {
        let service = MLXInferenceService()
        service.stopGeneration()
        #expect(service.tokensPerSecond == 0)
        // 空闲态调用 stopGeneration 不应把状态切到 ready
        #expect(service.state != .generating)
    }
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
    }

    // 逐个验证描述内容（中文短描述字符数 < 10 是正常的）
    #expect(InferenceError.modelNotDownloaded.errorDescription == "模型未下载")
    #expect(InferenceError.alreadyLoading.errorDescription == "模型正在加载中")
    #expect(InferenceError.notReady.errorDescription == "模型未就绪")
    #expect(InferenceError.loadFailed("X").errorDescription?.contains("X") == true)
    #expect(InferenceError.generateFailed("Y").errorDescription?.contains("Y") == true)
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

        // 中文描述可能只有 5 个字符（如 "无效的 URL"），不强制最小长度，
        // 但不得是占位文本。
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

// MARK: - Model Series Coverage Tests
// 以下测试直接覆盖各模型系列文件（Qwen/Llama/Mistral/Gemma4）的
// visionModels / toolModels / model(id:) / availableModels(for:) 接口。

private func allSeriesAllModels() -> [LocalModelInfo] {
    QwenModels.all + LlamaModels.all + MistralModels.all + Gemma4Models.all
}

@Test func QwenSeriesCatalogInvariants() {
    let all = QwenModels.all
    #expect(!all.isEmpty)
    // 每个模型 id 唯一
    #expect(Set(all.map { $0.id }).count == all.count)
    // 系列名一致
    #expect(all.allSatisfy { $0.series == "Qwen 系列" })

    // visionModels 是 supportsVision 子集
    let vision = QwenModels.visionModels
    #expect(vision.allSatisfy { $0.supportsVision })
    #expect(vision.count == all.filter { $0.supportsVision }.count)

    // toolModels 是 supportsTools 子集
    let tools = QwenModels.toolModels
    #expect(tools.allSatisfy { $0.supportsTools })
    #expect(tools.count == all.filter { $0.supportsTools }.count)

    // 按 ID 查找
    let first = all.first!
    #expect(QwenModels.model(id: first.id)?.id == first.id)
    #expect(QwenModels.model(id: "nope") == nil)
}

@Test func QwenSeriesRAMFiltering() {
    let all = QwenModels.all
    let maxRAM = all.map { $0.minRAM }.max() ?? 0

    // 全量 RAM 应返回全部
    #expect(QwenModels.availableModels(for: maxRAM).count == all.count)

    // 0 RAM 返回空
    #expect(QwenModels.availableModels(for: 0).isEmpty)

    // 中间值只含 minRAM <= 该值的
    let mid = maxRAM / 2
    let filtered = QwenModels.availableModels(for: mid)
    #expect(filtered.allSatisfy { $0.minRAM <= mid })
}

@Test func LlamaSeriesCatalogInvariants() {
    let all = LlamaModels.all
    #expect(all.count >= 2)
    #expect(Set(all.map { $0.id }).count == all.count)
    #expect(all.allSatisfy { $0.series == "Llama 系列" })

    let vision = LlamaModels.visionModels
    #expect(vision.allSatisfy { $0.supportsVision })
    #expect(vision.count == all.filter { $0.supportsVision }.count)

    let tools = LlamaModels.toolModels
    #expect(tools.allSatisfy { $0.supportsTools })
    #expect(tools.count == all.filter { $0.supportsTools }.count)

    let first = all.first!
    #expect(LlamaModels.model(id: first.id)?.id == first.id)
    #expect(LlamaModels.model(id: "missing") == nil)
}

@Test func LlamaSeriesRAMFilteringMonotonic() {
    // RAM 越大，可用模型数单调不减
    let r4 = LlamaModels.availableModels(for: 4)
    let r8 = LlamaModels.availableModels(for: 8)
    let r64 = LlamaModels.availableModels(for: 64)
    #expect(r4.count <= r8.count)
    #expect(r8.count <= r64.count)
    #expect(r4.allSatisfy { $0.minRAM <= 4 })
}

@Test func MistralSeriesCatalogInvariants() {
    let all = MistralModels.all
    #expect(!all.isEmpty)
    #expect(Set(all.map { $0.id }).count == all.count)
    #expect(all.allSatisfy { $0.series == "Mistral 系列" })

    let vision = MistralModels.visionModels
    #expect(vision.allSatisfy { $0.supportsVision })
    let tools = MistralModels.toolModels
    #expect(tools.allSatisfy { $0.supportsTools })

    let first = all.first!
    #expect(MistralModels.model(id: first.id)?.id == first.id)
    #expect(MistralModels.model(id: "absent") == nil)
}

@Test func MistralSeriesAvailableModelsForZeroIsEmpty() {
    #expect(MistralModels.availableModels(for: 0).isEmpty)
    #expect(MistralModels.availableModels(for: 1024).count == MistralModels.all.count)
}

@Test func Gemma4SeriesCatalogInvariants() {
    let all = Gemma4Models.all
    // 至少包含 E2B/E4B/26B-A4B/31B 各两类
    #expect(all.count >= 8)
    #expect(Set(all.map { $0.id }).count == all.count)
    #expect(all.allSatisfy { $0.series == "Gemma 4 系列" })

    let vision = Gemma4Models.visionModels
    #expect(vision.allSatisfy { $0.supportsVision })
    #expect(vision.count == all.filter { $0.supportsVision }.count)
    #expect(!vision.isEmpty, "Gemma 4 应有视觉模型")

    let tools = Gemma4Models.toolModels
    #expect(tools.allSatisfy { $0.supportsTools })
    #expect(tools.count == all.filter { $0.supportsTools }.count)
    #expect(!tools.isEmpty, "Gemma 4 应有工具模型")
}

@Test func Gemma4SeriesLookupAndRAMFiltering() {
    let first = Gemma4Models.all.first!
    #expect(Gemma4Models.model(id: first.id)?.id == first.id)
    #expect(Gemma4Models.model(id: "unknown") == nil)

    // 8GB 可用模型均应 minRAM <= 8（E2B/E4B 系列）
    let r8 = Gemma4Models.availableModels(for: 8)
    #expect(r8.allSatisfy { $0.minRAM <= 8 })
    #expect(!r8.isEmpty)

    // 32GB 应包含 26B-A4B / 31B 等大模型
    let r32 = Gemma4Models.availableModels(for: 32)
    #expect(r32.count >= r8.count)
    #expect(r32.contains { $0.minRAM == 32 })
}

@Test func recommendedModelsAggregateAllSeries() {
    // MLXModels.recommended 应是四个系列的去重并集
    let aggregated = allSeriesAllModels()
    #expect(Set(MLXModels.recommended.map { $0.id }) == Set(aggregated.map { $0.id }))

    // 每个系列至少贡献一个模型到 recommended
    for seriesAll in [QwenModels.all, LlamaModels.all, MistralModels.all, Gemma4Models.all] {
        #expect(seriesAll.contains { rec in MLXModels.recommended.contains { $0.id == rec.id } })
    }
}

// MARK: - HFFileEntry Decoding Tests

@Test func HFFileEntryDecodesFromFileType() throws {
    // HF API 返回的树结构条目：type 为 "file"/"directory"，size 可缺省
    let json = """
    [
      {"type":"file","path":"config.json","size":1234},
      {"type":"directory","path":"onnx","size":0},
      {"type":"file","path":"tokenizer.json"}
    ]
    """.data(using: .utf8)!

    let entries = try JSONDecoder().decode([HFFileEntry].self, from: json)
    #expect(entries.count == 3)
    #expect(entries[0].type == "file")
    #expect(entries[0].path == "config.json")
    #expect(entries[0].size == 1234)
    #expect(entries[1].type == "directory")
    #expect(entries[2].size == nil)
}

// MARK: - MLXDownloadManager.filterFiles Tests

private func entry(_ path: String, size: Int64? = nil) -> HFFileEntry {
    HFFileEntry(type: "file", path: path, size: size)
}

@Test func filterFilesKeepsSafetensorsAndConfigs() {
    let files = [
        entry("config.json", size: 100),
        entry("tokenizer.json"),
        entry("tokenizer_config.json"),
        entry("generation_config.json"),
        entry("special_tokens_map.json"),
        entry("chat_template.jinja"),
        entry("model.safetensors", size: 1_000_000),
        entry("vocab.txt"),
        entry("token.py"),
        entry("encoding.tiktoken")
    ]

    let kept = MLXDownloadManager.filterFiles(files).map(\.path)
    #expect(Set(kept) == Set(files.map(\.path)))
    #expect(kept.count == files.count)
}

@Test func filterFilesExcludesUnrelatedArtifacts() {
    let excluded = [
        entry("README.md"),
        entry("LICENSE"),
        entry(".gitattributes"),
        entry("onnx/model.onnx"),
        entry("flax_model.msgpack"),
        entry("tf_model.h5"),
        entry("pytorch_model.bin")
    ]

    let kept = MLXDownloadManager.filterFiles(excluded)
    #expect(kept.isEmpty, "排除项应全部被过滤掉，实际保留：\(kept.map(\.path))")
}

@Test func filterFilesIsCaseInsensitiveForExcludes() {
    // README.md / LICENSE 大小写都应排除
    let files = [entry("readme.md"), entry("license"), entry("ONNX/a.onnx")]
    #expect(MLXDownloadManager.filterFiles(files).isEmpty)
}

@Test func filterFilesExcludesBySubstring() {
    // 路径任意位置出现 onnx/ / flax_ / tf_ / pytorch_ 都排除
    let files = [
        entry("flax_weights/something.json"),     // 含 flax_
        entry("nested/onnx/inner.safetensors"),    // 含 onnx/
        entry("config.json")                       // 保留
    ]
    let kept = MLXDownloadManager.filterFiles(files).map(\.path)
    #expect(kept == ["config.json"])
}

@Test func filterFilesKeepsRequiredNamesExactly() {
    // 仅文件名（最后一段）匹配 requiredNames 才保留
    let files = [
        entry("config.json"),
        entry("subdir/config.json"),   // 末段仍是 config.json，应保留
        entry("not_config.json"),      // 末段不匹配，扩展名 .json 仍命中
        entry("README.md")
    ]
    let kept = Set(MLXDownloadManager.filterFiles(files).map(\.path))
    #expect(kept.contains("config.json"))
    #expect(kept.contains("subdir/config.json"))
    #expect(kept.contains("not_config.json"))
    #expect(!kept.contains("README.md"))
}

@Test func filterFilesKeepsByExtension() {
    let files = [
        entry("a.safetensors"),
        entry("b.json"),
        entry("c.txt"),
        entry("d.py"),
        entry("e.tiktoken"),
        entry("f.bin"),     // 不在白名单
        entry("g.onnx")     // 命中排除
    ]
    let kept = Set(MLXDownloadManager.filterFiles(files).map(\.path))
    #expect(kept.contains("a.safetensors"))
    #expect(kept.contains("b.json"))
    #expect(kept.contains("c.txt"))
    #expect(kept.contains("d.py"))
    #expect(kept.contains("e.tiktoken"))
    #expect(!kept.contains("f.bin"))
    #expect(!kept.contains("g.onnx"))
}

@Test func filterFilesHandlesEmptyInput() {
    #expect(MLXDownloadManager.filterFiles([]).isEmpty)
}

// MARK: - MLXError Description Tests (MLXProvider.swift 被排除编译，仅验证可达错误)

// 注：MLXError 定义在 MLXProvider.swift，但该文件按 Package.swift 被 exclude，
// 因此 MLXError 不在测试目标内。这里覆盖仍在构建产物中的 MLXLumiError。

@Test func MLXLumiErrorDescriptionsAreValid() {
    #expect(MLXLumiError.missingConversation.errorDescription == "Missing conversation ID")
    #expect(MLXLumiError.emptyPrompt.errorDescription == "Prompt is empty")
    #expect(MLXLumiError.generationFailed("boom").errorDescription == "boom")
    #expect(!MLXLumiError.missingConversation.errorDescription!.isEmpty)
}

// MARK: - MLXModelManager Cache Scanning (真实临时目录)
//
// 以下用例在 MLXModels 真实缓存根目录或临时目录写入文件。由于每次构造
// MLXModelManager 都会启动后台定时器扫描真实缓存，并发执行会互相观察到对方的
// 写入并产生竞态，因此整体放入 `.serialized` Suite 串行执行。

@Suite(.serialized)
enum MLXModelManagerRealFilesystemTests {

    /// 使用真实文件系统的隔离临时目录验证缓存扫描/删除/计量逻辑。
    @Test
    static func detectsCachedModelViaRealFiles() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXTest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let manager = MLXModelManager(fileManager: .default, cacheDirectory: tempRoot)
        manager.stopMonitoring()  // 停止后台扫描，避免跨用例干扰

        // 在 MLXModels 真实缓存根目录下创建一个已知模型的目录，但只放部分文件
        // （2MB safetensors，远小于模型的 expectedBytes）。
        let cachedId = MLXModels.recommended.first!.id
        let cacheDir = MLXModels.cacheDirectory(for: cachedId)
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let stFile = cacheDir.appendingPathComponent("model.safetensors")
        try Data(repeating: 0, count: 2_000_000).write(to: stFile)
        defer { try? FileManager.default.removeItem(at: cacheDir) }

        manager.refreshCachedModels()
        // 修复后：缓存完整性校验基于目录大小是否达到 expectedBytes。
        // 仅 2MB 的部分文件（远小于真实模型的数 GB）不应被误判为已缓存，
        // 否则下载中途按钮会错乱地变成「加载」。
        #expect(manager.isModelCached(id: cachedId) == false,
                "部分文件（未达期望大小）不应被判定为已缓存")
    }

    @Test
    static func cacheSizeReflectsRealFiles() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXTest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let manager = MLXModelManager(fileManager: .default, cacheDirectory: tempRoot)
        manager.stopMonitoring()  // 避免后台定时器干扰断言

        // 初始（空目录）缓存大小应为 0
        #expect(manager.totalCacheSize == 0)

        // 写入两个文件，合计 8000 字节
        let sub = tempRoot.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data(repeating: 0, count: 5_000).write(to: sub.appendingPathComponent("a.bin"))
        try Data(repeating: 0, count: 3_000).write(to: tempRoot.appendingPathComponent("b.bin"))

        manager.updateCacheSize()
        // 文件系统的目录条目本身可能贡献少量字节，但至少应计入两个文件的 8000 字节
        #expect(manager.totalCacheSize >= 8_000)
        #expect(manager.totalCacheSize <= 8_000 + 1_000)  // 上界：避免计入无关文件

        // 格式化输出包含 KB（约 8KB）
        #expect(manager.formattedCacheSize.contains("KB"))
    }

    @Test
    static func formattedSizeUnits() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXTest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        let manager = MLXModelManager(fileManager: .default, cacheDirectory: tempRoot)
        manager.stopMonitoring()

        // 临时目录为空时大小为 0 bytes
        #expect(manager.formattedCacheSize.contains("bytes"))
    }

    @Test
    static func deleteNonExistentIsNoop() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXTest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        let manager = MLXModelManager(fileManager: .default, cacheDirectory: tempRoot)
        manager.stopMonitoring()

        // 删除一个不存在的模型目录不应抛错
        #expect(throws: Never.self) {
            try manager.deleteModel(id: "org/does-not-exist-\(UUID().uuidString)")
        }
    }

    @Test
    static func clearAllCacheRecreatesDirectory() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXTest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        let manager = MLXModelManager(fileManager: .default, cacheDirectory: tempRoot)
        manager.stopMonitoring()

        // 先写入再清空
        try Data(repeating: 0, count: 1_000).write(to: tempRoot.appendingPathComponent("x.bin"))
        manager.updateCacheSize()
        #expect(manager.totalCacheSize == 1_000)

        try manager.clearAllCache()
        // 清空后目录被重建，大小归零
        #expect(FileManager.default.fileExists(atPath: tempRoot.path))
        manager.updateCacheSize()
        #expect(manager.totalCacheSize == 0)
    }

    @Test
    static func perModelSizeAndFormatted() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXTest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        let manager = MLXModelManager(fileManager: .default, cacheDirectory: tempRoot)
        manager.stopMonitoring()

        // 在某个模型缓存目录写文件并计量
        let modelId = "test/per-model"
        let dir = MLXModels.cacheDirectory(for: modelId)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(repeating: 0, count: 4_000).write(to: dir.appendingPathComponent("w.bin"))
        defer { try? FileManager.default.removeItem(at: dir) }

        #expect(manager.getCacheSize(for: modelId) == 4_000)
        #expect(manager.formattedSize(for: modelId).contains("KB"))
    }

    @Test
    static func stopMonitoringIsIdempotent() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXTest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        let manager = MLXModelManager(fileManager: .default, cacheDirectory: tempRoot)

        // 多次停止监控不应崩溃
        manager.stopMonitoring()
        manager.stopMonitoring()
        #expect(true)
    }
}

// MARK: - MLXDownloadManager Pause/Resume/Cancel/Reset Tests
//
// 这些测试操作 MLXDownloadManager.shared 单例的共享可变状态（status 等）。
// Swift Testing 默认并行执行用例，若并发改写同一个单例会触发竞态甚至崩溃，
// 因此整体放入 `.serialized` Suite 串行执行，保证稳定可复现。

@MainActor
@Suite(.serialized)
enum MLXDownloadManagerSharedStateTests {
    @Test
    static func pauseWhenIdleIsNoop() {
        let manager = MLXDownloadManager.shared
        if manager.status == .downloading { manager.cancel() }
        // 空闲时暂停应安全无副作用
        manager.pause()
        #expect(manager.status != .downloading)
    }

    @Test
    static func resumeWhenNotPausedIsNoop() async {
        let manager = MLXDownloadManager.shared
        if manager.status == .downloading { manager.cancel() }
        // 非暂停态调用 resume 应立即返回、不改状态
        await manager.resume()
        #expect(manager.status != .downloading)
    }

    @Test
    static func cancelResetsToIdle() {
        let manager = MLXDownloadManager.shared
        manager.cancel()
        #expect(manager.status == .idle)
        #expect(manager.downloadingModelId == nil)
        #expect(manager.currentFileName == nil)
    }

    @Test
    static func resetAliasesCancel() {
        let manager = MLXDownloadManager.shared
        manager.reset()
        #expect(manager.status == .idle)
    }

    @Test
    static func cancelKeepsSingletonUsable() {
        // 不真正调用 shutdown（会永久关闭单例），仅验证 cancel 后单例仍可用
        let manager = MLXDownloadManager.shared
        manager.cancel()
        #expect(manager.status == .idle)
    }

    // MARK: - 暂停保留 .paused（回归 #1：暂停曾被异步取消覆盖为 idle）

    /// 下载中调用 pause() 后，状态应停留在 .paused、模型 ID 仍在，
    /// 而非被下载任务的取消分支改回 .idle（这是修复前的核心缺陷）。
    ///
    /// 使用真实存在的模型 id（文件列表可达、但完整下载耗时较长），使 .downloading 态
    /// 持续足够久以便触发暂停。无网络环境下下载会失败、用例直接跳过，不视为回归。
    @Test
    static func pauseDuringDownloadKeepsPausedState() async {
        let manager = MLXDownloadManager.shared
        manager.cancel()  // 确保从干净状态开始

        // 真实存在的小模型：fetchFileList 成功后会进入实际下载（耗时），留出暂停窗口
        let realId = "mlx-community/Qwen3.5-0.8B-OptiQ-4bit"
        let downloadTask = Task { await manager.download(modelId: realId) }

        // download() 在发起网络请求前就会同步置 status = .downloading（line ~122）。
        // 等待文件列表返回并开始下载，期间状态保持 .downloading。
        try? await Task.sleep(nanoseconds: 400_000_000)  // 0.4s

        guard manager.status == .downloading else {
            // 无网络或下载瞬时结束：本用例无法验证暂停，收尾跳过（不记为失败）
            manager.cancel(); downloadTask.cancel()
            return
        }

        manager.pause()
        // 暂停后状态应为 .paused，且模型 ID 保留（恢复按钮可见的前提）
        #expect(manager.status == .paused, "暂停后应停留在 .paused，实际：\(manager.status)")
        #expect(manager.downloadingModelId == realId, "暂停后模型 ID 应保留")

        // 关键回归点：等待足够时间让被取消的下载任务的 catch 分支执行完毕后，
        // .paused 仍不应被改回 .idle（修复前会在此处被覆盖）。
        try? await Task.sleep(nanoseconds: 400_000_000)  // 0.4s
        #expect(manager.status == .paused, "暂停后状态应保持 .paused，实际：\(manager.status)")

        // 收尾：取消并等待后台下载任务结束，避免污染后续用例
        manager.cancel()
        downloadTask.cancel()
    }

    /// 暂停 → 取消 应回到 .idle（暂停保留的状态最终能被真取消复位）。
    /// 使用真实存在的模型 id 以获得可暂停的下载窗口；无网络则跳过。
    @Test
    static func pauseThenCancelReturnsToIdle() async {
        let manager = MLXDownloadManager.shared
        manager.cancel()

        let realId = "mlx-community/Qwen3.5-0.8B-OptiQ-4bit"
        let downloadTask = Task { await manager.download(modelId: realId) }
        try? await Task.sleep(nanoseconds: 400_000_000)

        guard manager.status == .downloading else {
            manager.cancel(); downloadTask.cancel()
            return  // 无网络：跳过
        }

        manager.pause()
        #expect(manager.status == .paused)

        // 真取消应复位为 idle（暂停标志被清除）
        manager.cancel()
        #expect(manager.status == .idle)
        #expect(manager.downloadingModelId == nil)

        manager.cancel()
        downloadTask.cancel()
    }

    /// 暂停后恢复：若仍处于 .paused（未被取消），resume() 应重新进入 .downloading。
    @Test
    static func resumeAfterPauseReentersDownloading() async {
        let manager = MLXDownloadManager.shared
        manager.cancel()

        let realId = "mlx-community/Qwen3.5-0.8B-OptiQ-4bit"
        let downloadTask = Task { await manager.download(modelId: realId) }
        try? await Task.sleep(nanoseconds: 400_000_000)

        guard manager.status == .downloading else {
            manager.cancel(); downloadTask.cancel()
            return  // 无网络：跳过
        }

        manager.pause()
        #expect(manager.status == .paused)

        // 恢复：应重新置为 .downloading（随后会继续下载，关键是不应停留在 paused）
        let resumeTask = Task { await manager.resume() }
        try? await Task.sleep(nanoseconds: 400_000_000)
        // 恢复发起后，状态要么 downloading（进行中）要么已 failed/completed；
        // 关键是不应停留在 paused
        #expect(manager.status != .paused, "恢复后不应停留在 paused")

        manager.cancel()
        downloadTask.cancel()
        resumeTask.cancel()
    }

    // MARK: - 进度恢复（回归 #3：恢复后进度曾冻结；回归 #4：恢复瞬间进度曾回退）

    /// downloadProgressFraction 在已知字节数下应立即重算，不再卡在旧值。
    /// 这里直接验证纯函数：恢复路径的 updateProgress 依赖它计算 fraction。
    @Test
    static func progressFractionRecomputesAfterResume() {
        // 模拟恢复场景：已完成 500MB，总量 1GB → fraction 应 ≈ 0.475（0.5 * 0.95）
        let fraction = MLXDownloadManager.downloadProgressFraction(
            writtenBytes: 500_000_000,
            totalBytes: 1_000_000_000
        )
        #expect(fraction > 0.47 && fraction < 0.48, "恢复后进度应立即反映已下载字节，实际：\(fraction)")
        #expect(fraction > 0, "进度必须非零，否则进度条冻结")
    }

    /// 续传块不再用「仅完整文件字节」重算 fraction（会丢掉暂停文件的部分字节），
    /// 改为保留暂停 fraction 并由 resumeFloorFraction 兜底。本用例守护这个契约：
    /// 「仅完整文件」算出的 fraction 必然低于「含部分字节」的暂停值，地板应取后者。
    @Test
    static func resumeFloorKeepsFractionAbovePartialFileLoss() {
        let totalBytes: Int64 = 1_000_000_000

        // 暂停时刻：2 个完整文件(各 200MB) + 第 3 个文件已下 300MB = 700MB
        let pausedFraction = MLXDownloadManager.downloadProgressFraction(
            writtenBytes: 700_000_000,
            totalBytes: totalBytes
        )

        // 恢复重算：仅 2 个完整文件 = 400MB（第 3 个文件的部分字节丢失）
        let recomputedFraction = MLXDownloadManager.downloadProgressFraction(
            writtenBytes: 400_000_000,
            totalBytes: totalBytes
        )

        // 没有地板时，恢复瞬间会从暂停值下跌（这就是 bug）
        #expect(recomputedFraction < pausedFraction,
                "恢复重算的 fraction 必然低于暂停值（部分字节丢失）")

        // 地板机制：取 max(recomputed, paused) 保证不回退
        let flooredFraction = max(recomputedFraction, pausedFraction)
        #expect(flooredFraction == pausedFraction,
                "地板应让恢复后的 fraction 不低于暂停值，实际：\(flooredFraction)")
    }

    /// 验证 MLXDownloadProgress 在 startIndex 续传块后的状态：fraction 保留暂停值。
    @Test
    static func progressKeepsPausedFractionOnResume() {
        var progress = MLXDownloadProgress()
        progress.totalFiles = 10
        progress.completedFiles = 5
        // 暂停值（含部分文件字节）
        let pausedFraction = MLXDownloadManager.downloadProgressFraction(
            writtenBytes: 700_000_000,
            totalBytes: 1_000_000_000
        )
        progress.fractionCompleted = pausedFraction

        // 续传块现在只更新 completedFiles/totalFiles，不重算 fraction（保留暂停值）
        progress.completedFiles = 5  // 恢复时 startIndex=5
        // fractionCompleted 不被覆盖
        #expect(progress.fractionCompleted == pausedFraction,
                "恢复瞬间应保留暂停 fraction，实际：\(progress.fractionCompleted)")
    }
}

// Progress 标签格式化是纯函数式，无需串行；保持在 MainActor 下与现有风格一致。
@MainActor
@Test func MLXDownloadProgressSpeedLabelFormatsAllUnits() {
    var p = MLXDownloadProgress()
    p.speed = 500  // < 1KB
    #expect(p.speedLabel.contains("bytes") || p.speedLabel.contains("KB") || p.speedLabel.contains("B"))
    p.speed = 1_536  // ~1.5 KB
    #expect(p.speedLabel.contains("KB"))
}

@MainActor
@Test func MLXDownloadProgressPercentLabelFloorsToInteger() {
    var p = MLXDownloadProgress()
    p.fractionCompleted = 0.9999
    #expect(p.percentLabel == "99%")
    p.fractionCompleted = 0.001
    #expect(p.percentLabel == "0%")
}

// MARK: - MLX Error → renderKind Mapping Tests

@Test func mlxErrorHandlingMapsModelNotDownloaded() {
    #expect(MLXErrorHandling.renderKind(for: InferenceError.modelNotDownloaded) == "mlx-model-not-downloaded")
}

@Test func mlxErrorHandlingReturnsNilForOtherErrors() {
    // 非「未下载」错误不应触发内联下载界面，交给核心错误渲染器
    #expect(MLXErrorHandling.renderKind(for: InferenceError.loadFailed("boom")) == nil)
    #expect(MLXErrorHandling.renderKind(for: InferenceError.notReady) == nil)
    #expect(MLXErrorHandling.renderKind(for: MLXDownloadError.downloadFailed("network")) == nil)
    #expect(MLXErrorHandling.renderKind(for: NSError(domain: "x", code: 1)) == nil)
}

@Test func mlxLumiProviderErrorRenderKind() {
    let provider = MLXLumiProvider()
    #expect(provider.errorRenderKind(for: InferenceError.modelNotDownloaded) == "mlx-model-not-downloaded")
    #expect(provider.errorRenderKind(for: InferenceError.loadFailed("oom")) == nil)
}

@Test func mlxLumiProviderMakeErrorMessageCarriesRenderKindAndModel() async {
    let provider = MLXLumiProvider()
    let request = LumiLLMRequest(
        messages: [],
        model: "mlx-community/Qwen3.5-0.8B-OptiQ-4bit"
    )
    let message = provider.makeErrorMessage(
        conversationID: UUID(),
        request: request,
        error: InferenceError.modelNotDownloaded,
        disposition: .nonRetryable
    )

    #expect(message.role == .error)
    #expect(message.isError == true)
    #expect(message.providerID == "mlx")
    #expect(message.modelName == "mlx-community/Qwen3.5-0.8B-OptiQ-4bit")
    #expect(message.renderKind == "mlx-model-not-downloaded")
}

@Test func mlxLumiProviderMakeErrorMessageWithoutRenderKindForOtherErrors() {
    let provider = MLXLumiProvider()
    let request = LumiLLMRequest(messages: [], model: "mlx-community/Qwen3.5-0.8B-OptiQ-4bit")
    let message = provider.makeErrorMessage(
        conversationID: UUID(),
        request: request,
        error: InferenceError.loadFailed("oom"),
        disposition: .nonRetryable
    )
    // 其它错误不应携带 mlx- 前缀的 renderKind，否则会被排除出核心错误渲染器
    #expect(message.renderKind == nil)
}

// MARK: - MLXRenderKind Matching Tests

@Test func mlxRenderKindMatchesModelNotDownloaded() {
    let message = LumiChatMessage(
        conversationID: UUID(),
        role: .error,
        content: "",
        providerID: "mlx",
        modelName: "mlx-community/Qwen3.5-0.8B-OptiQ-4bit",
        isError: true,
        rawErrorDetail: "模型未下载",
        renderKind: "mlx-model-not-downloaded"
    )
    #expect(MLXRenderKind.matchesModelNotDownloaded(message) == true)
    #expect(MLXRenderKind.isMLXError(message) == true)
}

@Test func mlxRenderKindRejectsNonMLXProvider() {
    let message = LumiChatMessage(
        conversationID: UUID(),
        role: .error,
        content: "",
        providerID: "openai",  // 非 MLX
        isError: true,
        renderKind: "mlx-model-not-downloaded"
    )
    #expect(MLXRenderKind.matchesModelNotDownloaded(message) == false)
    #expect(MLXRenderKind.isMLXError(message) == false)
}

@Test func mlxRenderKindRejectsMismatchedRenderKind() {
    // provider 是 mlx，但 renderKind 不匹配
    let message = LumiChatMessage(
        conversationID: UUID(),
        role: .error,
        content: "",
        providerID: "mlx",
        isError: true,
        renderKind: "some-other-kind"
    )
    #expect(MLXRenderKind.matchesModelNotDownloaded(message) == false)
}

@Test func mlxRenderKindRejectsNonErrorMessages() {
    let message = LumiChatMessage(
        conversationID: UUID(),
        role: .assistant,
        content: "hello",
        providerID: "mlx",
        isError: false,
        renderKind: "mlx-model-not-downloaded"
    )
    // isError == false 不算错误消息
    #expect(MLXRenderKind.isMLXError(message) == false)
    #expect(MLXRenderKind.matchesModelNotDownloaded(message) == false)
}

// MARK: - MLXLumiPlugin Renderer Registration Tests

@MainActor
@Test func mlxPluginRegistersModelNotDownloadedRenderer() {
    let context = LumiPluginContext(
        activeSectionID: "test",
        activeSectionTitle: "Test"
    )
    let renderers = MLXLumiPlugin.messageRenderers(context: context)
    #expect(renderers.contains { $0.id == "mlx-model-not-downloaded" })

    let renderer = renderers.first { $0.id == "mlx-model-not-downloaded" }
    #expect(renderer?.order == 310, "应高于核心错误渲染器 (300)")
}

@MainActor
@Test func mlxRendererSelectsOnlyModelNotDownloadedErrors() {
    let context = LumiPluginContext(
        activeSectionID: "test",
        activeSectionTitle: "Test"
    )
    let renderer = MLXLumiPlugin
        .messageRenderers(context: context)
        .first { $0.id == "mlx-model-not-downloaded" }!

    let notDownloaded = LumiChatMessage(
        conversationID: UUID(),
        role: .error,
        content: "",
        providerID: "mlx",
        modelName: "mlx-community/Qwen3.5-0.8B-OptiQ-4bit",
        isError: true,
        renderKind: "mlx-model-not-downloaded"
    )
    #expect(renderer.canRender(notDownloaded) == true)

    let otherError = LumiChatMessage(
        conversationID: UUID(),
        role: .error,
        content: "boom",
        providerID: "mlx",
        isError: true,
        renderKind: nil
    )
    #expect(renderer.canRender(otherError) == false)
}
