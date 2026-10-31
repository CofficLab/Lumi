import Foundation
import PluginDeviceThermalBridge

// MARK: - Thermal Sensor Reading

/// 单个温度传感器的瞬时读数。
public struct ThermalSensorReading: Identifiable, Equatable, Sendable {
    /// 传感器在 HID 服务数组中的下标,用作 `id`。
    ///
    /// - Note: 该下标在同一台机器的一次开机周期内稳定,但跨重启可能变化。
    ///   UI 侧不应把它当作持久标识(例如不要写进历史库主键)。
    public let index: Int

    /// 传感器类别。无法判定时为 `nil`。
    public let kind: SensorKind?

    /// 摄氏温度。
    public let celsius: Double

    public var id: Int { index }

    /// 传感器类别。
    public enum SensorKind: String, Sendable, CaseIterable {
        /// SoC 裸片温度(`tdie`)。
        case die
        /// 设备/模块温度(`tdev`).
        case device
        /// 表面温度(`TP0s` 等)。
        case surface
    }
}

// MARK: - Thermal Sensor Reader

/// 通过 `IOHIDEventSystemClient` 读取 PMU 温度传感器。
///
/// ## 为什么走 HID 而不是 SMC
///
/// 传统方案(``osx-cpu-temp``、`istats`)通过 `IOServiceOpen("AppleSMC")`
/// 读 SMC key。在 Apple Silicon 上这条路已死:SMC 驱动只服务 Apple 自己的客户端,
/// `IOConnectCallStructMethod` 返回 `kIOReturnNotPrivileged`(实测 -536870206),
/// 即便 root 也无解。CPU / die 温度因此改由固件以 HID 事件形式暴露,
/// 通过 `IOHIDEventSystemClient` 可在纯用户态免 sudo 读取。
///
/// 这正是 Stats.app 多年来使用的路径。底层调用集中在
/// ``ThermalSensorBridge``,Swift 侧只做类型转换与分类。
///
/// ## 能力边界
///
/// - ✅ CPU / die / 封装温度(`tdie`、`tdev`、surface)
/// - ❌ GPU 温度仍在 SMC 上,免特权条件下拿不到
/// - ❌ Intel Mac 无 PMU 传感器,始终返回空数组
public enum ThermalSensorReader {

    // MARK: - Public API

    /// 读取当前所有可用温度传感器。
    ///
    /// - Returns: 有效温度读数;不可用时返回空数组(Intel Mac、私有符号失效等)。
    public static func read() -> [ThermalSensorReading] {
        var collected: [(Int, Double)] = []
        // 预分配,实测 Apple Silicon 上约 38 个有效传感器。
        collected.reserveCapacity(48)

        withUnsafeMutablePointer(to: &collected) { pointer in
            let context = UnsafeMutableRawPointer(pointer)
            let callback: LumiThermalSensorCallback = {
                rawContext, index, celsius in
                let typed = rawContext.assumingMemoryBound(to: [(Int, Double)].self)
                typed.pointee.append((Int(index), celsius))
            }
            _ = LumiReadThermalSensors(context, callback)
        }

        return collected
            .map { ThermalSensorReading(index: $0.0, kind: kind(for: $0.0), celsius: $0.1) }
            .sorted { $0.index < $1.index }
    }

    /// 传感器是否可用。
    ///
    /// UI 依据它区分「该机器读不到温度」与「当前温度为 0」,避免静默失败。
    public static func isAvailable() -> Bool {
        !read().isEmpty
    }

    /// 最高温度读数。
    ///
    /// 对应 iStat Menus 的 "CPU die max",是判断热节流风险最直接的指标。
    public static func peak() -> ThermalSensorReading? {
        read().max { $0.celsius < $1.celsius }
    }

    /// 最高温度(℃);无数据时返回 `nil`。
    public static func peakCelsius() -> Double? {
        peak()?.celsius
    }

    // MARK: - Classification

    /// 由传感器下标推断类别。
    ///
    /// Apple 未公开该映射,这里按固件中观测到的排布做启发式分组,仅用于 UI 分组标题,
    /// 读数本身不依赖它。
    private static func kind(for index: Int) -> ThermalSensorReading.SensorKind? {
        switch index {
        case 0..<16: return .device
        case 16..<48: return .die
        default: return .surface
        }
    }
}
