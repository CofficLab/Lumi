import Foundation
import ProviderIdleTime
import ProviderStorage
import Testing
@testable import FactoryLumi

/// IdleTime Provider 装配测试：验证 FactoryLumi 把完整服务装配进内核，
/// 而非占位内存桩。
@Suite("FactoryLumi IdleTime 装配")
@MainActor
struct FactoryLumiIdleTimeTests {

    private final class TestStorage: StorageProviding {
        let dataRootDirectory: URL

        init() {
            dataRootDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("FactoryLumiIdleTimeTests-\(UUID().uuidString)")
        }

        func pluginDataDirectory(for pluginID: String) -> URL {
            dataRootDirectory.appendingPathComponent(pluginID, isDirectory: true)
        }

        func coreDataDirectory() -> URL {
            dataRootDirectory.appendingPathComponent("Core", isDirectory: true)
        }
    }

    @Test("makeIdleTimeProvider 返回完整 IdleTimeService 并持久化到插件目录")
    func makeIdleTimeProviderReturnsFullService() async throws {
        let storage = TestStorage()
        defer { try? FileManager.default.removeItem(at: storage.dataRootDirectory) }

        let factory = DefaultProviderFactory()
        let provider = factory.makeIdleTimeProvider(storage: storage)

        // 必须是完整服务实现，而非占位内存桩。
        #expect(provider is IdleTimeService)
        #expect(!(provider is DefaultIdleTimeProviding))

        // 记录一次活动后，快照能反映最近活动时间（缓存链路生效）。
        // 存储为 ISO8601 秒级精度，事件从磁盘读回后亚秒被截断，按秒比较。
        let recordedAt = Date()
        await provider.record(.editorInput, at: recordedAt)
        let snapshot = await provider.currentSnapshot(for: recordedAt)
        #expect(snapshot.lastActivityAt != nil)
        #expect(snapshot.lastActivityAt?.timeIntervalSince1970.rounded(.down)
                == recordedAt.timeIntervalSince1970.rounded(.down))

        // 事件与快照已落盘到 Storage 提供的插件数据目录。
        let idleDirectory = storage.pluginDataDirectory(for: "IdleTime")
        #expect(FileManager.default.fileExists(
            atPath: idleDirectory.appendingPathComponent("activity.json").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: idleDirectory.appendingPathComponent("snapshot.json").path
        ))
    }
}
