import SwiftUI
import AppKit
import LumiUI

struct TopProcessesView: View {
    @LumiTheme private var theme

    // MARK: - Properties

    let processes: [ProcessMetric]

    private var displayProcesses: [DisplayProcessMetric] {
        let totalCPUUsage = processes.reduce(0.0) { $0 + max($1.cpuUsage, 0) }
        guard totalCPUUsage > 0 else {
            return processes.map { DisplayProcessMetric(process: $0, cpuShare: 0) }
        }

        let rawShares = processes.map { process in
            max(process.cpuUsage, 0) / totalCPUUsage * 100.0
        }
        var integerShares = rawShares.map { Int($0.rounded(.down)) }
        let remainder = max(0, 100 - integerShares.reduce(0, +))

        rawShares
            .enumerated()
            .sorted { lhs, rhs in
                let lhsFraction = lhs.element - floor(lhs.element)
                let rhsFraction = rhs.element - floor(rhs.element)
                return lhsFraction == rhsFraction ? lhs.offset < rhs.offset : lhsFraction > rhsFraction
            }
            .prefix(remainder)
            .forEach { integerShares[$0.offset] += 1 }

        return zip(processes, integerShares).map { process, cpuShare in
            DisplayProcessMetric(process: process, cpuShare: cpuShare)
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 10))
                    .foregroundColor(theme.textTertiary)

                Text(LumiPluginLocalization.string("Top Processes", bundle: .module))
                    .font(.system(size: 10))
                    .foregroundColor(theme.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)

            if processes.isEmpty {
                Text(LumiPluginLocalization.string("Collecting...", bundle: .module))
                    .font(.system(size: 10))
                    .foregroundColor(theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 2) {
                    ForEach(displayProcesses) { displayProcess in
                        processRow(displayProcess)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .background(theme.textTertiary.opacity(0.06))
    }

    // MARK: - 私有方法

    private func processRow(_ displayProcess: DisplayProcessMetric) -> some View {
        let process = displayProcess.process

        return HStack(spacing: 8) {
            // 进程图标
            iconForProcess(process)
                .resizable()
                .frame(width: 16, height: 16)

            // 进程名
            Text(process.name)
                .font(.system(size: 11))
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            // CPU%
            Text("\(displayProcess.cpuShare)%")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(theme.info)
                .frame(width: 36, alignment: .trailing)

            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.textTertiary.opacity(0.2))

                    Capsule()
                        .fill(theme.info.opacity(0.7))
                        .frame(width: geometry.size.width * min(Double(displayProcess.cpuShare) / 100.0, 1.0))
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

private struct DisplayProcessMetric: Identifiable {
    let process: ProcessMetric
    let cpuShare: Int

    var id: Int32 { process.id }
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
