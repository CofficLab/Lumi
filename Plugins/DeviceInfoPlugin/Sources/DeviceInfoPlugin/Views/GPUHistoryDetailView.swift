import LumiUI
import SwiftUI

struct GPUHistoryDetailView: View {
    @ObservedObject private var historyService = GPUHistoryService.shared
    @StateObject private var viewModel = GPUManagerViewModel()
    @State private var selectedRange: GPUTimeRange = .hour1

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(LumiPluginLocalization.string("GPU Usage Trend", bundle: .module))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

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

            VStack(spacing: 0) {
                GPUHistoryGraphView(
                    dataPoints: historyService.getData(for: selectedRange),
                    timeRange: selectedRange
                )
            }
            .background(Color.secondary.opacity(0.06))
            .frame(height: 180)

            // GPU detail metrics cards
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                GPUMetricCard(
                    title: LumiPluginLocalization.string("Utilization", bundle: .module),
                    value: viewModel.utilizationString,
                    color: statusColor(for: viewModel.utilization)
                )

                GPUMetricCard(
                    title: LumiPluginLocalization.string("Memory", bundle: .module),
                    value: viewModel.usedMemory,
                    subtitle: viewModel.totalMemory,
                    color: statusColor(for: viewModel.memoryUsagePercentage)
                )

                GPUMetricCard(
                    title: LumiPluginLocalization.string("Renderer", bundle: .module),
                    value: viewModel.rendererUtilizationString,
                    color: .blue
                )

                GPUMetricCard(
                    title: LumiPluginLocalization.string("Tiler", bundle: .module),
                    value: viewModel.tilerUtilizationString,
                    color: .orange
                )

                GPUMetricCard(
                    title: LumiPluginLocalization.string("Temperature", bundle: .module),
                    value: viewModel.temperatureString,
                    color: temperatureColor
                )

                GPUMetricCard(
                    title: LumiPluginLocalization.string("Model", bundle: .module),
                    value: viewModel.modelName,
                    color: .secondary
                )
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    private func statusColor(for value: Double) -> Color {
        if value < 60 { return .green }
        if value < 85 { return .orange }
        return .red
    }

    private var temperatureColor: Color {
        guard viewModel.gpuService.temperature > 0 else { return .secondary }
        if viewModel.gpuService.temperature < 60 { return .green }
        if viewModel.gpuService.temperature < 80 { return .orange }
        return .red
    }
}

// MARK: - Metric Card

private struct GPUMetricCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Color Extension
