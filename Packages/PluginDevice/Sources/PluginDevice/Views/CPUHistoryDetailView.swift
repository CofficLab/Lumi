import SwiftUI
import LumiUI

struct CPUHistoryDetailView: View {
    @ObservedObject private var viewModel: DeviceHistoryViewModel<CPUDataPoint>
    @State private var selectedRange: CPUTimeRange = .hour1

    init(viewModel: DeviceHistoryViewModel<CPUDataPoint>) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header with Picker
            HStack {
                Text(LumiPluginLocalization.string("CPU Load Trend", bundle: .module))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Picker(LumiPluginLocalization.string("Time Range", bundle: .module), selection: $selectedRange) {
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
        }
    }
}
