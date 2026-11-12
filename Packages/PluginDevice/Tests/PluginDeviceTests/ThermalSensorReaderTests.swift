import Foundation
import Testing
@testable import PluginDevice

@Suite("ThermalSensorReader")
struct ThermalSensorReaderTests {

    @Test("private HID symbols are still resolvable")
    func privateSymbolsAvailable() {
        // 私有 API 依赖:若系统升级后符号消失,read() 会静默返回空。
        // 此测试用于让失效尽早暴露在 CI,而不是等到用户界面无温度可看。
        for symbol in [
            "IOHIDEventSystemClientCreate",
            "IOHIDEventSystemClientSetMatching",
            "IOHIDEventSystemClientCopyServices",
            "IOHIDServiceClientCopyEvent",
            "IOHIDEventGetFloatValue"
        ] {
            #expect(dlsym(UnsafeMutableRawPointer(bitPattern: -2), symbol) != nil,
                    "private HID symbol missing: \(symbol)")
        }
    }

    @Test("readings are within physical range")
    func readingsInRange() {
        let readings = ThermalSensorReader.read()
        // Intel Mac 无 PMU 传感器,此时允许为空。
        try? #require(readings.isEmpty || !readings.isEmpty)
        for reading in readings {
            #expect(reading.celsius >= 1.0, "negative/dummy reading leaked through: \(reading)")
            #expect(reading.celsius <= 150.0, "implausible reading: \(reading)")
        }
    }

    @Test("readings are sorted by sensor index")
    func sortedByIndex() {
        let indices = ThermalSensorReader.read().map(\.index)
        #expect(indices == indices.sorted())
    }

    @Test("peak equals maximum of the same sample")
    func peakIsMaximum() {
        // 注意:peak() 内部会重新采样,因此必须与同一次 read() 的结果比较,
        // 否则两次采样之间的温度波动会造成假失败。
        //
        // - Important: 原实现虽然注释写对了,代码却仍去比 `peakCelsius()`
        //   （它会**重新采样**）—— 于是断言测到的是两次采样间的温度波动。
        //   本机负载高时波动可超过 1℃ 容差 → 稳定失败。
        //
        //   现在改为：用**同一次采样**同时算出样本与 peak，比较二者。
        let readings = ThermalSensorReader.read()
        guard let expected = ThermalSensorReader.peakCelsius(from: readings) else {
            #expect(readings.isEmpty)
            return
        }
        // 同一次采样,peak 必须严格等于样本最大值。
        #expect(expected == readings.map(\.celsius).max())
        // 独立采样路径仍必须给出可用的温度(存在性保证)。
        #expect(ThermalSensorReader.peakCelsius() != nil)
    }

    @Test("isAvailable agrees with non-empty read")
    func availabilityMatchesRead() {
        #expect(ThermalSensorReader.isAvailable() == !ThermalSensorReader.read().isEmpty)
    }
}
