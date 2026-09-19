import LumiUI
import SwiftUI
import KernelCore

public struct NetworkHistoryDetailView: View {
    @ObservedObject private var historyViewModel: NetworkHistoryViewModel
    @ObservedObject private var viewModel: NetworkManagerViewModel

    init(viewModel: NetworkManagerViewModel, historyViewModel: NetworkHistoryViewModel) {
        self.viewModel = viewModel
        self.historyViewModel = historyViewModel
    }

    init() { self.init(viewModel: NetworkManagerViewModel(), historyViewModel: NetworkHistoryViewModel()) }
    @State private var selectedRange: TimeRange = .hour1

    private var selectedRangeIndex: Binding<Int> {
        Binding(
            get: { TimeRange.allCases.firstIndex(of: selectedRange) ?? 0 },
            set: { selectedRange = TimeRange.allCases[$0] }
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header with Picker (History Trend)
            HStack {
                Text(LumiPluginLocalization.string("History Trend", bundle: .module))
                    .font(.appCaptionEmphasized)
                    .foregroundColor(.secondary)

                AppSegmentedControl(
                    TimeRange.allCases.map(\.localizedName),
                    selection: selectedRangeIndex,
                    maxWidth: .infinity
                )
            }
            .padding(12)

            // Graph
            NetworkHistoryGraphView(
                dataPoints: selectedRange == .hour1 ? historyViewModel.recentHistory : historyViewModel.longTermHistory,
                timeRange: selectedRange
            )
            .frame(height: 140)
            .background(Color.secondary.opacity(0.06))

            Divider()

            // Process Monitor
            ProcessNetworkListView(viewModel: viewModel)
        }
        .frame(minHeight: 600)
    }
}

#Preview("Network Status Bar Popup") {
    NetworkMenuBarPopupView()
        .frame(width: 400)
        .frame(height: 400)
}

#Preview {
    NetworkHistoryDetailView()
        .frame(width: 500, height: 700)
}
