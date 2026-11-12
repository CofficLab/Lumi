import LumiUI
import SwiftUI
import KernelCore

/// Menu bar popup view for Network Manager plugin
public struct NetworkMenuBarPopupView: View {
    // MARK: - Properties

    @ObservedObject private var viewModel: NetworkManagerViewModel
    @ObservedObject private var historyViewModel: NetworkHistoryViewModel

    init(viewModel: NetworkManagerViewModel, historyViewModel: NetworkHistoryViewModel) {
        self.viewModel = viewModel
        self.historyViewModel = historyViewModel
    }

    init() { self.init(viewModel: NetworkManagerViewModel(), historyViewModel: NetworkHistoryViewModel()) }

    // MARK: - Body

    public var body: some View {
        HoverableContainerView(detailView: NetworkHistoryDetailView(viewModel: viewModel, historyViewModel: historyViewModel)) {
            VStack(spacing: 0) {
                // Real-time speed display
                liveSpeedView

                Divider()

                // Top network processes (inline, same presentation as the CPU block)
                TopNetworkProcessesView(viewModel: viewModel)
            }
        }
    }

    // MARK: - Live Speed View

    private var liveSpeedView: some View {
        HStack(spacing: 16) {
            // Download speed
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.appMicro)
                    .foregroundColor(.green)

                Text(SpeedFormatter.formatForStatusBar(viewModel.networkState.downloadSpeed))
                    .font(.appBodyEmphasized)
                    .foregroundColor(.primary)
                    .frame(alignment: .leading)
            }
            .frame(alignment: .leading)

            Spacer()

            Divider()
                .frame(height: 24)

            Spacer()

            // Upload speed
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.appMicro)
                    .foregroundColor(.red)

                Text(SpeedFormatter.formatForStatusBar(viewModel.networkState.uploadSpeed))
                    .font(.appBodyEmphasized)
                    .foregroundColor(.primary)
                    .frame(alignment: .leading)
            }
            .frame(alignment: .leading)
        }
        .padding(10)
    }
}

// MARK: - Preview

#Preview("Network Status Bar Popup") {
    NetworkMenuBarPopupView()
        .frame(width: 400)
        .frame(height: 400)
}
