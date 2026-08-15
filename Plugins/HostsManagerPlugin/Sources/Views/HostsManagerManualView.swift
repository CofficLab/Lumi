import LumiUI
import SwiftUI

// MARK: - Manual View

/// Hosts 管理器使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct HostsManagerManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Hosts Manager"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of the Hosts Manager: adding, toggling, searching, and backing up hosts entries."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("Toolbar: a group picker, the 「Search Host」 field, the 「Add」 button, and a 「More」 menu with 「Refresh」, 「Export Backup...」, and 「Import Backup...」.")),
                .init(L("Entry list: entries grouped by group; each entry shows an enable toggle, its domains and comment, the IP address in monospaced text, and a trash button.")),
                .init(L("Add sheet: 「Add Host Entry」 with the 「IP Address」, 「Domain」, 「Comment」, and 「Group」 fields.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Open the Hosts Manager tab in the sidebar.")),
                .init(L("Click 「Add」; in the 「Add Host Entry」 sheet, fill in 「IP Address」 and 「Domain」, optionally 「Comment」 and 「Group」, then click 「Save」.")),
                .init(L("Use the toggle on an entry to enable or disable it without deleting it.")),
                .init(L("Type in 「Search Host」 or pick a group in the group picker to filter the list.")),
                .init(L("Choose 「Export Backup...」 from the 「More」 menu to save a backup, or 「Import Backup...」 to restore one.")),
                .init(L("Click the trash button on an entry to remove it.")),
            ])

            ManualSectionHeader(number: 4, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("Changes are written to the system hosts file and take effect in DNS resolution immediately.")),
                .init(L("Invalid IP addresses or domain names are rejected by validation and cannot be saved.")),
                .init(L("Disable critical entries with care; some system services may fail to resolve.")),
                .init(L("Export a backup before making large changes.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 12) {
                // ① 工具栏示意
                HStack(spacing: 6) {
                    pickerMock()
                    searchFieldMock()
                    Spacer(minLength: 0)
                    toolbarPill("plus")
                    toolbarPill("ellipsis")
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(theme.appDivider)
                )
                .overlay(alignment: .topLeading) { ManualFigureMarker(1).padding(-7) }

                // ② 条目列表示意
                VStack(alignment: .leading, spacing: 7) {
                    Text(L("Group"))
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                    entryRowMock()
                    entryRowMock()
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(theme.appDivider)
                )
                .overlay(alignment: .topLeading) { ManualFigureMarker(2).padding(-7) }

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, L("Toolbar"))
                    ManualFigureLegendItem(2, L("Entry list"))
                }
            }
        }
    }

    // MARK: - 示意简笔元素

    /// 条目行示意:开关 + 域名/备注 + 等宽 IP + 删除按钮。
    private func entryRowMock() -> some View {
        HStack(spacing: 8) {
            toggleMock(isOn: true)
            VStack(alignment: .leading, spacing: 3) {
                lineMock(width: 70)
                lineMock(width: 40)
            }
            Spacer(minLength: 0)
            Text("127.0.0.1")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(theme.textPrimary)
            Image(systemName: "trash")
                .font(.system(size: 9))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    /// 搜索框示意。
    private func searchFieldMock() -> some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 8))
                .foregroundStyle(theme.textSecondary)
            lineMock(width: 42)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(theme.appDivider)
        )
    }

    /// 选择器示意:下拉框形状。
    private func pickerMock() -> some View {
        HStack(spacing: 4) {
            lineMock(width: 26)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 6))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(theme.appDivider)
        )
    }

    /// 工具栏按钮示意。
    private func toolbarPill(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 9))
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(theme.appDivider)
            )
    }

    /// 开关示意。
    private func toggleMock(isOn: Bool) -> some View {
        Capsule()
            .fill(isOn ? theme.primary.opacity(0.75) : Color.primary.opacity(0.15))
            .frame(width: 24, height: 14)
            .overlay(alignment: .trailing) {
                Circle()
                    .fill(.white)
                    .frame(width: 10, height: 10)
                    .padding(2)
            }
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
        HostsManagerManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
