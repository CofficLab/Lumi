import Foundation
@testable import LumiKernel
import Testing

/// `StorageProviding` 的内核契约测试。
///
/// 模块对应:`Sources/LumiKernel/Providers/StorageProviding.swift`。
/// 验证注册/解析 + 目录计算。
@Suite("StorageProviding")
@MainActor
struct StorageServiceTests {
    @Test("注册后可解析,plugin/core 目录按 id/固定名计算")
    func registerAndResolve() async throws {
        let kernel = KernelTestKit.makeKernel()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiTest", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storage = MockStorageProviding(dataRootDirectory: tempDir)
        try kernel.registerStorage(storage)

        let resolved = kernel.storage
        #expect(resolved != nil)
        #expect(resolved!.pluginDataDirectory(for: "test-plugin").path.contains("test-plugin"))
        #expect(resolved!.coreDataDirectory().path.contains("Core"))
    }
}
