import Foundation
import Testing
@testable import KitTestSupport

@Suite("临时目录")
struct TemporaryDirectoryTests {

    @Test("创建后目录存在")
    func createsDirectory() throws {
        let directory = try TemporaryDirectory.make("kit-test-support")
        defer { directory.remove() }

        #expect(FileManager.default.fileExists(atPath: directory.url.path))
        #expect(FileManager.default.fileExists(
            atPath: directory.appending("sub").deletingLastPathComponent().path
        ))
    }

    @Test("每次创建得到互不相同的目录")
    func createsUniqueDirectories() throws {
        let first = try TemporaryDirectory.make("kit-test-support")
        defer { first.remove() }
        let second = try TemporaryDirectory.make("kit-test-support")
        defer { second.remove() }

        #expect(first.url != second.url)
    }

    @Test("清理后目录消失，重复清理不抛错")
    func removesDirectory() throws {
        let directory = try TemporaryDirectory.make("kit-test-support")

        directory.remove()
        #expect(FileManager.default.fileExists(atPath: directory.url.path) == false)

        // 幂等：重复清理应当安全，避免清理失败掩盖真正的断言失败。
        directory.remove()
    }
}

@Suite("隔离 UserDefaults")
struct IsolatedUserDefaultsTests {

    @Test("写入值可读回")
    func readsBackWrittenValue() {
        let isolated = IsolatedUserDefaults.make(prefix: "app-update")
        defer { isolated.reset() }

        isolated.set("preview", forKey: "channel")
        #expect(isolated.string(forKey: "channel") == "preview")
    }

    @Test("不影响 UserDefaults.standard")
    func doesNotTouchStandardDefaults() {
        let key = "com.coffic.lumi.test.isolation-probe"
        // - Important: 这里**只读** `UserDefaults.standard`，绝不写它。
        //   隔离实例用的是另一个 suite（物理上不同的 domain），写入不会传播到
        //   standard；所以这里无需任何「写回原值」的清理动作。
        let original = UserDefaults.standard.string(forKey: key)

        let isolated = IsolatedUserDefaults.make(prefix: "standard-probe")
        defer { isolated.reset() }
        isolated.set("isolated-value", forKey: key)

        #expect(UserDefaults.standard.string(forKey: key) == original)
        #expect(isolated.string(forKey: key) == "isolated-value")
    }

    @Test("不同实例之间互不可见")
    func isolatesBetweenInstances() {
        let key = "shared-key"
        let first = IsolatedUserDefaults.make(prefix: "instance-a")
        let second = IsolatedUserDefaults.make(prefix: "instance-b")
        defer {
            first.reset()
            second.reset()
        }

        first.set("value-a", forKey: key)

        #expect(first.string(forKey: key) == "value-a")
        #expect(second.string(forKey: key) == nil)
    }
}

@Suite("临时存储 Provider")
@MainActor
struct TemporaryStorageProviderTests {

    @Test("数据根落在临时目录且保持版本命名")
    func usesVersionedRootInsideTemporaryDirectory() throws {
        let storage = try TemporaryStorageProvider.make(prefix: "kit-test-support")
        defer { storage.cleanup() }

        #expect(storage.dataRootDirectory.lastPathComponent == "db_debug_v6")
        #expect(
            storage.dataRootDirectory.path.hasPrefix(FileManager.default.temporaryDirectory.path)
        )
        #expect(FileManager.default.fileExists(atPath: storage.dataRootDirectory.path))
    }

    @Test("插件目录与核心目录按需创建")
    func createsPluginAndCoreDirectories() throws {
        let storage = try TemporaryStorageProvider.make(prefix: "kit-test-support")
        defer { storage.cleanup() }

        let pluginDirectory = storage.pluginDataDirectory(for: "com.coffic.lumi.plugin.demo")
        let coreDirectory = storage.coreDataDirectory()

        #expect(FileManager.default.fileExists(atPath: pluginDirectory.path))
        #expect(pluginDirectory.lastPathComponent == "com.coffic.lumi.plugin.demo")
        #expect(FileManager.default.fileExists(atPath: coreDirectory.path))
        #expect(coreDirectory.lastPathComponent == "Core")
    }

    @Test("清理后整个临时根被删除")
    func cleanupRemovesEverything() throws {
        let storage = try TemporaryStorageProvider.make(prefix: "kit-test-support")
        let root = storage.dataRootDirectory
        _ = storage.pluginDataDirectory(for: "com.coffic.lumi.plugin.demo")

        storage.cleanup()

        #expect(FileManager.default.fileExists(atPath: root.path) == false)
    }
}