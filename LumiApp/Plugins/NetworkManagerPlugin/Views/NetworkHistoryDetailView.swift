import MagicKit
import SwiftUI

struct NetworkHistoryDetailView: View {
    @ObservedObject private var historyService = NetworkHistoryService.shared
    @StateObject private var viewModel = NetworkManagerViewModel()
    @State private var selectedRange: TimeRange = .hour1

    var body: some View {
        VStack(spacing: 0) {
            // Header with Picker (History Trend)
            HStack {
                Text(String(localized: "History Trend"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)

                Spacer()

                Picker("Time Range", selection: $selectedRange) {
                    ForEach(TimeRange.allCases) { range in
                        Text(range.localizedName).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.mini)
                .infiniteWidth()
            }
            .padding(12)

            // Graph
            NetworkHistoryGraphView(
                dataPoints: historyService.getData(for: selectedRange),
                timeRange: selectedRange
            )
            .frame(height: 140)
            .background(DesignTokens.Material.glass.opacity(0.5))
            .roundedMedium()
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

            GlassDivider()

            // Process Monitor
            ProcessNetworkListView(viewModel: viewModel)
        }
        .frame(minHeight: 600)
    }
}

#Preview("Network Status Bar Popup") {
    NetworkStatusBarPopupView()
        .frame(width: 400)
        .frame(height: 400)
}

#Preview {
    NetworkHistoryDetailView()
        .frame(width: 500, height: 700)
}
