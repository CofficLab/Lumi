import LumiUI
import SwiftUI

// MARK: - Manual View

/// 右键使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct RClickManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Right Click"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of the Right Click plugin: enabling the Finder extension, switching right-click actions, and managing New File templates."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("Enable Finder Extension card: the Open System Settings button for enabling the extension.")),
                .init(L("General Actions card: a switch for each right-click action.")),
                .init(L("New File Menu card: the 'New File' submenu switch, the Add Template button, and the template list with a switch and a delete button on each row.")),
                .init(L("Reset card: restores the default configuration.")),
                .init(L("Preview tab in the rail: a live preview of the Finder right-click menu.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Click Open System Settings and enable the app's Finder extension.")),
                .init(L("In General Actions, turn the right-click actions on or off as needed.")),
                .init(L("In New File Menu, click Add Template and fill in the name, extension, and default content.")),
                .init(L("Use the switch and the delete button on a template row to manage it.")),
                .init(L("Open the Preview tab in the rail to check the resulting menu.")),
            ])

            ManualSectionHeader(number: 4, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("The right-click menu works only after the Finder extension is enabled in System Settings.")),
                .init(L("Reset restores all actions and templates to the defaults.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 10) {
                // ① 扩展开关卡片示意
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        Image(systemName: "puzzlepiece.extension")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.textSecondary)
                        lineMock(width: 56)
                    }
                    HStack(spacing: 6) {
                        buttonPillMock(L("Open System Settings"))
                        Spacer(minLength: 0)
                        lineMock(width: 64)
                    }
                }
                .padding(9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
                .overlay(alignment: .topLeading) { ManualFigureMarker(1).padding(-7) }

                // ② 通用动作卡片示意
                VStack(alignment: .leading, spacing: 6) {
                    groupLabel(L("General Actions"))
                    toggleRowMock(width: 40)
                    toggleRowMock(width: 52)
                }
                .padding(9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
                .overlay(alignment: .topLeading) { ManualFigureMarker(2).padding(-7) }

                // ③ 新建文件菜单卡片示意
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        groupLabel(L("New File Menu"))
                        Spacer(minLength: 0)
                        buttonPillMock(L("Add Template"))
                    }
                    HStack(spacing: 6) {
                        toggleMock(on: true)
                        lineMock(width: 44)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 8))
                            .foregroundStyle(theme.textSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            lineMock(width: 40)
                            lineMock(width: 24)
                        }
                        Spacer(minLength: 0)
                        toggleMock(on: true)
                        Image(systemName: "trash")
                            .font(.system(size: 8))
                            .foregroundStyle(theme.error)
                    }
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
                }
                .padding(9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
                .overlay(alignment: .topLeading) { ManualFigureMarker(3).padding(-7) }

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, L("Enable Finder Extension"))
                    ManualFigureLegendItem(2, L("General Actions"))
                    ManualFigureLegendItem(3, L("New File Menu"))
                }
            }
        }
    }

    // MARK: - 示意简笔元素

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(theme.appDivider)
    }

    /// 卡片小标题。
    private func groupLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .semibold))
            .foregroundColor(theme.textSecondary)
    }

    /// 动作行示意:开关 + 文字线。
    private func toggleRowMock(width: CGFloat) -> some View {
        HStack(spacing: 6) {
            toggleMock(on: true)
            lineMock(width: width)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    /// 按钮示意。
    private func buttonPillMock(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .medium))
            .foregroundColor(theme.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(theme.appDivider)
            )
    }

    /// 开关示意。
    private func toggleMock(on: Bool) -> some View {
        ZStack(alignment: on ? .trailing : .leading) {
            Capsule()
                .fill(Color.primary.opacity(0.15))
            Circle()
                .fill(Color.primary.opacity(0.5))
                .padding(2)
        }
        .frame(width: 22, height: 12)
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
        RClickManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
