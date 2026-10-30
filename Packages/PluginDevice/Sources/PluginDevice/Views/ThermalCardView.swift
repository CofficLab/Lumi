import LumiUI
import SwiftUI

/// CPU / die 温度卡片,展示最高温度与全部传感器读数。
struct ThermalCardView: View {
    @LumiTheme private var theme

    @ObservedObject private var viewModel: ThermalViewModel

    init(viewModel: ThermalViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        MonitorCard(
            title: pluginLocalization.string("CPU Temperature"),
            value: viewModel.peakString ?? pluginLocalization.string("Unavailable"),
            color: viewModel.peakColor
        ) {
            content
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isAvailable {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.groupedReadings, id: \.kind) { group in
                        section(for: group.kind, values: group.values)
                    }
                }
                .padding(8)
            }
        } else {
            unavailableHint
        }
    }

    @ViewBuilder
    private func section(
        for kind: ThermalSensorReading.SensorKind,
        values: [ThermalSensorReading]
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title(for: kind))
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(theme.textSecondary)

            ForEach(values) { reading in
                HStack {
                    Text(String(format: "Sensor %d", reading.index))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(theme.textTertiary)
                    Spacer()
                    Text(String(format: "%.1f°C", reading.celsius))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(MetricStatus.temperature(reading.celsius).color(in: theme))
                }
            }
        }
    }

    private var unavailableHint: some View {
        VStack(spacing: 6) {
            Image(systemName: "thermometer.slash")
                .font(.system(size: 20))
                .foregroundColor(theme.textTertiary)
            Text(pluginLocalization.string("No temperature sensors available"))
                .font(.system(size: 10))
                .foregroundColor(theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func title(for kind: ThermalSensorReading.SensorKind) -> String {
        switch kind {
        case .die: return pluginLocalization.string("Die")
        case .device: return pluginLocalization.string("Device")
        case .surface: return pluginLocalization.string("Surface")
        }
    }
}
