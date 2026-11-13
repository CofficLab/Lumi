import LumiUI
import PluginDevice
import SwiftUI

/// 温度明细区块：各传感器读数与峰值。
struct DeviceStatusThermalSection: View {
    @LumiTheme private var theme

    let thermal: DeviceThermalStatus?

    var body: some View {
        if let thermal, !thermal.readings.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let peak = thermal.peakCelsius {
                        Text(String(format: "%.1f°C", peak))
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(theme.textPrimary)
                            .monospacedDigit()
                    }

                    Text(pluginLocalization.string("Peak Temperature"))
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)

                    Spacer(minLength: 0)
                }

                ForEach(thermal.readings, id: \.index) { reading in
                    readingRow(reading)
                }
            }
        } else {
            Text(pluginLocalization.string("No sensor readings available"))
                .font(.caption)
                .foregroundStyle(theme.textTertiary)
        }
    }

    // MARK: - Row

    private func readingRow(_ reading: DeviceThermalReading) -> some View {
        HStack(spacing: 8) {
            Text(label(for: reading))
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
                .frame(width: 88, alignment: .leading)

            ProgressView(value: min(max(reading.celsius, 0), 120), total: 120)
                .tint(statusColor(for: reading.celsius).color(in: theme))
                .controlSize(.mini)

            Text(String(format: "%.1f°C", reading.celsius))
                .font(.caption2)
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
                .frame(minWidth: 46, alignment: .trailing)
        }
    }

    // MARK: - Helpers

    /// 传感器标签：优先用类别，缺失时退回序号。
    private func label(for reading: DeviceThermalReading) -> String {
        guard let kind = reading.kind, !kind.isEmpty else {
            return pluginLocalization.string("Sensor") + " \(reading.index)"
        }
        return kind.capitalized
    }

    private func statusColor(for celsius: Double) -> MetricStatus {
        MetricStatus.temperature(celsius)
    }
}
