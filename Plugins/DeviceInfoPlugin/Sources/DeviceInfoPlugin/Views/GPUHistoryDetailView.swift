import LumiUI
import SwiftUI

struct GPUHistoryDetailView: View {
    @LumiTheme private var theme

    @ObservedObject private var historyService = GPUHistoryService.shared
    @StateObject private var viewModel = GPUManagerViewModel()
    @State private var selectedRange: GPUTimeRange = .hour1

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(LumiPluginLocalization.string("GPU Usage Trend", bundle: .module))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.textTertiary)

                Spacer()

                Picker(LumiPluginLocalization.string("Time Range", bundle: .module), selection: $selectedRange) {
                    ForEach(GPUTimeRange.allCases) { range in
                        Text(range.displayName).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.mini)
                .frame(width: 160)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            AppCard(cornerRadius: 0, padding: EdgeInsets(), showShadow: false) {
                GPUHistoryGraphView(
                    dataPoints: historyService.getData(for: selectedRange),
                    timeRange: selectedRange
                )
            }
            .frame(height: 180)

            // GPU detail metrics cards
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                GPUMetricCard(
                    title: LumiPluginLocalization.string("Utilization", bundle: .module),
                    value: viewModel.utilizationString,
                    color: viewModel.utilizationColor
                )

                GPUMetricCard(
                    title: LumiPluginLocalization.string("Memory", bundle: .module),
                    value: viewModel.usedMemory,
                    subtitle: viewModel.totalMemory,
                    color: viewModel.memoryColor
                )

                GPUMetricCard(
                    title: LumiPluginLocalization.string("Renderer", bundle: .module),
                    value: viewModel.rendererUtilizationString,
                    color: theme.info
                )

                GPUMetricCard(
                    title: LumiPluginLocalization.string("Tiler", bundle: .module),
                    value: viewModel.tilerUtilizationString,
                    color: theme.warning
                )

                GPUMetricCard(
                    title: LumiPluginLocalization.string("Temperature", bundle: .module),
                    value: viewModel.temperatureString,
                    color: viewModel.temperatureColor
                )

                GPUMetricCard(
                    title: LumiPluginLocalization.string("Model", bundle: .module),
                    value: viewModel.modelName,
                    color: theme.textTertiary
                )
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Metric Card

private struct GPUMetricCard: View {
    @LumiTheme private var theme

    let title: String
    let value: String
    var subtitle: String? = nil
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(theme.textTertiary)

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(theme.textTertiary)
            }
        }
        .padding(8)
        .background(theme.textTertiary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Color Extension

extension GPUManagerViewModel {
    var temperatureColor: Color {
        guard gpuService.temperature > 0 else { return currentTheme.textTertiary }
        return MetricStatus.gpuTemperature(gpuService.temperature).themeColor
    }
}
