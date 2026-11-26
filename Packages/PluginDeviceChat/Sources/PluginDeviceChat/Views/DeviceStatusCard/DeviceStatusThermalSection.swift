import LumiUI
import PluginDevice
import SwiftUI

/// 温度 / 热压力明细区块。
///
/// 有传感器读数时展示各传感器温度与峰值；否则退化为系统热压力等级。
struct DeviceStatusThermalSection: View {
    @LumiTheme private var theme

    let thermal: DeviceThermalStatus?

    var body: some View {
        if let thermal {
            if !thermal.readings.isEmpty {
                temperatureContent(thermal)
            } else {
                pressureContent(thermal)
            }
        } else {
            Text("--")
                .font(.caption)
                .foregroundStyle(theme.textTertiary)
        }
    }

    // MARK: - Temperature

    private func temperatureContent(_ thermal: DeviceThermalStatus) -> some View {
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
    }

    private func readingRow(_ reading: DeviceThermalReading) -> some View {
        HStack(spacing: 8) {
            Text(label(for: reading))
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
                .frame(width: 88, alignment: .leading)

            ProgressView(value: min(max(reading.celsius, 0), 120), total: 120)
                .tint(MetricStatus.temperature(reading.celsius).color(in: theme))
                .controlSize(.mini)

            Text(String(format: "%.1f°C", reading.celsius))
                .font(.caption2)
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
                .frame(minWidth: 46, alignment: .trailing)
        }
    }

    // MARK: - Pressure

    private func pressureContent(_ thermal: DeviceThermalStatus) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title(for: thermal.state))
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(color(for: thermal.state))

                Text(pluginLocalization.string("Thermal Pressure"))
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)

                Spacer(minLength: 0)
            }

            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index <= level(for: thermal.state) ? color(for: thermal.state) : theme.divider)
                        .frame(height: 6)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(pluginLocalization.string("Thermal Pressure")): \(title(for: thermal.state))")
    }

    // MARK: - Helpers

    /// 传感器标签：优先用类别，缺失时退回序号。
    private func label(for reading: DeviceThermalReading) -> String {
        guard let kind = reading.kind, !kind.isEmpty else {
            return pluginLocalization.string("Sensor") + " \(reading.index)"
        }
        return kind.capitalized
    }

    private func title(for state: DeviceThermalState) -> String {
        switch state {
        case .nominal: return pluginLocalization.string("Normal")
        case .fair: return pluginLocalization.string("Warm")
        case .serious: return pluginLocalization.string("Serious")
        case .critical: return pluginLocalization.string("Critical")
        }
    }

    private func color(for state: DeviceThermalState) -> Color {
        switch state {
        case .nominal: return theme.success
        case .fair: return theme.warning
        case .serious, .critical: return theme.error
        }
    }

    private func level(for state: DeviceThermalState) -> Int {
        switch state {
        case .nominal: return 0
        case .fair: return 1
        case .serious: return 2
        case .critical: return 3
        }
    }
}
