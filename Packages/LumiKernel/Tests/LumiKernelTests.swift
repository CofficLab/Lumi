import Foundation
import Testing
@testable import LumiKernel

@Suite("LumiKernel Tests")
@MainActor
struct LumiKernelTests {

    @Test("Service registration and resolution")
    func testServiceRegistration() async throws {
        let kernel = LumiKernel()

        // 测试服务注册
        let storage = MockStorageService()
        kernel.registerService(StorageProviding.self, storage)

        // 测试服务解析
        let resolved = kernel.resolveService(StorageProviding.self)
        #expect(resolved != nil)
    }
}

// MARK: - Mock Services

/// Mock 存储服务实现
@MainActor
private final class MockStorageService: StorageProviding {
    var dataRootDirectory: URL {
        FileManager.default.temporaryDirectory
    }

    func pluginDataDirectory(for pluginID: String) -> URL {
        dataRootDirectory.appendingPathComponent("Plugins/\(pluginID)")
    }

    func coreDataDirectory() -> URL {
        dataRootDirectory.appendingPathComponent("Core")
    }
}