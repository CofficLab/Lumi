import Foundation
import Testing
@testable import KitReminder

/// 插件状态存储的落盘行为（Binary Plist，遵循 CofficLab 存储规范）。
@Suite("ReminderStateStore 落盘")
struct ReminderStateStoreTests {
    /// 创建临时目录，测试结束后清理。
    private func makeTemporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReminderStateStoreTests-\(UUID().uuidString)", isDirectory: true)
        return url
    }

    @Test("写入的整数值可读回")
    func storesAndReadsInteger() {
        let store = ReminderStateStore(directory: makeTemporaryDirectory())
        defer { try? FileManager.default.removeItem(at: storeDirectory(of: store)) }

        store.setInteger(42, forKey: "count")
        #expect(store.integer(forKey: "count") == 42)
    }

    @Test("不存在的键返回 nil")
    func missingKeyReturnsNil() {
        let store = ReminderStateStore(directory: makeTemporaryDirectory())

        #expect(store.integer(forKey: "missing") == nil)
    }

    @Test("removeValue 移除键")
    func removesValue() {
        let store = ReminderStateStore(directory: makeTemporaryDirectory())

        store.setInteger(1, forKey: "count")
        store.removeValue(forKey: "count")

        #expect(store.integer(forKey: "count") == nil)
    }

    @Test("状态写入 Binary Plist 文件")
    func writesBinaryPlistFile() {
        let directory = makeTemporaryDirectory()
        let store = ReminderStateStore(directory: directory)
        defer { try? FileManager.default.removeItem(at: directory) }

        store.setInteger(7, forKey: "count")

        let fileURL = directory.appendingPathComponent(ReminderStateStore.fileName)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        let data = try? Data(contentsOf: fileURL)
        let plist = data.flatMap {
            try? PropertyListSerialization.propertyList(from: $0, options: [], format: nil)
        }
        #expect(plist is [String: Any], "状态文件应为 Binary Plist 字典")
    }

    @Test("新实例可从磁盘读回旧值")
    func reloadsFromDisk() {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = ReminderStateStore(directory: directory)
        first.setInteger(99, forKey: "count")

        let reloaded = ReminderStateStore(directory: directory)

        #expect(reloaded.integer(forKey: "count") == 99, "重启后状态应保留")
    }

    @Test("内存模式不写文件但可读写")
    func inMemoryStoreWorks() {
        let store = ReminderStateStore.inMemory()

        store.setInteger(5, forKey: "count")

        #expect(store.integer(forKey: "count") == 5)
    }

    /// 从 store 反查其所在目录（测试清理用）。
    private func storeDirectory(of store: ReminderStateStore) -> URL {
        let fileURL = Mirror(reflecting: store).children
            .first { $0.label == "fileURL" }?.value as? URL
        return fileURL?.deletingLastPathComponent() ?? FileManager.default.temporaryDirectory
    }
}
