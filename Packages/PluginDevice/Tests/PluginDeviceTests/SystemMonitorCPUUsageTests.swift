import Foundation
import Testing
@testable import PluginDevice

/// `SystemMonitorService.cpuUsage` 对 Mach buffer 长度的校验回归。
///
/// 旧实现按 `sysctl` 的 CPU 数量循环并直接下标 `host_processor_info`
/// 返回的 buffer；API 返回的 CPU 数量更少、历史 buffer 更短或指针为空时
/// 都会越界/强制解包崩溃。
struct SystemMonitorCPUUsageTests {
    private func usage(
        current: [integer_t],
        previous: [integer_t],
        cpuCount: Int,
        currentCount: Int? = nil,
        previousCount: Int? = nil
    ) -> Double {
        current.withUnsafeBufferPointer { currentBuffer in
            previous.withUnsafeBufferPointer { previousBuffer in
                SystemMonitorService.cpuUsage(
                    current: currentBuffer.baseAddress!,
                    currentCount: currentCount ?? current.count,
                    previous: previousBuffer.baseAddress!,
                    previousCount: previousCount ?? previous.count,
                    cpuCount: cpuCount
                )
            }
        }
    }

    @Test("两个 CPU 各半负载时返回平均使用率")
    func averageUsageAcrossCPUs() {
        let current: [integer_t] = [50, 0, 50, 0, 50, 0, 50, 0]
        let previous: [integer_t] = Array(repeating: 0, count: 8)
        #expect(abs(usage(current: current, previous: previous, cpuCount: 2) - 0.5) < 0.0001)
    }

    @Test("差分基于历史采样而不是绝对值")
    func usageIsDeltaBased() {
        let previous: [integer_t] = [10, 0, 90, 0, 0, 0, 100, 0]
        let current: [integer_t] = [60, 0, 140, 0, 20, 0, 180, 0]
        // CPU0: 用户态 +50、空闲 +50 → 0.5；CPU1: +20 / +100 → 0.2
        #expect(abs(usage(current: current, previous: previous, cpuCount: 2) - 0.35) < 0.0001)
    }

    @Test("buffer 长度不足 CPU 数量所需时返回 0 且不越界")
    func shortBuffersReturnZero() {
        let current: [integer_t] = Array(repeating: 100, count: 8)
        let previous: [integer_t] = Array(repeating: 0, count: 8)
        // 2 个 CPU 需要 8 个状态值；声明需要更多时不能读取
        #expect(usage(current: current, previous: previous, cpuCount: 3) == 0)
        #expect(usage(current: current, previous: previous, cpuCount: 2, currentCount: 7) == 0)
        #expect(usage(current: current, previous: previous, cpuCount: 2, previousCount: 7) == 0)
    }

    @Test("CPU 数量为 0 时返回 0")
    func zeroCPUCountReturnsZero() {
        let current: [integer_t] = [100, 0, 100, 0]
        let previous: [integer_t] = [0, 0, 0, 0]
        #expect(usage(current: current, previous: previous, cpuCount: 0) == 0)
    }
}
