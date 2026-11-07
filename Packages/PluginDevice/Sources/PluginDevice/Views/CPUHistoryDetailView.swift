import SwiftUI
import LumiUI

struct CPUHistoryDetailView: View {
    @ObservedObject private var viewModel: DeviceHistoryViewModel<CPUDataPoint>
    @ObservedObject private var thermalViewModel: DeviceHistoryViewModel<ThermalDataPoint>
    @ObservedObject private var processViewModel: CPUManagerViewModel
    @State private var selectedRange: CPUTimeRange = .hour1

    init(
        viewModel: DeviceHistoryViewModel<CPUDataPoint>,
        thermalViewModel: DeviceHistoryViewModel<ThermalDataPoint>,
        processViewModel: CPUManagerViewModel
    ) {
        self.viewModel = viewModel
        self.thermalViewModel = thermalViewModel
        self.processViewModel = processViewModel
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
                    dataPoints: viewModel.data(for: selectedRange),
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
                    dataPoints: thermalViewModel.data(for: selectedRange),
                    timeRange: selectedRange
                )
            }
            .background(Color.secondary.opacity(0.06))
            .frame(height: 180)

            // 全部进程：主弹窗只展示前 5 条，这里给出完整列表。
            HStack {
                Text(pluginLocalization.string("All Processes"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(processViewModel.topProcesses.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)

            VStack(spacing: 0) {
                if processViewModel.topProcesses.isEmpty {
                    Text(pluginLocalization.string("Collecting..."))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(processViewModel.topProcesses) { metric in
                                ProcessMetricRow(process: metric)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .background(Color.secondary.opacity(0.06))
            .frame(height: 160)
            .padding(.bottom, 12)
        }
    }
}
