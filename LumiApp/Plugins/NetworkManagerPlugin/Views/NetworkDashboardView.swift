import SwiftUI

struct NetworkDashboardView: View {
    @StateObject private var viewModel = NetworkManagerViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Stats
                    HStack(spacing: 20) {
                        SpeedCard(
                            title: String(localized: "Download"),
                            speed: viewModel.networkState.downloadSpeed,
                            total: viewModel.networkState.totalDownload,
                            icon: "arrow.down.circle.fill",
                            color: .green,
                            viewModel: viewModel
                        )

                        SpeedCard(
                            title: String(localized: "Upload"),
                            speed: viewModel.networkState.uploadSpeed,
                            total: viewModel.networkState.totalUpload,
                            icon: "arrow.up.circle.fill",
                            color: .blue,
                            viewModel: viewModel
                        )
                    }
                    .padding(.horizontal)

                    Divider()

                    // Info Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        NetworkInfoCard(title: String(localized: "Local IP"), value: viewModel.networkState.localIP ?? String(localized: "Unknown"), icon: "pc")
                        NetworkInfoCard(title: String(localized: "Public IP"), value: viewModel.networkState.publicIP ?? String(localized: "Fetching..."), icon: "globe")
                        NetworkInfoCard(title: String(localized: "Wi-Fi"), value: viewModel.networkState.wifiSSID ?? String(localized: "Not Connected"), icon: "wifi")
                        NetworkInfoCard(title: String(localized: "Signal"), value: "\(viewModel.networkState.wifiSignalStrength) dBm", icon: "antenna.radiowaves.left.and.right")
                        NetworkInfoCard(title: String(localized: "Latency (Ping)"), value: String(format: "%.1f ms", viewModel.networkState.ping), icon: "stopwatch")
                        NetworkInfoCard(title: String(localized: "Interface"), value: viewModel.networkState.interfaceName, icon: "cable.connector")
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .frame(minHeight: 200, maxHeight: 350) // Limit overview area height
            
            Divider()
            
            // Process monitor list
            ProcessNetworkListView(viewModel: viewModel)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .navigationTitle(NetworkManagerPlugin.displayName)
    }
}

struct SpeedCard: View {
    let title: String
    let speed: Double
    let total: UInt64
    let icon: String
    let color: Color
    let viewModel: NetworkManagerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(speed.formattedNetworkSpeed())
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)

            Text(String(localized: "Total: \(Double(total).formattedBytes())"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}

struct NetworkInfoCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
            }
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
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
