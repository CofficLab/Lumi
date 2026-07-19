import SwiftUI
import LumiUI
import LumiKernel

public struct NetworkDashboardView: View {
    @ObservedObject private var viewModel = NetworkManagerViewModel.shared

    public var body: some View {
        VSplitView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Stats
                    HStack(spacing: 20) {
                        SpeedCard(
                            title: LumiPluginLocalization.string("Download", bundle: .module),
                            speed: viewModel.networkState.downloadSpeed,
                            total: viewModel.networkState.totalDownload,
                            icon: "arrow.down.circle.fill",
                            color: Color(hex: "30D158"),
                            viewModel: viewModel
                        )

                        SpeedCard(
                            title: LumiPluginLocalization.string("Upload", bundle: .module),
                            speed: viewModel.networkState.uploadSpeed,
                            total: viewModel.networkState.totalUpload,
                            icon: "arrow.up.circle.fill",
                            color: Color(hex: "0A84FF"),
                            viewModel: viewModel
                        )
                    }
                    .padding(.horizontal)

                    GlassDivider()

                    // Info Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        NetworkInfoCard(title: LumiPluginLocalization.string("Local IP", bundle: .module), value: viewModel.networkState.localIP ?? LumiPluginLocalization.string("Unknown", bundle: .module), icon: "pc")
                        NetworkInfoCard(title: LumiPluginLocalization.string("Public IP", bundle: .module), value: viewModel.networkState.publicIP ?? LumiPluginLocalization.string("Fetching...", bundle: .module), icon: "globe")
                        NetworkInfoCard(title: LumiPluginLocalization.string("Wi-Fi", bundle: .module), value: viewModel.networkState.wifiSSID ?? LumiPluginLocalization.string("Not Connected", bundle: .module), icon: "wifi")
                        NetworkInfoCard(title: LumiPluginLocalization.string("Signal", bundle: .module), value: "\(viewModel.networkState.wifiSignalStrength) dBm", icon: "antenna.radiowaves.left.and.right")
                        NetworkInfoCard(title: LumiPluginLocalization.string("Latency (Ping)", bundle: .module), value: String(format: "%.1f ms", viewModel.networkState.ping), icon: "stopwatch")
                        NetworkInfoCard(title: LumiPluginLocalization.string("Interface", bundle: .module), value: viewModel.networkState.interfaceName, icon: "cable.connector")
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
        .navigationTitle(NetworkManagerPlugin.info.displayName)
        .task {
            await viewModel.refreshPublicIPIfNeeded()
        }
    }
}

public struct SpeedCard: View {
    public let title: String
    public let speed: Double
    public let total: UInt64
    public let icon: String
    public let color: Color
    public let viewModel: NetworkManagerViewModel

    public var body: some View {
        AppCard(cornerRadius: 16, padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    Spacer()
                }

                Text(speed.formattedNetworkSpeed())
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                Text(LumiPluginLocalization.string("Total: \(Double(total).formattedBytes())", bundle: .module))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color(hex: "98989E"))
            }
        }
        .mystiqueGlow(intensity: 0.2)
    }
}

public struct NetworkInfoCard: View {
    public let title: String
    public let value: String
    public let icon: String

    public var body: some View {
        AppCard(cornerRadius: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 24, height: 24)
                    .foregroundColor(Color(hex: "98989E"))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(hex: "98989E"))
                    Text(value)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                }
                Spacer()
            }
            .padding(8)
        }
    }
}
