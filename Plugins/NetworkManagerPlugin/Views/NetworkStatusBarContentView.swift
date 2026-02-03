import SwiftUI
import Combine
import OSLog

/// 网络管理插件的状态栏内容视图
/// 显示实时上传/下载速度
struct NetworkStatusBarContentView: View {
    // MARK: - Properties

    @StateObject private var viewModel = NetworkManagerViewModel()

    // MARK: - Body

    var body: some View {
        HStack(spacing: 2) {
            // 上传速度
            HStack(spacing: 1) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.red)
                Text(SpeedFormatter.formatForStatusBar(viewModel.networkState.uploadSpeed))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
            }

            // 下载速度
            HStack(spacing: 1) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.green)
                Text(SpeedFormatter.formatForStatusBar(viewModel.networkState.downloadSpeed))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .onAppear {
            os_log("📡 NetworkStatusBarContentView appeared - upload: \(viewModel.networkState.uploadSpeed), download: \(viewModel.networkState.downloadSpeed)")
        }
        .onChange(of: viewModel.networkState.uploadSpeed) { newValue in
            os_log("📡 Upload speed changed: \(newValue)")
        }
        .onChange(of: viewModel.networkState.downloadSpeed) { newValue in
            os_log("📡 Download speed changed: \(newValue)")
        }
    }
}

// MARK: - Preview

#Preview("Network Status Bar Content") {
    HStack(spacing: 4) {
        // 模拟 Logo
        Circle()
            .fill(Color.blue)
            .frame(width: 16, height: 16)

        // 网速内容
        NetworkStatusBarContentView()
    }
    .padding()
    .background(Color.black)
}
