import AppKit
import SwiftUI

/// Top N CPU 占用进程列表
///
/// 显示当前 CPU 占用最高的进程，每个进程展示图标、名称、CPU% 和进度条。
struct TopProcessesView: View {

    // MARK: - Properties

    let processes: [ProcessMetric]

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 10))
                    .foregroundColor(AppUI.Color.semantic.textTertiary)

                Text("Top Processes")
                    .font(.system(size: 10))
                    .foregroundColor(AppUI.Color.semantic.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)

            if processes.isEmpty {
                Text("Collecting...")
                    .font(.system(size: 10))
                    .foregroundColor(AppUI.Color.semantic.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 2) {
                    ForEach(processes) { process in
                        processRow(process)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .background(AppUI.Material.glass.opacity(0.3))
    }

    // MARK: - 私有方法

    private func processRow(_ process: ProcessMetric) -> some View {
        HStack(spacing: 8) {
            // 进程图标
            iconForProcess(process)
                .resizable()
                .frame(width: 16, height: 16)

            // 进程名
            Text(process.name)
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            // CPU%
            Text(String(format: "%.0f%%", process.cpuUsage))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(AppUI.Color.semantic.info)
                .frame(width: 36, alignment: .trailing)

            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppUI.Color.semantic.textTertiary.opacity(0.2))

                    Capsule()
                        .fill(AppUI.Color.semantic.info.opacity(0.7))
                        .frame(width: geometry.size.width * min(process.cpuUsage / 100.0, 1.0))
                }
            }
            .frame(width: 40, height: 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
    }

    private func iconForProcess(_ process: ProcessMetric) -> Image {
        if let path = process.icon, let nsImage = NSWorkspace.shared.icon(forFile: path) {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "terminal")
    }
}

// MARK: - 预览

#Preview("Top Processes") {
    TopProcessesView(processes: [
        ProcessMetric(id: 100, name: "Google Chrome", icon: nil, cpuUsage: 32, memoryUsage: 512_000_000),
        ProcessMetric(id: 101, name: "Xcode", icon: nil, cpuUsage: 18, memoryUsage: 1_200_000_000),
        ProcessMetric(id: 102, name: "WindowServer", icon: nil, cpuUsage: 8, memoryUsage: 300_000_000),
        ProcessMetric(id: 103, name: "mds_stores", icon: nil, cpuUsage: 5, memoryUsage: 200_000_000),
        ProcessMetric(id: 104, name: "Safari", icon: nil, cpuUsage: 3, memoryUsage: 450_000_000),
    ])
    .frame(width: 280)
    .padding()
}

#Preview("Empty") {
    TopProcessesView(processes: [])
        .frame(width: 280)
        .padding()
}
