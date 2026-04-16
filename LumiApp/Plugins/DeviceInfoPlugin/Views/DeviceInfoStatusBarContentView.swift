import SwiftUI
import Combine

/// Status bar content view for Device Info plugin
/// Displays real-time CPU usage percentage
struct DeviceInfoStatusBarContentView: View {
    // MARK: - Properties

    @StateObject private var viewModel = CPUManagerViewModel()

    // MARK: - Body

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(String(format: "%.0f%%", viewModel.cpuUsage))
                .font(.system(size: 9, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
                .foregroundColor(AppUI.Color.semantic.info)
        }
        .frame(width: 38)
    }
}

// MARK: - Preview

#Preview("Device Info Status Bar Content") {
    HStack(spacing: 4) {
        // Mock Logo
        Circle()
            .fill(AppUI.Color.semantic.info)
            .frame(width: 16, height: 16)

        // CPU Usage Content
        DeviceInfoStatusBarContentView()
    }
    .padding()
}
