import SwiftUI

struct NetworkDashboardView: View {
    @StateObject private var viewModel = NetworkManagerViewModel()

    var body: some View {
        VSplitView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Stats
                    HStack(spacing: 20) {
                        SpeedCard(
                            title: String(localized: "Download"),
                            speed: viewModel.networkState.downloadSpeed,
                            total: viewModel.networkState.totalDownload,
                            icon: "arrow.down.circle.fill",
                            color: DesignTokens.Color.semantic.success,
                            viewModel: viewModel
                        )

                        SpeedCard(
                            title: String(localized: "Upload"),
                            speed: viewModel.networkState.uploadSpeed,
                            total: viewModel.networkState.totalUpload,
                            icon: "arrow.up.circle.fill",
                            color: DesignTokens.Color.semantic.info,
                            viewModel: viewModel
                        )
                    }
                    .padding(.horizontal)

                    GlassDivider()

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
            .frame(minHeight: 200) // Limit overview area height
            
            GlassDivider()
            
            // Process monitor list
            ProcessNetworkListView(viewModel: viewModel)
        }
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
        MystiqueGlassCard(cornerRadius: DesignTokens.Radius.md, padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                    Text(title)
                        .font(DesignTokens.Typography.bodyEmphasized)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    Spacer()
                }

                Text(speed.formattedNetworkSpeed())
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Text(String(localized: "Total: \(Double(total).formattedBytes())"))
                    .font(DesignTokens.Typography.caption1)
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
            }
        }
        .mystiqueGlow(intensity: 0.2)
    }
}

struct NetworkInfoCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        MystiqueGlassCard(cornerRadius: DesignTokens.Radius.sm) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: icon)
                    .frame(width: 24, height: 24)
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(title)
                        .font(DesignTokens.Typography.caption1)
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    Text(value)
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                }
                Spacer()
            }
            .padding(DesignTokens.Spacing.sm)
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
