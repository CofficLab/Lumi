import LumiUI
import SwiftUI

// MARK: - Manual View

/// 输入管理器使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct InputManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Input Manager"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of the Input Manager: switching the input source automatically for each application."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("Switch card: the 「Enable Auto Input Source Switching」 toggle turns the feature on or off.")),
                .init(L("Add-rule card: under 「Add New Rule」, pick an application and an input source, then click 「Add」.")),
                .init(L("Rules card: lists the rules; each row shows an application and its input source. Right-click a row and choose 「Delete」 to remove it.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Open the Input Manager tab in the sidebar.")),
                .init(L("Turn on 「Enable Auto Input Source Switching」.")),
                .init(L("Under 「Add New Rule」, choose an application from 「Select Application」; running applications are listed.")),
                .init(L("Choose an input source from 「Select Input Source」.")),
                .init(L("Click 「Add」; the rule appears in the 「Rules」 list.")),
                .init(L("To remove a rule, right-click it and choose 「Delete」.")),
            ])

            ManualSectionHeader(number: 4, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("The input source switches when the matched application comes to the foreground.")),
                .init(L("Rules take effect only while the master switch is on.")),
                .init(L("With no rules, the list shows 「No input source switching rules」.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 12) {
                // ① 开关卡片示意
                cardMock {
                    HStack(spacing: 8) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.textSecondary)
                        lineMock(width: 110)
                        Spacer(minLength: 0)
                        toggleMock(isOn: true)
                    }
                }
                .overlay(alignment: .topLeading) { ManualFigureMarker(1).padding(-7) }

                // ② 新建规则卡片示意
                cardMock {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("Add New Rule"))
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                        HStack(spacing: 6) {
                            pickerMock()
                            pickerMock()
                            toolbarPill("plus")
                        }
                    }
                }
                .overlay(alignment: .topLeading) { ManualFigureMarker(2).padding(-7) }

                // ③ 规则列表卡片示意
                cardMock {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("Rules"))
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                        ruleRowMock()
                        ruleRowMock()
                    }
                }
                .overlay(alignment: .topLeading) { ManualFigureMarker(3).padding(-7) }

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, L("Switch card"))
                    ManualFigureLegendItem(2, L("Add-rule card"))
                    ManualFigureLegendItem(3, L("Rules card"))
                }
            }
        }
    }

    // MARK: - 示意简笔元素

    /// 设置卡片外框。
    private func cardMock<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(theme.appDivider)
            )
    }

    /// 规则行示意:应用 + 输入源。
    private func ruleRowMock() -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.primary.opacity(0.08))
                .frame(width: 14, height: 14)
            lineMock(width: 48)
            Spacer(minLength: 0)
            lineMock(width: 36)
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    /// 选择器示意:下拉框形状。
    private func pickerMock() -> some View {
        HStack(spacing: 4) {
            lineMock(width: 30)
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
        InputManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
