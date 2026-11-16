import Foundation
import Testing

@testable import EditorKernel

/// 统计目录创建次数，作为「整份 plist 落盘次数」的代理指标：
/// `saveDict` 每次写盘前都会调用一次 `createDirectory`。
private final class CountingFileManager: FileManager, @unchecked Sendable {
    var createDirectoryCount = 0

    override func createDirectory(
        at url: URL,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey: Any]?
    ) throws {
        createDirectoryCount += 1
        try super.createDirectory(
            at: url,
            withIntermediateDirectories: createIntermediates,
            attributes: attributes
        )
    }
}

@Suite("EditorConfigFileStore 批量写入（issue #1250）")
struct EditorConfigFileStoreBatchTests {
    private func makeStore() throws -> (EditorConfigFileStore, CountingFileManager, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditorConfigFileStoreTests-\(UUID().uuidString)", isDirectory: true)
        let fileManager = CountingFileManager()
        let store = EditorConfigFileStore(settingsDirectoryURL: directory)
        return (store, fileManager, directory)
    }

    @Test("savingValues 合并多个键只落盘一次，且保留已有键")
    func savingValuesWritesOnceAndMerges() throws {
        let (store, fileManager, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        store.savingValue("seed", forKey: "existing", fileManager: fileManager)
        #expect(fileManager.createDirectoryCount == 1)

        store.savingValues([
            "fontSize": 15.0,
            "tabWidth": 2,
            "useSpaces": false,
        ], fileManager: fileManager)
        #expect(fileManager.createDirectoryCount == 2)

        let dict = store.loadDict(fileManager: fileManager)
        #expect(dict["existing"] as? String == "seed")
        #expect(dict["fontSize"] as? Double == 15.0)
        #expect(dict["tabWidth"] as? Int == 2)
        #expect(dict["useSpaces"] as? Bool == false)
    }

    @Test("逐键 savingValue 每次都整份落盘（旧行为的代价基线）")
    func sequentialSavingValueWritesPerKey() throws {
        let (store, fileManager, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        store.savingValue(15.0, forKey: "fontSize", fileManager: fileManager)
        store.savingValue(2, forKey: "tabWidth", fileManager: fileManager)
        store.savingValue(false, forKey: "useSpaces", fileManager: fileManager)
        #expect(fileManager.createDirectoryCount == 3)
    }

    @Test("空字典不触发写盘")
    func emptyValuesSkipWrite() throws {
        let (store, fileManager, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        store.savingValues([:], fileManager: fileManager)
        #expect(fileManager.createDirectoryCount == 0)
        #expect(!FileManager.default.fileExists(atPath: store.settingsFileURL().path))
    }
}