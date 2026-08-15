import LumiUI
import SwiftUI

// MARK: - Manual View

/// 应用管理器使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct AppManagerManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("App Manager"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of the App Manager: browsing installed applications, viewing app details, and uninstalling applications."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("Apps list: the left pane lists installed applications, with a search field and a Refresh button on top.")),
                .init(L("Detail pane: shows the selected application's information, related files, and cache, and provides the Uninstall Selected button.")),
                .init(L("Row actions: hover a row in the list to reveal Show in Finder and Open.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Open the Apps tab in the sidebar.")),
                .init(L("Use the search field to find an application, or scroll the list and click one to select it.")),
                .init(L("Review the application's information, related files, and cache in the detail pane.")),
                .init(L("Use Show in Finder to reveal the application in the Finder, or Open to launch it.")),
                .init(L("To remove an application, click Uninstall Selected and confirm in the dialog.")),
            ])

            ManualSectionHeader(number: 4, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("Uninstalling cannot be undone; confirm carefully before proceeding.")),
                .init(L("Removing related files also removes the application's data; review the list before uninstalling.")),
                .init(L("Click Refresh to rescan when the list looks out of date.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    // ① 应用列表:搜索 + 刷新 + 应用行
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 5) {
                            searchPillMock()
                            toolbarPill("arrow.clockwise")
                        }
                        appRowMock()
                        appRowMock()
                        appRowMock()
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .frame(width: 148, height: 168, alignment: .topLeading)
                    .overlay(alignment: .topLeading) { ManualFigureMarker(1).padding(-7) }

                    Divider()

                    // ② 详情面板:应用信息 + 相关文件行 + ③ 卸载按钮
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.primary.opacity(0.08))
                                .frame(width: 22, height: 22)
                            VStack(alignment: .leading, spacing: 3) {
                                lineMock(width: 64)
                                lineMock(width: 40)
                            }
                        }

                        lineMock(width: 110)
                        lineMock(width: 86)

                        fileRowMock()
                        fileRowMock()

                        Spacer(minLength: 0)

                        HStack {
                            Spacer(minLength: 0)
                            uninstallPillMock()
                        }
                        .overlay(alignment: .top) { ManualFigureMarker(3).offset(y: -9) }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .frame(height: 168)
                    .overlay(alignment: .topLeading) { ManualFigureMarker(2).padding(-7) }
                }

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, L("Apps List"))
                    ManualFigureLegendItem(2, L("App Details"))
                    ManualFigureLegendItem(3, L("Uninstall Button"))
                }
            }
        }
    }

    // MARK: - 示意简笔元素

    /// 搜索框示意。
    private func searchPillMock() -> some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 8))
                .foregroundStyle(theme.textSecondary)
            lineMock(width: 26)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(theme.appDivider)
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

    /// 应用行示意:圆角图标 + 名称两行。
    private func appRowMock() -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.primary.opacity(0.08))
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 3) {
                lineMock(width: 48)
                lineMock(width: 30)
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    /// 相关文件行示意。
    private func fileRowMock() -> some View {
        HStack(spacing: 6) {
            Image(systemName: "doc")
                .font(.system(size: 8))
                .foregroundStyle(theme.textSecondary)
            lineMock(width: 56)
            Spacer(minLength: 0)
            lineMock(width: 18)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    /// 卸载按钮示意。
    private func uninstallPillMock() -> some View {
        Text("⌫")
            .font(.system(size: 9))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.red.opacity(0.75))
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
        PluginAppManagerLocalization.string(key)
    }
}

#Preview {
    ScrollView {
        AppManagerManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
