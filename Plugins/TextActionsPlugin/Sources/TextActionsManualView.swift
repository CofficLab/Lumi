import LumiUI
import SwiftUI

// MARK: - Manual View

/// 文本操作使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct TextActionsManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Text Actions"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of Text Actions: enabling the plugin, granting permissions, and using the floating menu on selected text."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("Header card: shows the plugin name and a short description.")),
                .init(L("Enable Text Actions: a switch that turns the floating menu on or off.")),
                .init(L("Permission card: shows the accessibility permission status, an explanation, and the Open System Settings button.")),
                .init(L("After text is selected in another app, a floating menu with Copy, Search, and Translate appears near the selection.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Open the Text Actions tab in the sidebar.")),
                .init(L("Turn on the Enable Text Actions switch.")),
                .init(L("Grant accessibility permission when prompted, using Open System Settings if necessary.")),
                .init(L("Select text in any macOS app; a floating menu appears near the selection.")),
                .init(L("Choose Copy, Search, or Translate from the menu.")),
            ])

            ManualSectionHeader(number: 4, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("The floating menu requires accessibility permission to read selected text.")),
                .init(L("If the permission is revoked, the feature stops working.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 12) {
                // ① 启用开关行
                HStack(spacing: 8) {
                    Image(systemName: "cursorarrow.rays")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textSecondary)
                    VStack(alignment: .leading, spacing: 4) {
                        lineMock(width: 56)
                        lineMock(width: 96)
                    }
                    Spacer(minLength: 0)
                    toggleMock(on: true)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(theme.appDivider)
                )
                .overlay(alignment: .topLeading) { ManualFigureMarker(1).padding(-7) }

                // ② 权限卡片
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(theme.warning.opacity(0.8))
                            .frame(width: 7, height: 7)
                        lineMock(width: 70)
                    }
                    lineMock(width: 120)
                    buttonPill()
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
                .overlay(alignment: .topLeading) { ManualFigureMarker(2).padding(-7) }

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, L("Enable switch"))
                    ManualFigureLegendItem(2, L("Permission card"))
                }
            }
        }
    }

    // MARK: - 示意简笔元素

    /// 开关示意:开启状态的胶囊滑块。
    private func toggleMock(on: Bool) -> some View {
        ZStack(alignment: on ? .trailing : .leading) {
            Capsule()
                .fill(on ? theme.primary.opacity(0.6) : Color.primary.opacity(0.15))
                .frame(width: 30, height: 17)
            Circle()
                .fill(.white)
                .frame(width: 13, height: 13)
                .shadow(radius: 1)
                .padding(2)
        }
    }

    /// 按钮示意。
    private func buttonPill() -> some View {
        HStack(spacing: 5) {
            Image(systemName: "gear")
                .font(.system(size: 8))
            lineMock(width: 40)
        }
        .padding(.horizontal, 8)
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
        TextActionsManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
