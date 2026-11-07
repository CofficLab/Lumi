import AppKit
import LumiUI
import SwiftUI

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
                    .foregroundColor(.secondary)

                Text(pluginLocalization.string("Top Processes"))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)

            if processes.isEmpty {
                Text(pluginLocalization.string("Collecting..."))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
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
        .background(Color.secondary.opacity(0.06))
    }

    // MARK: - 私有方法

    private func processRow(_ process: ProcessMetric) -> some View {
        ProcessMetricRow(process: process)
    }
}

/// 单条进程记录：图标 / 名称（含份数与本应用标注）/ CPU% / 迷你进度条。
///
/// 主弹窗只展示前 5 条，详情页复用同一行视图展示完整列表。
struct ProcessMetricRow: View {
    let process: ProcessMetric

    var body: some View {
        HStack(spacing: 8) {
            // 进程图标
            iconForProcess(process)
                .resizable()
                .frame(width: 16, height: 16)

            // 进程名 + 同名份数 + 本应用标注
            HStack(spacing: 4) {
                Text(process.name)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)

                if process.instanceCount > 1 {
                    Text("×\(process.instanceCount)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                        .fixedSize()
                }

                if process.isCurrentApp {
                    Text(pluginLocalization.string("This app"))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.secondary.opacity(0.12)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // CPU%：直接展示服务端算出的真实占用，不做前 N 名归一化。
            Text(process.formattedCPUUsage)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.blue)
                .frame(width: 40, alignment: .trailing)

            // 进度条：以单核 100% 为满格。
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))

                    Capsule()
                        .fill(Color.blue.opacity(0.7))
                        .frame(width: geometry.size.width * CGFloat(process.cpuBarFraction))
                }
            }
            .frame(width: 40, height: 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
    }

    private func iconForProcess(_ process: ProcessMetric) -> Image {
        if let path = process.icon {
            return Image(nsImage: NSWorkspace.shared.icon(forFile: path))
        }
        return Image(systemName: "terminal")
    }
}

// MARK: - 展示口径

extension ProcessMetric {
    /// 展示用 CPU 百分比。
    ///
    /// `ProcessService` 返回的 `cpuUsage` 已经是相对单核的真实占用
    /// （100% = 占满一个核心，多线程进程可超过 100%），直接展示即可；
    /// 不能按前 N 名进程重新归一化，否则数值会被系统性放大。
    var formattedCPUUsage: String {
        String(format: "%.0f%%", cpuUsage)
    }

    /// 进度条比例：单核 100% 为满格，超过 100% 的部分截断。
    var cpuBarFraction: Double {
        min(max(cpuUsage / 100.0, 0), 1)
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
