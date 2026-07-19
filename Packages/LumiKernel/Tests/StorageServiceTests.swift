import Foundation
@testable import LumiKernel
import Testing

@Suite("Storage Service Tests")
@MainActor
struct StorageServiceTests {

    @Test("Storage service registration and usage")
    func testStorageService() async throws {
        // 1. 创建核心
        let kernel = LumiKernel()

        // 2. 准备测试数据目录
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiTest", isDirectory: true)

        // 3. 创建并注册存储服务
        let storage = StorageService(dataRootDirectory: tempDir)
        kernel.registerService(StorageProviding.self, storage)

        // 4. 验证服务可用
        let resolved = kernel.resolveService(StorageProviding.self)
        #expect(resolved != nil)

        // 5. 测试功能
        let pluginDir = resolved!.pluginDataDirectory(for: "test-plugin")
        #expect(pluginDir.path.contains("test-plugin"))

        let coreDir = resolved!.coreDataDirectory()
        #expect(coreDir.path.contains("Core"))

        // 6. 清理
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("Storage service via provider")
    func testStorageViaProvider() async throws {
        // 1. 创建核心
        let kernel = LumiKernel()

        // 2. 准备测试数据目录
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiTest", isDirectory: true)

        // 3. 创建服务提供者
        let provider = StorageServiceProvider(dataRootDirectory: tempDir)

        // 4. 通过 bootstrap 注入
        try await kernel.bootstrap(with: [provider])

        // 5. 验证服务可用
        #expect(kernel.storage != nil)

        // 6. 清理
        try? FileManager.default.removeItem(at: tempDir)
    }
}

// MARK: - Test Implementation

/// 测试用的存储服务实现
@MainActor
private final class StorageService: StorageProviding {
    public let dataRootDirectory: URL

    public init(dataRootDirectory: URL) {
        self.dataRootDirectory = dataRootDirectory
    }

    public func pluginDataDirectory(for pluginID: String) -> URL {
        dataRootDirectory.appendingPathComponent("Plugins/\(pluginID)")
    }

    public func coreDataDirectory() -> URL {
        dataRootDirectory.appendingPathComponent("Core")
    }
}

/// 测试用的存储服务提供者
@MainActor
private final class StorageServiceProvider: CoreServiceProvider {
    private let storageService: StorageService

    public init(dataRootDirectory: URL) {
        self.storageService = StorageService(dataRootDirectory: dataRootDirectory)
    }

    public var storage: (any StorageProviding)? {
        storageService
    }
}