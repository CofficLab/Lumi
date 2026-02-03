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
        VStack(alignment: .trailing, spacing: 0) {
            // 上传速度
            Text(SpeedFormatter.formatForStatusBar(viewModel.networkState.uploadSpeed))
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.primary)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()

            // 下载速度
            Text(SpeedFormatter.formatForStatusBar(viewModel.networkState.downloadSpeed))
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.primary)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
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
