import LumiUI
import SwiftUI

// MARK: - Manual View

/// 端口管理使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct PortManagerManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Port Manager"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of the Port Manager: scanning local listening ports, filtering the list, and terminating processes."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("Toolbar: the search field and the Refresh button.")),
                .init(L("Port list: one card per listening port, showing the port number, process name, address, PID badge, and user, with a terminate button on the right.")),
                .init(L("When no listening ports are found, an empty state is shown in place of the list.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Open the Port Manager tab; the port list is scanned automatically.")),
                .init(L("Type in the search field to filter the list by port number, PID, or process name.")),
                .init(L("Click Refresh to rescan the ports at any time.")),
                .init(L("To terminate a process, click the button on the right of its card and confirm in the dialog.")),
            ])

            ManualSectionHeader(number: 4, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("Terminating a process may lose its unsaved data; check before confirming.")),
                .init(L("Only ports in the listening state are listed.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 12) {
                // ① 工具栏示意:搜索框 + 刷新按钮
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 8))
                            .foregroundStyle(theme.textSecondary)
                        lineMock(width: 88)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(theme.appDivider)
                    )

                    Spacer(minLength: 0)

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 8))
                            .foregroundStyle(theme.textSecondary)
                        lineMock(width: 30)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(theme.appDivider)
                    )
                }
                .overlay(alignment: .topLeading) { ManualFigureMarker(1).padding(-7) }

                // ② 端口卡片列表示意
                VStack(spacing: 6) {
                    portCardMock()
                    portCardMock()
                    portCardMock()
                }
                .overlay(alignment: .topLeading) { ManualFigureMarker(2).padding(-7) }

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, L("Toolbar"))
                    ManualFigureLegendItem(2, L("Port List"))
                }
            }
        }
    }

    // MARK: - 示意简笔元素

    /// 端口卡片示意:端口号 + 进程名,第二行地址 + PID 徽章 + 结束按钮。
    private func portCardMock() -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("8080")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.info)
                    lineMock(width: 52)
                }

                HStack(spacing: 6) {
                    lineMock(width: 66)
                    pidBadgeMock()
                    lineMock(width: 24)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(theme.error.opacity(0.8))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.appDivider)
        )
    }

    /// PID 徽章示意。
    private func pidBadgeMock() -> some View {
        Text(LumiPluginLocalization.string("PID 4013", bundle: .module))
            .font(.system(size: 7, design: .monospaced))
            .foregroundColor(theme.textSecondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.08))
            )
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
        PortManagerManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
