import Foundation
import LumiUI
import SwiftUI

/// CPU / die 温度的展示模型。
@MainActor
final class ThermalViewModel: ObservableObject {

    // MARK: - Properties

    @Published private(set) var readings: [ThermalSensorReading] = []
    @Published private(set) var peakCelsius: Double?

    /// 该机器是否存在可读的温度传感器。
    ///
    /// Intel Mac 无 PMU 传感器,此时为 `false`,UI 应显示「不可用」
    /// 而不是把 0 当作有效温度。
    var isAvailable: Bool { !readings.isEmpty }

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    func apply(readings: [ThermalSensorReading], peak: Double?) {
        self.readings = readings
        peakCelsius = peak
    }

    // MARK: - Computed Properties

    /// 最高温度显示值(例:"65.1°C");无数据时为 `nil`。
    var peakString: String? {
        guard let peakCelsius else { return nil }
        return String(format: "%.1f°C", peakCelsius)
    }

    /// 按类别分组,便于 UI 分区展示。
    var groupedReadings: [(kind: ThermalSensorReading.SensorKind, values: [ThermalSensorReading])] {
        Dictionary(grouping: readings, by: \.kind)
            .compactMap { key, value in
                guard let kind = key else { return nil }
                return (kind, value.sorted { $0.index < $1.index })
            }
            .sorted { $0.kind.rawValue < $1.kind.rawValue }
    }

    /// 最高温度对应的状态色。
    var peakColor: Color {
        guard let peakCelsius else { return .secondary }
        return MetricStatus.temperature(peakCelsius).themeColor
    }
}
