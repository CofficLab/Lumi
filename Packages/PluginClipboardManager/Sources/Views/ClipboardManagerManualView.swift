import LumiUI
import SwiftUI

// MARK: - Manual View

/// 剪贴板管理器使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct ClipboardManagerManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Clipboard"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of the Clipboard Manager: it records what you copy and lets you browse and reuse previous clipboard content."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("History list: shows copied items, newest first. When there are no records, it shows No clipboard records.")),
                .init(L("Item actions: each item provides Copy and Delete buttons.")),
                .init(L("Toolbar: the Clear History button removes all records at once.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Open the Clipboard tab in the sidebar.")),
                .init(L("Copy anything on your Mac; while monitoring is enabled, it is recorded in the list automatically.")),
                .init(L("Find the item you need and click Copy to put it back on the clipboard, then paste it where you want.")),
                .init(L("Click Delete to remove a single record, or Clear History in the toolbar to clear everything.")),
            ])

            ManualSectionHeader(number: 4, title: L("Settings"))
            ManualBulletList(items: [
                .init(L("Enable Clipboard Monitoring: turns automatic recording on or off.")),
                .init(L("History Size: limits how many items are kept — 100, 500, 1000, or Unlimited.")),
                .init(L("Clear All History: removes all stored records.")),
            ])

            ManualSectionHeader(number: 5, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("History is stored only on this device and is never uploaded.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 12) {
                VStack(spacing: 10) {
                    // ③ 工具栏:清除历史
                    HStack(spacing: 6) {
                        Text(L("Clipboard"))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                        Spacer(minLength: 0)
                        toolbarPill("trash")
                            .overlay(alignment: .top) { ManualFigureMarker(3).offset(y: -10) }
                    }

                    // ① 历史列表:② 条目操作
                    VStack(spacing: 6) {
                        historyRowMock(showsButtons: true)
                            .overlay(alignment: .topLeading) { ManualFigureMarker(1).padding(-7) }
                        historyRowMock(showsButtons: true)
                        historyRowMock(showsButtons: false)
                        historyRowMock(showsButtons: false)
                    }
                    .overlay(alignment: .bottomTrailing) { ManualFigureMarker(2).padding(-7) }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(theme.appDivider)
                )

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, L("History list"))
                    ManualFigureLegendItem(2, L("Item actions"))
                    ManualFigureLegendItem(3, L("Toolbar"))
                }
            }
        }
    }

    // MARK: - 示意简笔元素

    /// 历史条目示意:两根文字线 + 可选的「复制 / 删除」按钮。
    private func historyRowMock(showsButtons: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 9))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 3) {
                lineMock(width: 120)
                lineMock(width: 72)
            }

            Spacer(minLength: 0)

            if showsButtons {
                HStack(spacing: 4) {
                    miniPill(L("Copy"))
                    miniPill(L("Delete"))
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    /// 工具栏按钮示意。
    private func toolbarPill(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 9))
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(theme.appDivider)
            )
    }

    /// 条目上的小按钮示意。
    private func miniPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 7))
            .foregroundColor(theme.textSecondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(theme.appDivider)
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
        ClipboardManagerManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
