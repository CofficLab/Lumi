import LumiUI
import SwiftUI

// MARK: - Manual View

/// 设备信息插件使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct DeviceInfoManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Device Info"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of Device Info: checking hardware status and reading the real-time monitor charts."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("Header card: shows the device name and the macOS version; the footer shows the uptime.")),
                .init(L("Card grid: CPU (name, cores, usage), Memory (used / total), Disk, Battery (level and cycles), and GPU.")),
                .init(L("Real-time Monitor: live charts for CPU, Memory, GPU temperature, Network, and Disk IO.")),
                .init(L("Menu bar: popups with CPU and memory graphs are always available.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Open the Device Info tab in the sidebar.")),
                .init(L("Read the header card for the device name and OS version, and the footer for the uptime.")),
                .init(L("Check each card: CPU usage and core count, the memory usage bar, disk space, battery level and cycles, and the GPU.")),
                .init(L("Scroll to the Real-time Monitor section to view the live charts.")),
            ])

            ManualSectionHeader(number: 4, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("All values are real-time snapshots and refresh as the system reports new data.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 卡片仪表盘

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 12) {
                VStack(spacing: 8) {
                    // ① 头部卡片:设备名称 + 系统版本
                    HStack(spacing: 8) {
                        Image(systemName: "laptopcomputer")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.textSecondary)
                        VStack(alignment: .leading, spacing: 3) {
                            lineMock(width: 64)
                            lineMock(width: 44)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(9)
                    .background(cardShape)
                    .overlay(alignment: .topLeading) { ManualFigureMarker(1).padding(-7) }

                    // ② 状态卡片网格
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        statCardMock(label: L("CPU"), fraction: 0.35)
                        statCardMock(label: L("Memory"), fraction: 0.6)
                        statCardMock(label: L("Disk"), fraction: 0.5)
                        statCardMock(label: L("Battery"), fraction: 0.8)
                        statCardMock(label: L("GPU"), fraction: 0.25)
                        statCardMock(label: L("Uptime"), fraction: 0)
                    }
                    .overlay(alignment: .bottomTrailing) { ManualFigureMarker(2).padding(-7) }
                }

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, L("Header card"))
                    ManualFigureLegendItem(2, L("Status cards"))
                }
            }
        }
    }

    // MARK: - 示意简笔元素

    private var cardShape: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(theme.appDivider)
    }

    /// 状态卡片示意:标签 + 占用条。
    private func statCardMock(label: String, fraction: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(theme.textSecondary)
            if fraction > 0 {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.primary.opacity(0.08))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.info.opacity(0.6))
                            .frame(width: proxy.size.width * fraction)
                    }
                }
                .frame(height: 4)
            } else {
                lineMock(width: 40)
            }
        }
        .padding(7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardShape)
    }

    /// 示意图中的占位文字线。
    private func lineMock(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.primary.opacity(0.14))
            .frame(width: width, height: 3)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}

#Preview {
    ScrollView {
        DeviceInfoManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
