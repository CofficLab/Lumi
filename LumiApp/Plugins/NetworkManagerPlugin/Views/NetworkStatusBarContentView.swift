import SwiftUI
import Combine

/// Status bar content view for Network Manager plugin
/// Displays real-time upload/download speeds
struct NetworkStatusBarContentView: View {
    // MARK: - Properties

    @StateObject private var viewModel = NetworkManagerViewModel()

    // MARK: - Body

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            // Upload speed
            Text(SpeedFormatter.formatForStatusBar(viewModel.networkState.uploadSpeed))
                .font(.system(size: 9, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()

            // Download speed
            Text(SpeedFormatter.formatForStatusBar(viewModel.networkState.downloadSpeed))
                .font(.system(size: 9, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
        }
        .frame(width: 38)
    }
}

// MARK: - Preview

#Preview("Network Status Bar Content") {
    HStack(spacing: 4) {
        // Mock Logo
        Circle()
            .fill(AppUI.Color.semantic.info)
            .frame(width: 16, height: 16)

        // Network Speed Content
        NetworkStatusBarContentView()
    }
    .padding()
}
