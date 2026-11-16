import Foundation
import Testing
@testable import PluginNetworkManager

/// 回归 #1212：NetworkHistoryService.configure 不得在主 actor 上同步解码 30 天历史，
/// 必须把目录创建 / 读取 / 解码 / 过滤放到后台，准备好后再回主 actor 发布；
/// 在途结果写回前必须做身份校验，旧目录 / 旧代次的加载不得覆盖重新配置后的新状态。
@MainActor
@Suite("NetworkHistoryService 后台配置与身份校验")
struct NetworkHistoryConfigureTests {
    private static func makeTempDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NetworkHistoryConfigure-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func writeHistory(_ points: [NetworkDataPoint], to directory: URL) throws {
        let url = directory.appendingPathComponent("history.json", isDirectory: false)
        let data = try JSONEncoder().encode(points)
        try data.write(to: url, options: .atomic)
    }

    private static func point(_ ageSeconds: TimeInterval, down: Double = 120, up: Double = 34) -> NetworkDataPoint {
        NetworkDataPoint(timestamp: Date().timeIntervalSince1970 - ageSeconds, downloadSpeed: down, uploadSpeed: up)
    }

    @Test("configure 立即返回，不在主 actor 同步解码，后台准备好后才发布历史")
    func configureReturnsBeforeDecodingAndPublishesInBackground() async throws {
        let directory = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = directory.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: storage, withIntermediateDirectories: true)
        let seeded = [Self.point(7200, down: 100, up: 10), Self.point(3600, down: 200, up: 20)]
        try Self.writeHistory(seeded, to: storage)

        let service = NetworkHistoryService(storageURL: nil, autoStartRecording: false)
        service.configure(storageDirectory: storage)

        // 关键：configure 同步返回后、尚未让出主 actor 时，历史必须仍为空，
        // 证明解码没有在主 actor 上同步发生（旧实现此处已被同步 loadHistory 填满）。
        #expect(service.longTermHistory.isEmpty)

        await service.waitForHistoryRestoreForTesting()

        #expect(service.longTermHistory.count == seeded.count)
        #expect(service.longTermHistory.map(\.downloadSpeed) == seeded.map(\.downloadSpeed))
        #expect(service.longTermHistory.map(\.uploadSpeed) == seeded.map(\.uploadSpeed))
        // 后台路径必须创建好存储目录。
        #expect(FileManager.default.fileExists(atPath: storage.path))
    }

    @Test("configure 后台加载遇到损坏文件必须隔离，且不得阻塞或抛出")
    func configureQuarantinesCorruptHistoryInBackground() async throws {
        let directory = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let historyURL = directory.appendingPathComponent("history.json", isDirectory: false)
        let corruptURL = directory.appendingPathComponent("history.corrupt.json", isDirectory: false)
        let invalidData = Data("not json".utf8)
        try invalidData.write(to: historyURL)

        let service = NetworkHistoryService(storageURL: nil, autoStartRecording: false)
        service.configure(storageDirectory: directory)
        #expect(service.longTermHistory.isEmpty)

        await service.waitForHistoryRestoreForTesting()

        #expect(service.longTermHistory.isEmpty)
        #expect((try? Data(contentsOf: corruptURL)) == invalidData)
        #expect(!FileManager.default.fileExists(atPath: historyURL.path))
    }

    @Test("重新配置后，旧代次 / 旧目录的在途加载晚到不得覆盖新状态")
    func staleInFlightPublishDoesNotOverwriteReconfiguredState() async throws {
        let dirA = try Self.makeTempDirectory()
        let dirB = try Self.makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: dirA)
            try? FileManager.default.removeItem(at: dirB)
        }
        let urlA = dirA.appendingPathComponent("history.json", isDirectory: false)
        let urlB = dirB.appendingPathComponent("history.json", isDirectory: false)
        let pointA = Self.point(7200, down: 111, up: 11)
        let pointB = Self.point(3600, down: 222, up: 22)
        try Self.writeHistory([pointA], to: dirA)
        try Self.writeHistory([pointB], to: dirB)

        let service = NetworkHistoryService(storageURL: nil, autoStartRecording: false)
        // 每次 configure 递增代次：第一次 gen=1，第二次 gen=2。
        service.configure(storageDirectory: dirA)
        await service.waitForHistoryRestoreForTesting()
        service.configure(storageDirectory: dirB)
        await service.waitForHistoryRestoreForTesting()
        #expect(service.longTermHistory.map(\.downloadSpeed) == [222])

        let stale = Self.point(1800, down: 999, up: 99)
        // 旧代次 + 旧目录（模拟 dirA 的在途加载晚到）。
        service.publishLoadedHistory([stale], url: urlA, generation: 1)
        #expect(service.longTermHistory.map(\.downloadSpeed) == [222])
        // 旧代次但目录匹配。
        service.publishLoadedHistory([stale], url: urlB, generation: 1)
        #expect(service.longTermHistory.map(\.downloadSpeed) == [222])
        // 当前代次但目录不匹配。
        service.publishLoadedHistory([stale], url: urlA, generation: 2)
        #expect(service.longTermHistory.map(\.downloadSpeed) == [222])
    }

    @Test("后台加载期间已录制的分钟点在发布时必须保留，不得被旧加载覆盖丢失")
    func publishPreservesPointsRecordedDuringInFlightLoad() async throws {
        let directory = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("history.json", isDirectory: false)

        let service = NetworkHistoryService(storageURL: nil, autoStartRecording: false)
        // 目录内暂无 history.json，后台加载返回 nil，longTermHistory 保持空。
        service.configure(storageDirectory: directory)
        await service.waitForHistoryRestoreForTesting()
        #expect(service.longTermHistory.isEmpty)

        // 模拟在途加载期间录制到的新分钟点。
        let recorded = Self.point(60, down: 300, up: 30)
        service.longTermHistory = [recorded]

        // 后台准备好的旧历史晚到发布。
        let loadedOld = Self.point(7200, down: 400, up: 40)
        service.publishLoadedHistory([loadedOld], url: url, generation: 1)

        // 合并后两者都在，且按时间先后排列（旧历史在前，新录制点在后）。
        #expect(service.longTermHistory.count == 2)
        #expect(service.longTermHistory.map(\.downloadSpeed) == [400, 300])
    }
}