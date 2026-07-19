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
                    .foregroundColor(Color(hex: "98989E"))

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
                    color: Color(hex: "BF5AF2")
                )

                GPUMetricCard(
                    title: LumiPluginLocalization.string("Tiler", bundle: .module),
                    value: viewModel.tilerUtilizationString,
                    color: Color(hex: "FF9F0A")
                )

                GPUMetricCard(
                    title: LumiPluginLocalization.string("Temperature", bundle: .module),
                    value: viewModel.temperatureString,
                    color: viewModel.temperatureColor
                )

                GPUMetricCard(
                    title: LumiPluginLocalization.string("Model", bundle: .module),
                    value: viewModel.modelName,
                    color: Color(hex: "98989E")
                )
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
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
                .foregroundColor(Color(hex: "98989E"))

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "98989E"))
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Color Extension

extension GPUManagerViewModel {
    var temperatureColor: Color {
        guard gpuService.temperature > 0 else { return Color(hex: "98989E") }
        if gpuService.temperature < 60 { return .green }
        if gpuService.temperature < 80 { return .orange }
        return .red
    }
}
