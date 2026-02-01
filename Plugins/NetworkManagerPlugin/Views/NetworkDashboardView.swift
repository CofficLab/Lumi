import SwiftUI

struct NetworkDashboardView: View {
    @StateObject private var viewModel = NetworkManagerViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Stats
                HStack(spacing: 20) {
                    SpeedCard(
                        title: "下载",
                        speed: viewModel.networkState.downloadSpeed,
                        total: viewModel.networkState.totalDownload,
                        icon: "arrow.down.circle.fill",
                        color: .green,
                        viewModel: viewModel
                    )
                    
                    SpeedCard(
                        title: "上传",
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
                    NetworkInfoCard(title: "内网 IP", value: viewModel.networkState.localIP ?? "未知", icon: "pc")
                    NetworkInfoCard(title: "公网 IP", value: viewModel.networkState.publicIP ?? "获取中...", icon: "globe")
                    NetworkInfoCard(title: "Wi-Fi", value: viewModel.networkState.wifiSSID ?? "未连接", icon: "wifi")
                    NetworkInfoCard(title: "信号强度", value: "\(viewModel.networkState.wifiSignalStrength) dBm", icon: "antenna.radiowaves.left.and.right")
                    NetworkInfoCard(title: "延迟 (Ping)", value: String(format: "%.1f ms", viewModel.networkState.ping), icon: "stopwatch")
                    NetworkInfoCard(title: "接口", value: viewModel.networkState.interfaceName, icon: "cable.connector")
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(nsColor: .controlBackgroundColor))
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
            
            Text(viewModel.formatSpeed(speed))
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
            
            Text("总计: \(viewModel.formatBytes(total))")
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
