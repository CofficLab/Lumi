import SwiftUI
import MagicKit

/// 网络管理插件的状态栏弹窗视图
struct NetworkStatusBarPopupView: View {
    // MARK: - Properties

    @StateObject private var viewModel = NetworkManagerViewModel()
    @State private var isHovering = false
    @State private var hideWorkItem: DispatchWorkItem?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            // 标题栏
            headerView

            // 实时速度显示
            liveSpeedView
                .background(Color.clear) // Ensure hit testing works
                .onHover { hovering in
                    updateHoverState(hovering: hovering)
                }
                .popover(isPresented: $isHovering, arrowEdge: .leading) {
                    NetworkHistoryDetailView()
                        .onHover { hovering in
                            updateHoverState(hovering: hovering)
                        }
                }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "network")
                .font(.system(size: 14))
                .foregroundColor(.blue)

            Text("网络监控")
                .font(.system(size: 13, weight: .semibold))

            Spacer()
        }
        .padding(.horizontal)
    }

    // MARK: - Live Speed View

    private var liveSpeedView: some View {
        HStack(spacing: 16) {
            // 下载速度
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("下载")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Text(SpeedFormatter.formatForStatusBar(viewModel.networkState.downloadSpeed))
                        .font(.system(size: 14, weight: .medium))
                }
            }

            Spacer()

            Divider()
                .frame(height: 24)

            Spacer()

            // 上传速度
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.red)

                VStack(alignment: .leading, spacing: 2) {
                    Text("上传")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Text(SpeedFormatter.formatForStatusBar(viewModel.networkState.uploadSpeed))
                        .font(.system(size: 14, weight: .medium))
                }
            }
        }
        .padding(10)
        .background(.background.opacity(0.5))
    }
    
    private func updateHoverState(hovering: Bool) {
        // Cancel any pending hide action
        hideWorkItem?.cancel()
        hideWorkItem = nil
        
        if hovering {
            // If mouse enters either view, keep showing
            isHovering = true
        } else {
            // If mouse leaves, wait a bit before hiding
            // This gives time to move between the source view and the popover
            let workItem = DispatchWorkItem {
                isHovering = false
            }
            hideWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
        }
    }
}

// MARK: - Process Row View

struct ProcessRowView: View {
    let process: NetworkProcess

    var body: some View {
        HStack(spacing: 8) {
            // 进程图标
            if let icon = process.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "app")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            // 进程名称
            VStack(alignment: .leading, spacing: 2) {
                Text(process.name)
                    .font(.system(size: 11))
                    .lineLimit(1)

                Text("PID: \(process.id)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 速度
            HStack(spacing: 4) {
                // 下载
                if process.downloadSpeed > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.green)

                        Text(SpeedFormatter.formatForStatusBar(process.downloadSpeed))
                            .font(.system(size: 10))
                    }
                }

                // 上传
                if process.uploadSpeed > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.red)

                        Text(SpeedFormatter.formatForStatusBar(process.uploadSpeed))
                            .font(.system(size: 10))
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}

// MARK: - Preview

#Preview("Network Status Bar Popup") {
    NetworkStatusBarPopupView()
        .frame(width: 260)
}
