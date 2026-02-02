import SwiftUI

struct NetworkStatusBarView: View {
    @ObservedObject var networkService = NetworkService.shared

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            speedText(formatSpeed(networkService.uploadSpeed))
            speedText(formatSpeed(networkService.downloadSpeed))
        }
    }

    private func speedText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .frame(minWidth: 52, alignment: .trailing)
    }

    private func formatSpeed(_ bytesPerSec: Double) -> String {
        let kb = bytesPerSec / 1024
        let mb = kb / 1024
        let gb = mb / 1024

        if gb >= 1.0 {
            return String(format: "%.1f GB/s", gb)
        } else if mb >= 1.0 {
            return String(format: "%.1f MB/s", mb)
        } else {
            return String(format: "%.0f KB/s", kb)
        }
    }
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .withNavigation(NetworkManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
