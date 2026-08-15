import LumiUI
import SwiftUI

// MARK: - Manual View

/// 设备信息插件使用手册 —— 模拟纸质说明书的章节式文档：
/// 编号章节、编号步骤、条目列表与线框示意图。
///
/// 复刻自 Lumi DeviceInfoPlugin 的 DeviceInfoManualView，使用 LumiUI
/// 的 Manual 组件（Header / SectionHeader / BulletList / StepList / Figure）。
public struct DeviceInfoManualView: View {
    @LumiTheme private var theme

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ManualHeader(title: "设备信息", subtitle: "使用手册")

                ManualSectionHeader(number: 1, title: "概述")
                Text("本手册介绍设备信息的界面与基本操作：查看硬件状态与实时监控指标。")
                    .font(.appBody)
                    .foregroundColor(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                ManualSectionHeader(number: 2, title: "界面")
                ManualBulletList(items: [
                    .init("主内容面板：设备名称、macOS 版本、处理器与核心数。"),
                    .init("指标卡片：CPU、内存、磁盘、电池与运行时间。"),
                    .init("每 2 秒自动刷新实时数据。"),
                ])
                interfaceFigure

                ManualSectionHeader(number: 3, title: "基本操作")
                ManualStepList(items: [
                    .init("打开主窗口，查看内容区的设备信息面板。"),
                    .init("阅读头部系统信息：设备名、系统版本、处理器、核心数。"),
                    .init("查看各指标卡片：CPU 使用率、内存占用、磁盘空间、电池电量。"),
                    .init("数据每 2 秒自动更新，无需手动操作。"),
                ])

                ManualSectionHeader(number: 4, title: "说明")
                ManualBulletList(items: [
                    .init("所有数值均为实时快照，随系统报告自动刷新。"),
                    .init("无电池的 Mac 不显示电池指标。"),
                ])
            }
            .frame(maxWidth: 620, alignment: .leading)
            .padding(22)
        }
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: "图 1：界面布局") {
            VStack(spacing: 12) {
                VStack(spacing: 8) {
                    // ① 头部系统信息
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

                    // ② 指标卡片网格
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        statCardMock(label: "CPU", fraction: 0.35)
                        statCardMock(label: "内存", fraction: 0.6)
                        statCardMock(label: "磁盘", fraction: 0.5)
                        statCardMock(label: "电池", fraction: 0.8)
                        statCardMock(label: "运行时间", fraction: 0)
                    }
                    .overlay(alignment: .bottomTrailing) { ManualFigureMarker(2).padding(-7) }
                }

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, "系统信息")
                    ManualFigureLegendItem(2, "指标卡片")
                }
            }
        }
    }

    // MARK: - 示意简笔元素

    private var cardShape: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(theme.appDivider)
    }

    /// 指标卡片示意：标签 + 占用条。
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
}
