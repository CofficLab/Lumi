import SwiftUI
import LumiUI

struct CPUHistoryDetailView: View {
    @ObservedObject private var viewModel: DeviceHistoryViewModel<CPUDataPoint>
    @ObservedObject private var thermalViewModel: DeviceHistoryViewModel<ThermalDataPoint>
    @State private var selectedRange: CPUTimeRange = .hour1

    init(
        viewModel: DeviceHistoryViewModel<CPUDataPoint>,
        thermalViewModel: DeviceHistoryViewModel<ThermalDataPoint>
    ) {
        self.viewModel = viewModel
        self.thermalViewModel = thermalViewModel
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header with Picker
            HStack {
                Text(pluginLocalization.string("CPU Load Trend"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Picker(pluginLocalization.string("Time Range"), selection: $selectedRange) {
                    ForEach(CPUTimeRange.allCases) { range in
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

            // Graph
            VStack(spacing: 0) {
                CPUHistoryGraphView(
                    dataPoints: selectedRange == .hour1 ? viewModel.recentHistory : viewModel.longTermHistory,
                    timeRange: selectedRange
                )
            }
            .background(Color.secondary.opacity(0.06))
            .frame(height: 180)

            // CPU 温度趋势:与负载图共用时间范围,便于上下对照
            HStack {
                Text(pluginLocalization.string("CPU Temperature Trend"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.horizontal, 12)

            VStack(spacing: 0) {
                ThermalHistoryGraphView(
                    dataPoints: selectedRange == .hour1
                        ? thermalViewModel.recentHistory
                        : thermalViewModel.longTermHistory,
                    timeRange: selectedRange
                )
            }
            .background(Color.secondary.opacity(0.06))
            .frame(height: 180)
            .padding(.bottom, 12)
        }
    }
}
