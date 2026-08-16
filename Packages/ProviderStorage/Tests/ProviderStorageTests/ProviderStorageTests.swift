import Foundation
import Testing
@testable import ProviderStorage

/// StorageProviding 协议与默认实现的基础验证。
///
/// 默认实现的磁盘布局必须与旧版 StoragePlugin 完全一致：
/// - 数据根目录：`~/Library/Application Support/<bundleID>/db_<debug|production>_v<majorVersion>/`
/// - 插件数据目录：`<root>/<pluginID>/`（无 `Plugins/` 中间层）
/// - 核心数据目录：`<root>/Core/`
@Suite("ProviderStorage")
@MainActor
struct ProviderStorageTests {

    /// 用临时目录创建默认实现，避免污染真实 Application Support。
    private func makeProvider() -> DefaultStorageProviding {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProviderStorageTests-\(UUID().uuidString)", isDirectory: true)
        return DefaultStorageProviding(dataRootDirectory: tempRoot)
    }

    @Test("数据根目录存在")
    func dataRootDirectoryExists() {
        let provider = makeProvider()
        let root = provider.dataRootDirectory

        #expect(FileManager.default.fileExists(atPath: root.path))
    }

    @Test("插件数据目录直接挂在根目录下，不带 Plugins 中间层（与旧版一致）")
    func pluginDataDirectoryCreated() {
        let provider = makeProvider()
        let dir = provider.pluginDataDirectory(for: "com.example.plugin")

        #expect(!dir.pathComponents.contains("Plugins"))
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

    // MARK: - 旧版命名规则

    @Test("数据根目录名遵循 db_<debug|production>_v<major> 规则")
    func dataRootDirectoryNaming() {
        #expect(DefaultStorageProviding.dataRootDirectoryName(debug: true, majorVersion: 5) == "db_debug_v5")
        #expect(DefaultStorageProviding.dataRootDirectoryName(debug: false, majorVersion: 5) == "db_production_v5")
        #expect(DefaultStorageProviding.dataRootDirectoryName(debug: false, majorVersion: 4) == "db_production_v4")
    }

    @Test("主版本号解析：取版本号第一段，无法解析回退 4")
    func majorVersionParsing() {
        #expect(DefaultStorageProviding.majorVersion(from: "5.3.1") == 5)
        #expect(DefaultStorageProviding.majorVersion(from: "6") == 6)
        #expect(DefaultStorageProviding.majorVersion(from: "abc") == 4)
        #expect(DefaultStorageProviding.majorVersion(from: "") == 4)
    }
}
