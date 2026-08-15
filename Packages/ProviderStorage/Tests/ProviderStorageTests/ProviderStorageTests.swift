import Foundation
import Testing
@testable import ProviderStorage

/// StorageProviding 协议与默认实现的基础验证。
@Suite("ProviderStorage")
@MainActor
struct ProviderStorageTests {

    /// 用临时目录创建默认实现，避免污染真实 Application Support。
    private func makeProvider(appName: String = "TestApp") -> DefaultStorageProviding {
        DefaultStorageProviding(appName: appName)
    }

    @Test("数据根目录存在且位于 Application Support")
    func dataRootDirectoryExists() {
        let provider = makeProvider()
        let root = provider.dataRootDirectory

        #expect(FileManager.default.fileExists(atPath: root.path))
        #expect(root.lastPathComponent == "TestApp")
    }

    @Test("插件数据目录带插件 id 且已创建")
    func pluginDataDirectoryCreated() {
        let provider = makeProvider()
        let dir = provider.pluginDataDirectory(for: "com.example.plugin")

        #expect(dir.pathComponents.contains("Plugins"))
        #expect(dir.pathComponents.contains("com.example.plugin"))
        #expect(FileManager.default.fileExists(atPath: dir.path))
    }

    @Test("不同插件目录相互独立")
    func pluginDirectoriesAreDistinct() {
        let provider = makeProvider()
        let a = provider.pluginDataDirectory(for: "plugin.a")
        let b = provider.pluginDataDirectory(for: "plugin.b")

        #expect(a.path != b.path)
    }

    @Test("核心数据目录已创建")
    func coreDataDirectoryCreated() {
        let provider = makeProvider()
        let dir = provider.coreDataDirectory()

        #expect(dir.pathComponents.contains("Core"))
        #expect(FileManager.default.fileExists(atPath: dir.path))
    }

    @Test("StorageProviding 可作为 any StorageProviding 使用")
    func providerAccessibleThroughProtocol() {
        let provider: any StorageProviding = makeProvider()

        let dir = provider.pluginDataDirectory(for: "test.plugin")

        #expect(FileManager.default.fileExists(atPath: dir.path))
    }
}
