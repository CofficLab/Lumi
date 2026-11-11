import Foundation
import Testing
@testable import PluginDevice

/// 回归 #863：停止采样时丢失当前未完成分钟的统计历史。
///
/// 四个历史服务（CPU / GPU / 内存 / 温度）都把采样聚合成分钟级点，只有在
/// **下一分钟**的采样到来时才把上一分钟的聚合点写入长期历史。若采样在这之前
/// 停止，图表上已经显示出来的那个聚合点就不会落盘，重启后永久丢失。
///
/// 修复：停止时先把当前这一分钟的聚合点结算进长期历史，再保存。
@MainActor
@Suite("停止采样时的分钟级结算")
struct HistoryServiceStopSettlementTests {

    // MARK: - CPU

    @Test("CPU 停止时把当前分钟的聚合点写入长期历史")
    func cpuSettlesPendingMinuteOnStop() throws {
        let service = CPUHistoryService(storageFileURL: try isolatedURL("cpu"))

        service.recordDataPoint(usage: 40.0)
        service.recordDataPoint(usage: 60.0)

        // 停止前：长期历史为空，图表上靠当前聚合点补出实时点。
        #expect(service.longTermHistory.isEmpty)
        #expect(service.getData(for: .hour4).count == 1)

        service.stopRecording()

        #expect(service.longTermHistory.count == 1)
        #expect(service.longTermHistory.first?.usage == 50.0)
    }

    @Test("CPU 没有采样时停止不会写入空点")
    func cpuStopWithoutSamplesWritesNothing() throws {
        let service = CPUHistoryService(storageFileURL: try isolatedURL("cpu-empty"))

        service.stopRecording()

        #expect(service.longTermHistory.isEmpty)
    }

    @Test("CPU 停止后继续采样不会重复写入同一个点")
    func cpuStopThenResumeDoesNotDuplicate() throws {
        let service = CPUHistoryService(storageFileURL: try isolatedURL("cpu-resume"))

        service.recordDataPoint(usage: 40.0)
        service.stopRecording()
        #expect(service.longTermHistory.count == 1)

        // 结算之后累加器已清空，继续采样只会累积新的聚合，不会再写一次旧点。
        service.recordDataPoint(usage: 80.0)
        #expect(service.longTermHistory.count == 1)
    }

    // MARK: - GPU

    @Test("GPU 停止时把当前分钟的聚合点写入长期历史")
    func gpuSettlesPendingMinuteOnStop() throws {
        let service = GPUHistoryService(storageFileURL: try isolatedURL("gpu"))

        service.recordDataPoint(usage: 20.0)
        service.recordDataPoint(usage: 40.0)

        #expect(service.longTermHistory.isEmpty)

        service.stopRecording()

        #expect(service.longTermHistory.count == 1)
        #expect(service.longTermHistory.first?.usage == 30.0)
    }

    // MARK: - Memory

    @Test("内存停止时把当前分钟的聚合点写入长期历史")
    func memorySettlesPendingMinuteOnStop() throws {
        let service = MemoryHistoryService(storageFileURL: try isolatedURL("memory"))

        service.recordDataPoint(pct: 30.0, bytes: 3_000_000_000)
        service.recordDataPoint(pct: 50.0, bytes: 5_000_000_000)

        #expect(service.longTermHistory.isEmpty)

        service.stopRecording()

        #expect(service.longTermHistory.count == 1)
        #expect(service.longTermHistory.first?.usagePercentage == 40.0)
        #expect(service.longTermHistory.first?.usedBytes == 4_000_000_000)
    }

    // MARK: - Thermal

    @Test("温度停止时把当前分钟的聚合点写入长期历史")
    func thermalSettlesPendingMinuteOnStop() {
        let service = ThermalHistoryService()

        service.recordDataPoint(celsius: 40.0)
        service.recordDataPoint(celsius: 50.0)

        #expect(service.longTermHistory.isEmpty)

        service.stopRecording()

        #expect(service.longTermHistory.count == 1)
        #expect(service.longTermHistory.first?.celsius == 45.0)
    }

    @Test("温度停止后结算过的点不再重复出现")
    func thermalDoesNotDuplicateAfterSettlement() {
        let service = ThermalHistoryService()

        service.recordDataPoint(celsius: 40.0)
        service.stopRecording()
        service.stopRecording()

        #expect(service.longTermHistory.count == 1)
    }

    // MARK: - Helpers

    /// 造一个指向临时目录、尚不存在的历史文件路径。
    ///
    /// 服务在初始化时会把磁盘上的历史读进来，因此必须给一个隔离的空路径，
    /// 否则断言会被本机既有的历史数据污染。
    private func isolatedURL(_ name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("device-history-stop-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("history.json")
    }
}
