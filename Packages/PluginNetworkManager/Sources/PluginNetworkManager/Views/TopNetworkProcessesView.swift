import LumiUI
import SwiftUI
import KernelCore

/// 主菜单栏弹窗网络区块内联展示的高占用网络进程。
///
/// 行样式与 CPU 区块的 `TopProcessesView` 对齐：16pt 图标、11pt 名称、
/// 单列速率数值和迷你进度条。数值为当前采样周期内的下载 + 上传速率，
/// 不是累计字节；进度条以榜首进程速率为满格。
public struct TopNetworkProcessesView: View {
    // MARK: - Properties

    @ObservedObject private var viewModel: NetworkManagerViewModel

    public init(viewModel: NetworkManagerViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    public var body: some View {
        let processes = viewModel.topNetworkProcesses
        let maxSpeed = processes.map(\.totalSpeed).max() ?? 0

        VStack(alignment: .leading, spacing: 0) {
            // 标题
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Text(pluginLocalization.string("Top Processes"))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)

            if processes.isEmpty {
                Text(pluginLocalization.string(viewModel.hasProcessSnapshot ? "No active processes" : "Collecting..."))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 2) {
                    ForEach(processes) { process in
                        processRow(process, maxSpeed: maxSpeed)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.06))
        .onAppear {
            DispatchQueue.main.async {
                viewModel.acquireProcessMonitor()
            }
        }
        .onDisappear {
            DispatchQueue.main.async {
                viewModel.releaseProcessMonitor()
            }
        }
    }

    // MARK: - 私有方法

    private func processRow(_ process: NetworkProcess, maxSpeed: Double) -> some View {
        HStack(spacing: 8) {
            // 进程图标
            iconForProcess(process)
                .resizable()
                .frame(width: 16, height: 16)

            // 进程名
            Text(process.name)
                .font(.system(size: 11))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 当前速率：按速率展示，单位随量级切换；已过滤零速率进程。
            Text(SpeedFormatter.formatForStatusBar(process.totalSpeed))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.blue)
                .lineLimit(1)
                .frame(width: 64, alignment: .trailing)

            // 进度条：以榜首进程速率为满格。
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))

                    Capsule()
                        .fill(Color.blue.opacity(0.7))
                        .frame(width: geometry.size.width * barFraction(for: process, maxSpeed: maxSpeed))
                }
            }
            .frame(width: 40, height: 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
    }

    private func iconForProcess(_ process: NetworkProcess) -> Image {
        if let icon = process.icon {
            return Image(nsImage: icon)
        }
        return Image(systemName: "gearshape")
    }

    private func barFraction(for process: NetworkProcess, maxSpeed: Double) -> CGFloat {
        guard maxSpeed > 0 else { return 0 }
        return CGFloat(min(max(process.totalSpeed / maxSpeed, 0), 1))
    }
}

// MARK: - 预览

#Preview("Top Network Processes") {
    TopNetworkProcessesView(viewModel: NetworkManagerViewModel())
        .frame(width: 280)
        .padding()
}
