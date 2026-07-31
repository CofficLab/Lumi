import Foundation
import Testing
@testable import LumiKernel

/// 内核容器本身(LumiKernelContainer)的测试:服务注册表的注册/解析语义。
///
/// 模块对应:`Sources/LumiKernel/LumiKernel.swift` 的 Generic Service Registry。
/// 协议能力的注册/解析契约放在各 `Providers/*Tests`。
@Suite("Kernel Service Registry")
@MainActor
struct KernelServiceRegistryTests {
    @Test("服务注册后可通过同类型解析")
    func registerAndResolve() throws {
        let kernel = KernelTestKit.makeKernel()
        let storage = MockStorageProviding()

        try kernel.registerService(StorageProviding.self, storage)

        let resolved = kernel.resolveService(StorageProviding.self)
        #expect(resolved != nil)
        #expect(resolved as? MockStorageProviding === storage)
    }
}
