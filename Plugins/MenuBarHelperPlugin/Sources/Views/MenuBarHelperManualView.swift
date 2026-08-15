import LumiUI
import SwiftUI

// MARK: - Manual View

/// 菜单栏管理使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct MenuBarHelperManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Menu Bar Manager"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of the Menu Bar Manager: showing and hiding menu bar items."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("Permission card: until the Accessibility permission is granted, a 「Permission Required」 card is shown with a 「Grant Permission」 button.")),
                .init(L("Items card: 「Menu Bar Items」 lists the menu bar items, each with its icon, name, and an eye toggle; a 「Refresh」 button sits at the bottom.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Open the Menu Bar Manager tab in the sidebar.")),
                .init(L("Click 「Grant Permission」 and enable the app in System Settings when prompted.")),
                .init(L("Return to the tab; the menu bar items are listed under 「Menu Bar Items」.")),
                .init(L("Click the eye icon on a row to show or hide that item.")),
                .init(L("Click 「Refresh」 to reload the list.")),
            ])

            ManualSectionHeader(number: 4, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("Managing menu bar items requires the Accessibility permission.")),
                .init(L("Hidden system items may reappear after the Mac restarts.")),
                .init(L("Hidden items keep running; only their menu bar icons are hidden.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 12) {
                // ① 权限卡片示意
                VStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.textSecondary)
                    lineMock(width: 60)
                    lineMock(width: 86)
                    buttonMock()
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(theme.appDivider)
                )
                .overlay(alignment: .topLeading) { ManualFigureMarker(1).padding(-7) }

                // ② 条目列表示意
                VStack(alignment: .leading, spacing: 7) {
                    Text(L("Menu Bar Items"))
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                    itemRowMock(systemImage: "wifi", eyeOn: true)
                    itemRowMock(systemImage: "battery.75", eyeOn: false)
                    HStack(spacing: 5) {
                        Spacer(minLength: 0)
                        toolbarPill("arrow.clockwise")
                        Text(L("Refresh"))
                            .font(.system(size: 8))
                            .foregroundColor(theme.textSecondary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(theme.appDivider)
                )
                .overlay(alignment: .topLeading) { ManualFigureMarker(2).padding(-7) }

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, L("Permission card"))
                    ManualFigureLegendItem(2, L("Items card"))
                }
            }
        }
    }

    // MARK: - 示意简笔元素

    /// 条目行示意:图标 + 名称 + 眼睛开关。
    private func itemRowMock(systemImage: String, eyeOn: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 9))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 14, height: 14)
            lineMock(width: 56)
            Spacer(minLength: 0)
            Image(systemName: eyeOn ? "eye" : "eye.slash")
                .font(.system(size: 9))
                .foregroundStyle(eyeOn ? theme.primary : theme.textSecondary)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    /// 主操作按钮示意。
    private func buttonMock() -> some View {
        lineMock(width: 44)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(theme.primary.opacity(0.75))
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
        MenuBarHelperManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
