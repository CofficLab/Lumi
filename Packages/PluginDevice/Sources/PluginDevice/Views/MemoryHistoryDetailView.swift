import SwiftUI
import LumiUI

struct MemoryHistoryDetailView: View {
    @ObservedObject private var viewModel: DeviceHistoryViewModel<MemoryDataPoint>
    @State private var selectedRange: MemoryTimeRange = .hour1

    init(viewModel: DeviceHistoryViewModel<MemoryDataPoint>) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(pluginLocalization.string("Memory Usage Trend"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Picker(pluginLocalization.string("Time Range"), selection: $selectedRange) {
                    ForEach(MemoryTimeRange.allCases) { range in
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
                MemoryHistoryGraphView(
                    dataPoints: selectedRange == .hour1 ? viewModel.recentHistory : viewModel.longTermHistory,
                    timeRange: selectedRange
                )
            }
            .background(Color.secondary.opacity(0.06))
            .frame(height: 180)
        }
    }
}
