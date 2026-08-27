import LumiUI
import SwiftUI

// MARK: - Manual View

/// 包管理使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct BrewManagerManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Package Management"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of the Package Management tool: viewing installed packages, updating packages, and searching for and installing packages."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("View picker: switches between the Installed, Updates, and Search tabs.")),
                .init(L("Installed tab: lists installed packages with their versions; casks are tagged, and each row provides Uninstall.")),
                .init(L("Updates tab: lists available updates, with Update All on top and Update on each row.")),
                .init(L("Search tab: search field and results; each result provides Install.")),
                .init(L("Toolbar: the Refresh button reloads the package list.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Open the Installed tab to view installed packages and their versions.")),
                .init(L("Open the Updates tab and click Update All, or update a single package with Update.")),
                .init(L("Open the Search tab, type a name, and click Install on a result.")),
                .init(L("To remove a package, click Uninstall on its row in the Installed tab and confirm.")),
            ])

            ManualSectionHeader(number: 4, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("Uninstalling a package may affect other packages that depend on it; review before proceeding.")),
                .init(L("Update packages before reporting issues; many problems are fixed in newer versions.")),
                .init(L("Click Refresh if a list looks out of date.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 12) {
                VStack(spacing: 10) {
                    // ① 视图切换
                    HStack(spacing: 0) {
                        Rectangle().fill(Color.primary.opacity(0.12)).frame(width: 44, height: 15)
                        Rectangle().fill(Color.clear).frame(width: 38, height: 15)
                        Rectangle().fill(Color.clear).frame(width: 38, height: 15)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(theme.appDivider)
                    )
                    .overlay(alignment: .top) { ManualFigureMarker(1).offset(y: -9) }

                    // ② 工具栏:刷新
                    HStack {
                        lineMock(width: 30)
                        Spacer(minLength: 0)
                        toolbarPill("arrow.clockwise")
                    }
                    .overlay(alignment: .trailing) { ManualFigureMarker(2).offset(x: 14) }

                    // ③ 软件包列表
                    VStack(alignment: .leading, spacing: 6) {
                        packageRowMock(tagged: true)
                        packageRowMock(tagged: false)
                        packageRowMock(tagged: false)
                    }
                    .overlay(alignment: .topLeading) { ManualFigureMarker(3).padding(-7) }
                }

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, L("View Picker"))
                    ManualFigureLegendItem(2, L("Toolbar"))
                    ManualFigureLegendItem(3, L("Package List"))
                }
            }
        }
    }

    // MARK: - 示意简笔元素

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

    /// 软件包行示意:文字线 + 标记 + 操作按钮。
    private func packageRowMock(tagged: Bool) -> some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 3) {
                lineMock(width: 56)
                lineMock(width: 28)
            }
            if tagged {
                Text(LumiPluginLocalization.string("cask", bundle: .module))
                    .font(.system(size: 7, weight: .semibold, design: .monospaced))
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().strokeBorder(theme.appDivider)
                    )
            }
            Spacer(minLength: 0)
            toolbarPill("trash")
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.04))
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
        BrewManagerManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
