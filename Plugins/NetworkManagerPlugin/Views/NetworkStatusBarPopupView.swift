import SwiftUI
import MagicKit

/// 网络管理插件的状态栏弹窗视图
struct NetworkStatusBarPopupView: View {
    // MARK: - Properties

    @StateObject private var viewModel = NetworkManagerViewModel()
    @State private var isExpanded = false
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

            // 进程列表
            if isExpanded {
                processListView
                    .transition(.opacity.combined(with: .slide))
            }
        }
        .padding(12)
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

            // 展开/收起按钮
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .buttonStyle(.plain)
        }
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

                    Text(formatSpeed(viewModel.networkState.downloadSpeed))
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

                    Text(formatSpeed(viewModel.networkState.uploadSpeed))
                        .font(.system(size: 14, weight: .medium))
                }
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    // MARK: - Process List View

    private var processListView: some View {
        VStack(spacing: 0) {
            if viewModel.filteredProcesses.isEmpty {
                Text("暂无活跃进程")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.filteredProcesses.prefix(5)) { process in
                    ProcessRowView(process: process)

                    if process.id != viewModel.filteredProcesses.prefix(5).last?.id {
                        Divider()
                            .padding(.horizontal, 8)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .memory
        let formatted = formatter.string(fromByteCount: Int64(bytesPerSecond))

        // 移除小数点后的字节，保留 KB/MB
        if formatted.contains("KB") || formatted.contains("MB") {
            return formatted.replacingOccurrences(of: " bytes", with: "")
        }

        return formatted
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

                        Text(formatSpeed(Int64(process.downloadSpeed)))
                            .font(.system(size: 10))
                    }
                }

                // 上传
                if process.uploadSpeed > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.red)

                        Text(formatSpeed(Int64(process.uploadSpeed)))
                            .font(.system(size: 10))
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func formatSpeed(_ bytesPerSecond: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .memory

        let formatted = formatter.string(fromByteCount: bytesPerSecond)

        // 简化显示：只显示数字和单位
        if formatted.contains("KB") {
            return formatted.replacingOccurrences(of: " KB", with: "K")
        } else if formatted.contains("MB") {
            return formatted.replacingOccurrences(of: " MB", with: "M")
        } else if formatted.contains("GB") {
            return formatted.replacingOccurrences(of: " GB", with: "G")
        } else if formatted.contains("bytes") {
            return formatted.replacingOccurrences(of: " bytes", with: "B")
        }

        return formatted
    }
}

// MARK: - Preview

#Preview("Network Status Bar Popup") {
    NetworkStatusBarPopupView()
        .frame(width: 260)
}
